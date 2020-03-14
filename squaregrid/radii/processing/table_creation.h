#pragma once

#include <vector>
#include <string>

#include <boost/asio/io_service.hpp>
#include <boost/bind.hpp>
#include <boost/thread/thread.hpp>
#include <easylogging++.h>
#include <pqxx/pqxx>

#include "utils/common.h"
#include "grids/grid_metadata.h"
#include "processing/data_grid.h"
#include "processing/grid_forming.h"
#include "processing/radii_summation.h"
#include "processing/radii_writer.h"

namespace processing {

template<typename DataType> void _ProcessGrid(
		const std::string &connection_string,
		const grids::GridMetadata &grid,
		const std::vector< std::pair<GeoCoords, DataType> > &values,
		const std::string output_table,
		bool exclude_most_common,
		float_t tolerance,
		int radii_count) {
	try {
		pqxx::connection conn(connection_string);
		processing::DataGrid<DataType> data_grid(0, 0);
		processing::FillDataGrid(
				values, grid, exclude_most_common, tolerance, &data_grid);

		std::vector< processing::DataGrid<DataType> > radii;
		processing::CalculateRadii(data_grid, radii_count, &radii, false);
		processing::RadiiWriter<DataType> writer(&conn, output_table);
		writer.WriteRadii(grid, radii);
		LOG(INFO) << "Finished grid " << grid.GetName() << " in " << output_table;
	} catch (const pqxx::sql_error &e) {
		LOG(ERROR) << "SQL error. Grid " << grid.GetName()
		           << "\nerror = " << e.what()
		           << "\nquery = " << e.query();
		return;
	}
}

template <typename InputDataType, typename ProcessingDataType>
void CreateRadiiTableFromSQLConcurrently(
		const std::string &connection_string,
		const std::vector<grids::GridMetadata> &grids,
		const std::string &sql_query, const std::string &output_table,
		int radii_count,
		bool exclude_most_common, float_t tolerance,
		int threads) {
	try {
		pqxx::result data;
		std::vector< std::pair<GeoCoords, ProcessingDataType> > values;
		do {
			pqxx::connection conn(connection_string);
			pqxx::work trans(conn);
			data = trans.exec(sql_query);
			if (data.size() > 0) {
				int skipped = 0;
				for (size_t i = 0; i < data.size(); ++i) {
					try {
						values.emplace_back(
								GeoCoords{data[i][0].as<float_t>(), data[i][1].as<float_t>()},
								(data[i].size() > 2) ? data[i][2].as<InputDataType>() : 1);
					} catch (pqxx::conversion_error &e) {
						++skipped;
						continue;
					}
				}
				if (skipped) {
					LOG(WARNING) << skipped << " rows skipped because of null values";
				}
			}
			trans.commit();

			processing::RadiiWriter<ProcessingDataType> writer(&conn, output_table);
			writer.ResetTable(radii_count);
		} while (false);

		boost::asio::io_service io_service;
		boost::thread_group threadpool;

		do {
			boost::asio::io_service::work work(io_service);
			for (int i = 0; i < threads; ++i) {
				threadpool.create_thread(
						boost::bind(&boost::asio::io_service::run, &io_service));
			}
			for (size_t i = 0; i < grids.size(); ++i) {
				io_service.post(boost::bind(
							_ProcessGrid<ProcessingDataType>, connection_string, grids[i],
							values, output_table,
							exclude_most_common, tolerance, radii_count));
			}
		} while (false);
		threadpool.join_all();
		io_service.stop();
	} catch (const pqxx::sql_error &e) {
		LOG(ERROR) << "SQL error"
		           << "\nerror = " << e.what()
		           << "\nquery = " << e.query();
	}
}

}  // namespace processing
