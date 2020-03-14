#include <iostream>
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

#include "processing/table_creation.h"

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

DEFINE_string(objects_table, "", "Table with objects");
DEFINE_validator(objects_table, &ValidateNonEmpty);

DEFINE_string(output_schema, "brands_radii", "Name of output schema");
DEFINE_validator(output_schema, &ValidateNonEmpty);

DEFINE_string(rubrics_file, "", "File with rubrics");
DEFINE_string(rubrics_list, "", "Comma separated rubrics list");
DEFINE_int32(top_names_count, 20, "Number of top names to select");

DEFINE_bool(exclude_most_common, false,
		"If set, do not count most common square");
DEFINE_double(tolerance, 1e-6, "Tolerance to match most common points");

DEFINE_int32(threads, 1, "Number of threads to use");
DEFINE_int32(radii_count, 30, "Number of radii to calculate");

INITIALIZE_EASYLOGGINGPP

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
	el::Loggers::reconfigureAllLoggers(el::ConfigurationType::Filename,
			"logs/calculate_radii_objects.log");
	gflags::ParseCommandLineFlags(&argc, &argv, true);

	try {
		pqxx::connection db_conn(GetConnectionString());
		std::vector<grids::GridMetadata> grids = grids::LoadGridMetadata(&db_conn);

		std::vector<std::string> rubrics;
		do {
			if (!FLAGS_rubrics_list.empty()) {
				FLAGS_rubrics_list += ",";
				int p = -1;
				for (size_t i = 0; i < FLAGS_rubrics_list.size(); ++i) {
					if (FLAGS_rubrics_list[i] != ',') continue;
					int l = p + 1, r = std::max(0, (int) i - 1);
					while (l <= r && FLAGS_rubrics_list[l] == ' ') ++l;
					while (l <= r && FLAGS_rubrics_list[r] == ' ') --r;
					rubrics.push_back(FLAGS_rubrics_list.substr(l, r - l + 1));
					p = i;
				}
				FLAGS_rubrics_list.pop_back();
			}
			if (!FLAGS_rubrics_file.empty()) {
				if (!rubrics.empty()) {
					LOG(ERROR) << "Please use --rubrics_list OR --rubrics_file flag";
					return 1;
				}
				std::ifstream in(FLAGS_rubrics_file);
				std::string line;
				while (std::getline(in, line)) {
					rubrics.push_back(line);
				}
			}
			if (rubrics.empty()) {
				LOG(ERROR) << "Please use --rubrics_list OR --rubrics_file flag";
				return 1;
			}
		} while (false);

		for (size_t i = 0; i < rubrics.size(); ++i) {
			std::vector<std::string> top_names;
			std::string rubric_eng;
			do {
				pqxx::work trans(db_conn);
				std::string top_names_query = (
						"SELECT standardized_name FROM " + FLAGS_objects_table + " "
						"WHERE rubric_name = " + trans.quote(rubrics[i]) + " "
						"AND standardized_name IS NOT NULL "
						"GROUP BY standardized_name "
						"ORDER BY COUNT(id) DESC "
						"LIMIT " + std::to_string(FLAGS_top_names_count) + ";");
				for (const auto &row: trans.exec(top_names_query)) {
					top_names.push_back(row[0].as<std::string>());
				}
				rubric_eng = trans.exec(
						"SELECT eng FROM metadata.rubrics "
						"WHERE rus = " + trans.quote(rubrics[i]))[0][0].as<std::string>();
			} while (false);
			LOG(INFO) << "Fetched " << top_names.size() << " top names for rubric "
				<< rubrics[i];
			for (size_t j = 0; j < top_names.size(); ++j) {
				LOG(INFO) << "Strated processing name " << top_names[j]
					<< " in rubric " << rubrics[i];
				std::string data_query = (
						"SELECT gc_lat, gc_lng FROM " + FLAGS_objects_table + " "
						"WHERE rubric_name = " + db_conn.quote(rubrics[i]) + " "
						"AND standardized_name = " + db_conn.quote(top_names[j]) + ";");
				std::string output_table = (
						FLAGS_output_schema + "." + rubric_eng +
						"_top" + std::to_string(j));

				processing::CreateRadiiTableFromSQLConcurrently<int, int>(
						GetConnectionString(), grids,
						data_query, output_table,
						FLAGS_radii_count,
						FLAGS_exclude_most_common, FLAGS_tolerance,
						FLAGS_threads);
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
