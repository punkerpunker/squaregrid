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
#include "utils/common.h"
#include "utils/helpers.h"

static bool ValidateNonEmpty(const char*, const std::string &value) {
	return !value.empty();
}

static bool ValidateAction(const char*, const std::string &value) {
	return value == "sum" || value == "average";
}

DEFINE_string(dbhost, "127.0.0.1", "Address of DB to connect");
DEFINE_validator(dbhost, &ValidateNonEmpty);
DEFINE_int32(dbport, 5432, "Port where DB is serving");
DEFINE_string(dbname, "mldata", "database name");
DEFINE_string(dbuser, "marketinglogic", "database user");
DEFINE_string(dbpass, "", "database password");
DEFINE_validator(dbpass, &ValidateNonEmpty);

DEFINE_string(data_query, "", "SQL-query");
DEFINE_validator(data_query, &ValidateNonEmpty);
DEFINE_string(output_table, "", "Output table name");
DEFINE_validator(output_table, &ValidateNonEmpty);
DEFINE_string(
		action, "",
		"What to do with the values in certain radius. "
		"Possible values: sum, average");
DEFINE_validator(action, &ValidateAction);
DEFINE_bool(exclude_most_common, false,
		"If set, do not count most common square");
DEFINE_double(tolerance, 1e-6, "Tolerance to match most common points");

DEFINE_int32(threads, 1, "Number of threads to use");
DEFINE_int32(radii_count, 30, "Number of radii to calculate");

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
		pqxx::connection db_conn(
				"host=0.0.0.0 port=5432 dbname=mldata user=marketinglogic password=tttBBB777");
		std::vector<grids::GridMetadata> grids = grids::LoadGridMetadata(&db_conn);

		if (FLAGS_action == "sum") {
			processing::CreateRadiiTableFromSQLConcurrently<int, int>(
					GetConnectionString(), grids,
					FLAGS_data_query, FLAGS_output_table,
					FLAGS_radii_count,
					FLAGS_exclude_most_common, FLAGS_tolerance,
					FLAGS_threads);
		} else {
			processing::CreateRadiiTableFromSQLConcurrently<
				int, utils::Averager<float_t> >(
					GetConnectionString(), grids,
					FLAGS_data_query, FLAGS_output_table,
					FLAGS_radii_count,
					FLAGS_exclude_most_common, FLAGS_tolerance,
					FLAGS_threads);
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
