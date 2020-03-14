#include <iostream>
#include <queue>
#include <string>
#include <tuple>
#include <vector>

#include <boost/asio/io_service.hpp>
#include <boost/bind.hpp>
#include <boost/thread/thread.hpp>
#include <gflags/gflags.h>
#include <pqxx/pqxx>
#include <pqxx/tablewriter>
#include <easylogging++.h>

#include "processing/data_grid.h"
#include "processing/grid_forming.h"
#include "utils/common.h"
#include "utils/geometry.h"

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

DEFINE_string(objects_query, "", "SQL query yielding (lat, lng) tuples");
DEFINE_validator(objects_query, &ValidateNonEmpty);

DEFINE_string(
		stops_query,
		(
			"SELECT DISTINCT stop.latitude, stop.longitude "
			"FROM raw_data.stop "
			"LEFT JOIN raw_data.route_stop ON stop.id = route_stop.stop_id "
			"LEFT JOIN raw_data.route ON route.id = route_stop.route_id "
			"WHERE route.type = 'Метро';"
		),
		"SQL query yielding (lat, lng) tuples");

DEFINE_int32(view_radius, 100, "Path-line boldness in meters");

DEFINE_string(output_table, "", "Name of output table");
DEFINE_validator(output_table, &ValidateNonEmpty);

DEFINE_int32(threads, 1, "Number of threads to use");

INITIALIZE_EASYLOGGINGPP

namespace {

std::string GetConnectionString() {
	std::string connection_string;
	connection_string += "host=" + FLAGS_dbhost;
	connection_string += " port=" + std::to_string(FLAGS_dbport);
	connection_string += " dbname=" + FLAGS_dbname;
	connection_string += " user=" + FLAGS_dbuser;
	connection_string += " password=" + FLAGS_dbpass;
	return connection_string;
}

using utils::GeoCoords;
using utils::Point2D;
using utils::Vector2D;

void MarkPath(
		int from_x, int from_y, int to_x, int to_y, float_t view_R, int obj_count,
		processing::DataGrid<int> *grid) {
	std::vector< std::vector<bool> > used(
			grid->NumRows(), std::vector<bool>(grid->NumCols(), false));
	std::queue< std::pair<int, int> > q;
	q.emplace(from_x, from_y);
	utils::Point2D<float_t> from(from_x, from_y), to(to_x, to_y);
	utils::Vector2D<float_t> v = to - from;
	while (!q.empty()) {
		auto cur = q.front();
		Point2D<float_t> curp(cur.first, cur.second);
		q.pop();

		if (used[cur.first][cur.second]) {
			continue;
		}
		used[cur.first][cur.second] = true;
		Vector2D<float_t> u = curp - from;
		float_t k = u.DotProduct(v) / v.NormSquared(), distance;
		if (k < 0 || k > 1) {
			distance = std::min((from - curp).Norm(), (to - curp).Norm());
		} else {
			distance = (u - v * k).Norm();
		}
		if (distance * 100 > view_R) {
			continue;
		}

		(*grid)[cur.first][cur.second] += obj_count;
		const int dx[] = {-1, 1, 0, 0};
		const int dy[] = {0, 0, -1, 1};
		for (int d = 0; d < 4; ++d) {
			std::pair<int, int> new_cell(cur.first + dx[d], cur.second + dy[d]);
			if (new_cell.first < 0 || new_cell.first >= grid->NumRows() ||
					new_cell.second < 0 || new_cell.second >= grid->NumCols() ||
					used[new_cell.first][new_cell.second]) {
				continue;
			}
			q.push(new_cell);
		}
	}
}

void ResetTable(const std::string &table_, pqxx::connection *conn_) {
	pqxx::work trans(*conn_);

	std::string query = "DROP TABLE IF EXISTS " + table_;
	trans.exec(query);

	query = "CREATE TABLE " + table_ +
		" (grid_id integer, square_id integer, traffic integer, "
		" UNIQUE (grid_id, square_id));";
	trans.exec(query);
	trans.commit();
}

}  // namespace

int main(int argc, char **argv) {
	START_EASYLOGGINGPP(argc, argv);
	el::Loggers::reconfigureAllLoggers(el::ConfigurationType::Filename,
			"logs/calculate_traffic.log");
	gflags::ParseCommandLineFlags(&argc, &argv, true);

	try {
		pqxx::connection db_conn(GetConnectionString());
		std::vector<grids::GridMetadata> grids = grids::LoadGridMetadata(&db_conn);
		ResetTable(FLAGS_output_table, &db_conn);

		std::vector<GeoCoords> stops;
		std::vector< std::pair<GeoCoords, int> > objects;

		{
			pqxx::work trans(db_conn);
			for (const auto &row: trans.exec(FLAGS_stops_query)) {
				stops.emplace_back(row[0].as<float_t>(), row[1].as<float_t>());
			}
			for (const auto &row: trans.exec(FLAGS_objects_query)) {
				objects.emplace_back(
						GeoCoords(row[0].as<float_t>(), row[1].as<float_t>()), 1);
			}
			trans.commit();
		}

		LOG(INFO) << stops.size() << " stops";
		LOG(INFO) << objects.size() << " objects";

		for (const auto &grid: grids) {
			processing::DataGrid<int> data_grid(grid), obj_grid(grid);
			processing::FillDataGrid(objects, grid, false, 0, &obj_grid);

			float_t lat_k = 100. / grid.GetLatStep();
			float_t lng_k = 100. / grid.GetLngStep();

			for (int i = 0; i < obj_grid.NumRows(); ++i) {
				for (int j = 0; j < obj_grid.NumCols(); ++j) {
					if (obj_grid[i][j] == 0) {
						continue;
					}
					size_t closest = 0;
					float_t closest_dist = 1e10;
					GeoCoords cell = grid.GetCenter(i, j);
					for (size_t z = 0; z < stops.size(); ++z) {
						float_t dist = hypot(
								(cell.lat - stops[z].lat) * lat_k,
								(cell.lng - stops[z].lng) * lng_k);
						if (dist < closest_dist) {
							closest = z;
							closest_dist = dist;
						}
					}
					int obj_x, obj_y;
					if (grid.GetSquareCoords(stops[closest], &obj_x, &obj_y)) {
						MarkPath(
								i, j, obj_x, obj_y,
								FLAGS_view_radius, obj_grid[i][j], &data_grid);
					}
				}
			}

			{
				pqxx::work trans(db_conn);
				auto cells = grids::EnumerateGridCells(grid.GetSide());
				pqxx::tablewriter writer(trans, FLAGS_output_table);
				for (size_t id = 0; id < cells.size(); ++id) {
					auto p = cells[id];
					if (data_grid[p.first][p.second] != 0) {
						std::vector<int> row = {
							grid.GetId(), (int) id, data_grid[p.first][p.second]};
						writer.insert(row);
					}
				}
				writer.complete();
				trans.commit();
			}
		}
		LOG(DEBUG) << "All jobs are finished";
	} catch (const pqxx::sql_error &e) {
		LOG(ERROR) << "SQL error"
		           << "\nerror = " << e.what()
		           << "\nquery = " << e.query();
		return 1;
	}
	return 0;
}
