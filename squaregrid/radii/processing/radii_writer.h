#pragma once

#include <algorithm>
#include <string>
#include <vector>

#include <pqxx/pqxx>
#include <pqxx/tablewriter>

#include "processing/data_grid.h"

namespace processing {

template<typename DataType> class RadiiWriter {
	public:
		RadiiWriter(pqxx::connection *conn, const std::string &table)
				: conn_(conn), table_(table), changed_type_(false) {}

		void ResetTable(int max_R) {
			pqxx::work trans(*conn_);

			std::string query = "DROP TABLE IF EXISTS " + table_;
			trans.exec(query);

			query = "CREATE TABLE " + table_ + " (city_id integer, square_id integer";
			for (int i = 0; i <= max_R; ++i) {
				query += ", _" + std::to_string(i * 100) + " ";
				query += "smallint";
			}
			query += ", UNIQUE (city_id, square_id)) TABLESPACE md0space;";
			trans.exec(query);
			trans.commit();
		}

		void WriteRadii(
				const grids::GridMetadata &grid,
				const std::vector< DataGrid<DataType> > &radii) {

			int n = radii[0].data().size(), R = radii.size();
			auto cells = grids::EnumerateGridCells(n / 2);

			{
				// hack for shortint DB values
				int max_value;
				for (size_t id = 0; id < cells.size(); ++id) {
					auto p = cells[id];
					for (int i = 0; i < R; ++i) {
						max_value = std::max(max_value, (int) radii[i][p.first][p.second]);
					}
				}
				if (max_value >= (1 << 15)) {
					ChangeColumnTypes_(R - 1);
				}
			}

			pqxx::work trans(*conn_);
			pqxx::tablewriter writer(trans, table_);
			for (size_t id = 0; id < cells.size(); ++id) {
				auto p = cells[id];
				bool empty = true;
				for (int i = 0; i < R; ++i) {
					empty &= radii[i][p.first][p.second] == DataType();
				}
				if (!empty) {
					std::vector<int> row = {grid.GetId(), (int) id};
					for (int i = 0; i < R; ++i) {
						row.push_back((int) radii[i][p.first][p.second]);
					}
					writer.insert(row);
				}
			}
			writer.complete();
			trans.commit();
		}

	private:
		pqxx::connection *conn_;
		std::string table_;
		bool changed_type_;

		void ChangeColumnTypes_(int count) {
			pqxx::work trans(*conn_);
			if (changed_type_) return;
			for (int i = 0; i <= count; ++i) {
				std::string query = (
						"ALTER TABLE " + table_ +
						" ALTER COLUMN _" + std::to_string(i * 100) +
						" SET DATA TYPE integer;");
				trans.exec(query);
			}
			changed_type_ = true;
			trans.commit();
		}

};

}  // namespace processing
