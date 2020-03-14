#include <iostream>
#include <string>
#include <tuple>
#include <vector>
#include <set>

#include <gflags/gflags.h>
#include <pqxx/pqxx>
#include <easylogging++.h>

#include "grids/grid_metadata.h"

static bool ValidateNonEmpty(const char*, const std::string &value) {
	return !value.empty();
}

static bool IsChar(const char*, const std::string &value) {
	return value.size() == 1;
}

DEFINE_string(dbhost, "10.0.0.24", "Address of DB to connect");
DEFINE_validator(dbhost, &ValidateNonEmpty);
DEFINE_int32(dbport, 5432, "Port where DB is serving");
DEFINE_string(dbname, "mldata", "database name");
DEFINE_string(dbuser, "marketinglogic", "database user");
DEFINE_string(dbpass, "", "database password");
DEFINE_validator(dbpass, &ValidateNonEmpty);

DEFINE_string(table_name, "", "table with squares");
DEFINE_validator(table_name, &ValidateNonEmpty);

std::string GetConnectionString() {
	std::string connection_string;
	connection_string += "host=" + FLAGS_dbhost;
	connection_string += " port=" + std::to_string(FLAGS_dbport);
	connection_string += " dbname=" + FLAGS_dbname;
	connection_string += " user=" + FLAGS_dbuser;
	connection_string += " password=" + FLAGS_dbpass;
	return connection_string;
}

void CreateSquareTable(pqxx::connection *conn, const std::string &name) {
	pqxx::work trans(*conn);
	trans.exec("DROP TABLE IF EXISTS " + name + ";");
	std::string query = "CREATE TABLE " + name +
		" (city_id integer, square_id integer, legacy_square_id integer";
	for (const std::string& col :
			{"center", "corner_nw", "corner_ne", "corner_sw", "corner_se"}) {
		query += ", " + col + " point";
	}
	query += ", UNIQUE (city_id, square_id));";
	trans.exec(query);
	trans.commit();
}

int main(int argc, char **argv) {
	START_EASYLOGGINGPP(argc, argv);
	el::Loggers::reconfigureAllLoggers(
			el::ConfigurationType::Filename, "logs/write_squares.log");
	gflags::ParseCommandLineFlags(&argc, &argv, true);

	std::vector<grids::GridMetadata> grids, ng;

	pqxx::connection db_conn(GetConnectionString());
	grids = grids::LoadGridMetadata(&db_conn);

	std::set<int> ss({2001, 2123, 2124, 2126, 2006, 1999});
	for (size_t i = 0; i < grids.size(); ++i) {
		if (ss.count(grids[i].GetId())) {
			ng.push_back(grids[i]);
		}
	}
	grids = ng;

	//CreateSquareTable(&db_conn, FLAGS_table_name);
	db_conn.prepare("insert_square", "INSERT INTO " + FLAGS_table_name +
			" VALUES ($1, $2, $3, point($4, $5), point($6, $7), point($8, $9) " +
			", point($10, $11), point($12, $13))");

	for (const auto &grid : grids) {
		LOG(INFO) << grid.GetName();
		pqxx::work trans(db_conn);
		auto cells = grids::EnumerateGridCells(grid.GetSide());
		for (size_t id = 0; id < cells.size(); ++id) {
			int lat_i = cells[id].first, lng_j = cells[id].second;
			auto query = trans.prepared("insert_square")
				(grid.GetId())(id)(lat_i * grid.GetSide() * 2 + lng_j)
				(grid.GetCenter(lat_i, lng_j).lat)
				(grid.GetCenter(lat_i, lng_j).lng)
				(grid.GetSWCorner(lat_i + 1, lng_j).lat)
				(grid.GetSWCorner(lat_i + 1, lng_j).lng)
				(grid.GetSWCorner(lat_i + 1, lng_j + 1).lat)
				(grid.GetSWCorner(lat_i + 1, lng_j + 1).lng)
				(grid.GetSWCorner(lat_i, lng_j).lat)
				(grid.GetSWCorner(lat_i, lng_j).lng)
				(grid.GetSWCorner(lat_i, lng_j + 1).lat)
				(grid.GetSWCorner(lat_i, lng_j + 1).lng);
			query.exec();
		}
		trans.commit();
	}
	return 0;
}
