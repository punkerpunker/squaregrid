#include <cmath>

#include <iostream>
#include <memory>
#include <numeric>
#include <string>

#include <boost/algorithm/string.hpp>
#include <boost/asio/io_service.hpp>
#include <boost/bind.hpp>
#include <boost/filesystem.hpp>
#include <boost/thread/thread.hpp>
#include <grpc++/grpc++.h>
#include <gflags/gflags.h>

#include "easylogging++.h"

#include "grids/grid_metadata.h"
#include "primary/data_mart_manager.grpc.pb.h"
#include "utils/datamart.pb.h"

static bool ValidateMessageSize(const char*, int value) {
	return 1 <= value && value < 2048;
}

static bool ValidateNonEmpty(const char*, const std::string &value) {
	return !value.empty();
}

DEFINE_string(dbhost, "127.0.0.1", "Address of DB to connect");
DEFINE_validator(dbhost, &ValidateNonEmpty);
DEFINE_int32(dbport, 5432, "Port where DB is serving");
DEFINE_string(dbname, "mldata", "database name");
DEFINE_string(dbuser, "marketinglogic", "database user");
DEFINE_string(dbpass, "", "database password");
DEFINE_validator(dbpass, &ValidateNonEmpty);

DEFINE_int32(max_message_size, 2000, "Max gRPC message size in MiB");
DEFINE_validator(max_message_size, &ValidateMessageSize);
DEFINE_int32(port, 55556, "Port to serve on");
DEFINE_int32(threads_per_request, 10, "Threads server can use per request");

using utils::DataMart;
using primary::DataMartManager;
using primary::MakeDataMartRequest;
using primary::MakeDataMartResponse;

class DataMartManagerImpl final : public DataMartManager::Service {
	public:
		grpc::Status MakeDataMart(
				grpc::ServerContext *,
				const MakeDataMartRequest *request,
				MakeDataMartResponse *response) override {
			LOG(INFO) << "MakeDataMart request recieved";
			MakeDataMart(*request, response);
			return grpc::Status::OK;
		}

		DataMartManagerImpl(
				const std::string &connection_string, int threads)
				: connection_string_(connection_string), threads_(threads) {
			try {
				pqxx::connection db_conn(connection_string_);
				regions_ = grids::LoadGridMetadata(&db_conn);
			} catch (const pqxx::sql_error &e) {
				LOG(ERROR) << "SQL Error:\n" << e.what() << "Query:\n" << e.query();
				throw e;
			}
		}

	private:
		std::pair<int, int> GetRegionAndSquare(float_t lat, float_t lng) {
			for (std::size_t i = 0; i < regions_.size(); ++i) {
				int id;
				if (regions_[i].GetSquareId(utils::GeoCoords(lat, lng), &id)) {
					return {regions_[i].GetId(), id};
				}
			}
			return {0, 0};
		}

		bool ProcessRubric(
				const std::string radii_table,
				const std::vector<int> radii,
				const std::string &prefix,
				const DataMart &mart,
				std::vector< utils::DataMartColumn> *result) {
			try {
				LOG(INFO) << "Starting table " << radii_table;
				pqxx::connection db_conn(connection_string_);
				pqxx::work trans(db_conn);

				int rows = mart.nrows();
				int radii_count = trans.exec(
						"SELECT * FROM " + radii_table + " LIMIT 1").columns() - 2;
				int radii_requested = radii.size();
				result->resize(radii_requested);
				for (int i = 0; i < radii_requested; ++i) {
					(*result)[i].set_name(
							prefix + radii_table + "_" +
							std::to_string(radii[i]));
					for (int j = 0; j < rows; ++j) {
						(*result)[i].add_cells();
					}
				}

				std::vector<int> sorted_order(rows);
				std::iota(sorted_order.begin(), sorted_order.end(), 0);
				int grid_col = mart.columns_size() - 1;
				int cell_col = mart.columns_size() - 2;
				std::sort(
						sorted_order.begin(), sorted_order.end(),
						[grid_col, &mart](int a, int b) {
							return (
									mart.columns(grid_col).cells(a).int_val() <
									mart.columns(grid_col).cells(b).int_val());
						});
				int cur_grid_id = 0;
				std::vector< std::vector<int> > cur_grid;
				for (int r_id : sorted_order) {
					if (mart.columns(grid_col).cells(r_id).int_val() != cur_grid_id) {
						cur_grid_id = mart.columns(grid_col).cells(r_id).int_val();
						cur_grid.clear();
						pqxx::result grid = trans.exec(
								"SELECT * FROM " + radii_table +
								" WHERE city_id = " + std::to_string(cur_grid_id) +
								" ORDER BY square_id");
						assert((int) grid.columns() == radii_count + 2);
						LOG(DEBUG) << "Fetched grid number " << cur_grid_id << "; "
							<< grid.columns() << " columns";
						for (int i = 0; i < radii_count; ++i) {
							assert(std::string(grid.column_name(i + 2)) ==
									"_" + std::to_string(i * 100));
						}
						if (grid.size() > 0) {
							cur_grid.resize(grid[grid.size() - 1][1].as<int>() + 1);
						}
						LOG(DEBUG) << "Names ok; total sqrs = " << grid.size();
						for (const auto &row : grid) {
							int row_id = row[1].as<int>();
							cur_grid[row_id].resize(radii_requested);
							for (int i = 0; i < radii_requested; ++i) {
								int r = radii[i] / 100;
								if (r + 2 >= (int) row.size()) {
									LOG(INFO) << "Radius " << radii[i] <<
										" is out of range for table " << radii_table;
									assert(false);
								}
								cur_grid[row_id][i] = row[r + 2].as<int>();
							}
							std::partial_sum(
									cur_grid[row_id].begin(), cur_grid[row_id].end(),
									cur_grid[row_id].begin());
						}
						LOG(DEBUG) << "Grid ok, max sqr = " << (int) cur_grid.size() - 1;
					}
					int cell_id = mart.columns(cell_col).cells(r_id).int_val();
					std::vector<int> cur_radii;
					if (!cur_grid.empty() && cell_id < (int) cur_grid.size()) {
						cur_radii = cur_grid[cell_id];
					}
					if (cur_radii.empty()) cur_radii.assign(radii_requested, 0);
					for (int i = 0; i < radii_requested; ++i) {
						(*result)[i].mutable_cells(r_id)->set_int_val(cur_radii[i]);
					}
				}
			} catch (const pqxx::sql_error &e) {
				LOG(ERROR) << "SQL Error:\n" << e.what() << "Query:\n" << e.query();
				return false;
			}
			return true;
		}

		void MakeDataMart(
				const MakeDataMartRequest &request,
				MakeDataMartResponse *response) {

			response->mutable_data()->CopyFrom(request.data());
			auto id_col = response->mutable_data()->add_columns();
			id_col->set_name(request.prefix() + "square_id");
			auto grid_col = response->mutable_data()->add_columns();
			grid_col->set_name(request.prefix() + "grid_id");

			int lat_idx = request.latitude_column();
			int lng_idx = request.longitude_column();
			const auto &req_data = request.data();
			for (int i = 0; i < request.data().nrows(); ++i) {
				auto grid_cell = grid_col->add_cells();
				auto id_cell = id_col->add_cells();
				int kFloatVal = utils::DataMartCell::DataTypeCase::kFloatVal;
				if (req_data.columns(lat_idx).cells(i).data_type_case() == kFloatVal &&
						req_data.columns(lng_idx).cells(i).data_type_case() == kFloatVal) {
					float_t lat = request.data().columns(lat_idx).cells(i).float_val();
					float_t lng = request.data().columns(lng_idx).cells(i).float_val();

					auto id = GetRegionAndSquare(lat, lng);
					grid_cell->set_int_val(id.first);
					id_cell->set_int_val(id.second);
				}
			}

			LOG(INFO) << "Forming data mart using " << threads_ << " threads";

			std::vector< std::vector<utils::DataMartColumn> > result(
					request.tables_size());
			boost::asio::io_service ioService;
			boost::thread_group threadpool;
			do {
				boost::asio::io_service::work work(ioService);
				for (int i = 0; i < threads_; ++i) {
					threadpool.create_thread(
							boost::bind(&boost::asio::io_service::run, &ioService));
				}
				for (int i = 0; i < request.tables_size(); ++i) {
					std::vector<int> r;
					for (int j = 0; j < request.tables(i).radii_size(); ++j) {
						r.push_back(request.tables(i).radii(j));
					}
					ioService.post(boost::bind(
								&DataMartManagerImpl::ProcessRubric, this,
								request.tables(i).table_name(), r, request.prefix(),
								response->data(), &result[i]));
				}
			} while (false);
			threadpool.join_all();
			ioService.stop();

			LOG(INFO) << "All jobs are finished, creating response";
			if (request.return_mart()) {
				for (auto &cols: result) {
					for (const utils::DataMartColumn &col: cols) {
						response->mutable_data()->add_columns()->CopyFrom(col);
					}
				}
			}
			if (request.output_table().size() > 0) {
				try {
					pqxx::connection db_conn(connection_string_);
					pqxx::work trans(db_conn);

					std::string create_query = "DROP TABLE IF EXISTS " + request.output_table();
					trans.exec(create_query);

					std::string insert_query = (
							"INSERT INTO " + request.output_table() + " VALUES (");
					int insert_cnt = 0;
					create_query = "CREATE TABLE " + request.output_table() + "(";
					for (int i = 0; i < request.data().columns_size(); ++i) {
						if (i > 0) {
							insert_query += ", ";
							create_query += ", ";
						}
						create_query += request.data().columns(i).name();
						int kFloatVal = utils::DataMartCell::DataTypeCase::kFloatVal;
						int kStrVal = utils::DataMartCell::DataTypeCase::kStrVal;
						int kIntVal = utils::DataMartCell::DataTypeCase::kIntVal;
						int type =  request.data().columns(i).cells(0).data_type_case();
						if (type == kFloatVal) create_query += " float";
						else if (type == kStrVal) create_query += " text";
						else if (type == kIntVal) create_query += " integer";
						insert_query += "$" + std::to_string(++insert_cnt);
					}
					for (const auto &col: {grid_col, id_col}) {
						create_query += ", ";
						insert_query += ", ";
						create_query += col->name();
						create_query += " integer";
						insert_query += "$" + std::to_string(++insert_cnt);
					}
					for (size_t i = 0; i < result.size(); ++i) {
						for (int j = 0; j < request.tables(i).radii_size(); ++j) {
							create_query += ", ";
							insert_query += ", ";
							std::string col_name = (
									request.prefix() + request.tables(i).table_name() + "_"
									+ std::to_string(request.tables(i).radii(j)));
							for (size_t z = 0; z < col_name.size(); ++z) {
								if (col_name[z] == '.') col_name[z] = '_';
							}
							create_query += col_name;
							create_query += " integer";
							insert_query += "$" + std::to_string(++insert_cnt);
						}
					}
					create_query += ")";
					insert_query += ")";
					LOG(DEBUG) << "Creating table";
					trans.exec(create_query);

					LOG(DEBUG) << "Inserting rows";
					db_conn.prepare("insert_row", insert_query);

					for (int i = 0; i < request.data().nrows(); ++i) {
						auto query = trans.prepared("insert_row");
						for (int j = 0; j < request.data().columns_size(); ++j) {
							int kFloatVal = utils::DataMartCell::DataTypeCase::kFloatVal;
							int kStrVal = utils::DataMartCell::DataTypeCase::kStrVal;
							int kIntVal = utils::DataMartCell::DataTypeCase::kIntVal;
							int type =  request.data().columns(j).cells(i).data_type_case();
							if (type == kFloatVal)
								query(request.data().columns(j).cells(i).float_val());
							else if (type == kStrVal)
								query(request.data().columns(j).cells(i).str_val());
							else if (type == kIntVal)
								query(request.data().columns(j).cells(i).int_val());
						}
						query(grid_col->cells(i).int_val());
						query(id_col->cells(i).int_val());
						for (size_t z = 0; z < result.size(); ++z) {
							for (int j = 0; j < request.tables(z).radii_size(); ++j) {
								query(result[z][j].cells(i).int_val());
							}
						}
						query.exec();
					}
					trans.commit();
				} catch (const pqxx::sql_error &e) {
					LOG(ERROR) << "SQL Error:\n" << e.what() << "Query:\n" << e.query();
					throw e;
				}
			}
			LOG(INFO) << "Response created";
		}

		std::string connection_string_;
		std::vector<grids::GridMetadata> regions_;
		int threads_;
};

void RunServer(
		const std::string &connection_string,
		int port, int max_message_size, int threads_per_request) {
	int max_message_size_bytes = max_message_size * 1024 * 1024;
	DataMartManagerImpl service(connection_string, threads_per_request);

	std::string server_address = std::string("0.0.0.0:") + std::to_string(port);

	grpc::ServerBuilder builder;
	builder.AddListeningPort(
			server_address, grpc::InsecureServerCredentials());
	builder.SetMaxReceiveMessageSize(max_message_size_bytes);
	builder.SetMaxSendMessageSize(max_message_size_bytes);
	builder.RegisterService(&service);
	std::unique_ptr<grpc::Server> server = builder.BuildAndStart();
	server->Wait();
}

std::string GetConnectionString() {
	std::string connection_string;
	connection_string += "host=" + FLAGS_dbhost;
	connection_string += " port=" + std::to_string(FLAGS_dbport);
	connection_string += " dbname=" + FLAGS_dbname;
	connection_string += " user=" + FLAGS_dbuser;
	connection_string += " password=" + FLAGS_dbpass;
	return connection_string;
}

int main(int argc, char **argv) {
	START_EASYLOGGINGPP(argc, argv);
	gflags::ParseCommandLineFlags(&argc, &argv, true);
	RunServer(
			GetConnectionString(), FLAGS_port, FLAGS_max_message_size,
			FLAGS_threads_per_request);
	return 0;
}
