#include <iostream>
#include <string>
#include <tuple>
#include <vector>

#include <boost/asio/io_service.hpp>
#include <boost/bind.hpp>
#include <boost/filesystem.hpp>
#include <boost/thread/thread.hpp>
#include <gflags/gflags.h>
#include <pqxx/pqxx>
#include <pqxx/tablewriter>
#include <easylogging++.h>

#include "grids/grid_metadata.h"
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

DEFINE_int32(threads, 1, "Number of threads to use");
DEFINE_int32(radii_count, 30, "Number of radii to calculate");
DEFINE_bool(exclude_most_common, false,
		"If set, do not count most common square");
DEFINE_double(tolerance, 1e-6, "Tolerance to match most common points");

DEFINE_int32(lbound, 0,
		"Left bound in alphabetically sorted rubric list");
DEFINE_int32(rbound, -1,
		"Right (uninclusive) bound in alphabetically sorted rubric list");

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

std::string QueryObjectsByRubric(
		pqxx::connection *conn,
		const std::string &rubric) {
	pqxx::work trans(*conn);
	const std::string query = (
			"SELECT DISTINCT ON (yandex_objects.organization.id) lat, lon"
			" FROM yandex_objects.organization"
			" LEFT JOIN yandex_objects.organization_rubric ON"
			" organization_rubric.organization_id = organization.id"
			" LEFT JOIN yandex_objects.rubric ON"
			" rubric.id = organization_rubric.rubric_id"
			" WHERE rubric.name  = " + trans.quote(rubric) +
			" AND lat IS NOT NULL AND lon IS NOT NULL"
			" AND gc_accuracy IN ('house')"
			" AND rubric.name IS NOT NULL"
			" AND updated in ('1','2');");
	return query;
}

int main(int argc, char **argv) {
	START_EASYLOGGINGPP(argc, argv);
	el::Loggers::reconfigureAllLoggers(el::ConfigurationType::Filename,
			"logs/calculate_radii_objects.log");
	gflags::ParseCommandLineFlags(&argc, &argv, true);

	try {
		pqxx::connection db_conn(GetConnectionString());

		std::vector< std::pair<std::string, std::string> > rubrics;
		std::vector<grids::GridMetadata> grids = grids::LoadGridMetadata(&db_conn);

		do {
			pqxx::work trans(db_conn);

			const std::string rubrics_query =
				"SELECT DISTINCT rubric.name"
				" FROM yandex_objects.organization"
				" LEFT JOIN yandex_objects.organization_rubric ON"
				" organization_rubric.organization_id = organization.id"
				" LEFT JOIN yandex_objects.rubric ON"
				" rubric.id = organization_rubric.rubric_id"
				" WHERE lat IS NOT NULL AND lon IS NOT NULL"
				" AND gc_accuracy IN ('house')"
				" AND rubric.name IS NOT NULL"
				" AND updated in ('1','2');";
			for (const auto &rubric: trans.exec(rubrics_query)) {
				std::string eng_name = trans.exec(
						"SELECT eng FROM metadata.rubrics WHERE rus = " + trans.quote(
							rubric[0].as<std::string>()) + ";")[0][0].as<std::string>();
				rubrics.emplace_back(rubric[0].as<std::string>(), eng_name);
			}
		} while (false);
		LOG(INFO) << "Fetched " << rubrics.size() << " rubrics";
		sort(rubrics.begin(), rubrics.end());
		if (FLAGS_rbound == -1 || FLAGS_rbound > (int) rubrics.size())
			FLAGS_rbound = rubrics.size();

		for (int i = FLAGS_lbound; i < FLAGS_rbound; ++i) {
			std::string output_table = "radii." + rubrics[i].second;
			LOG(INFO) << "Starting table " << output_table;

			processing::CreateRadiiTableFromSQLConcurrently<int, int>(
					GetConnectionString(), grids,
					QueryObjectsByRubric(&db_conn, rubrics[i].first),
					output_table, FLAGS_radii_count,
					FLAGS_exclude_most_common, FLAGS_tolerance,
					FLAGS_threads);
		}
		LOG(DEBUG) << "All jobs are finished";
	} catch (const pqxx::sql_error &e) {
		LOG(ERROR) << "Failed to fetch rubrics; error = " << e.what()
			<< " query = " << e.query();
		return 1;
	}
	return 0;
}
