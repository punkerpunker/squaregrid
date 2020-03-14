#pragma once

#include <algorithm>
#include <cmath>
#include <vector>

#include "grids/grid_metadata.h"
#include "processing/data_grid.h"
#include "utils/common.h"

namespace processing {

using utils::GeoCoords;

template<typename DataType> void FillDataGrid(
		const std::vector< std::pair<GeoCoords, DataType> > &data,
		const grids::GridMetadata &grid,
		bool exclude_most_common, float_t tolerance,
		DataGrid<DataType> *result) {
	auto equal = [tolerance](
			const std::pair<GeoCoords, DataType> &a,
			const std::pair<GeoCoords, DataType> &b) {
		return (
				std::abs(a.first.lat - b.first.lat) < tolerance &&
				std::abs(a.first.lng - b.first.lng) < tolerance);
	};

	auto compare = [](
			const std::pair<GeoCoords, DataType> &a,
			const std::pair<GeoCoords, DataType> &b) {
		return (
				std::make_pair(a.first.lat, a.first.lng) <
				std::make_pair(b.first.lat, b.first.lng));
	};


	*result = DataGrid<DataType>(grid);
	std::vector< std::pair<GeoCoords, DataType> > coords;
	for (const auto &row : data) {
		float_t lat = row.first.lat, lng = row.first.lng;
		if (grid.GetLatMin() <= lat && lat <= grid.GetLatMax() &&
				grid.GetLngMin() <= lng && lng <= grid.GetLngMax()) {
				coords.emplace_back(row);
		}
	}

	if (exclude_most_common && data.size() > 0) {
		std::sort(coords.begin(), coords.end(), compare);
		int max_cnt = 1, cur_cnt = 1;
		auto max_it = coords.end();
		for (auto it = ++coords.begin(); it != coords.end(); ++it) {
			cur_cnt += equal(*it, *(it - 1)) ? 1 : -cur_cnt;
			if (cur_cnt > max_cnt) {
				max_cnt = cur_cnt;
				max_it = it;
			}
		}
		auto it = max_it;
		while (it != coords.begin() && equal(*(it - 1), *it)) --it;
		coords.erase(it, max_it + 1);
	}

	for (const auto &row : coords) {
		float_t lat = row.first.lat;
		float_t lng = row.first.lng;
		int x = std::floor((lat - grid.GetLatMin()) / grid.GetLatStep());
		int y = std::floor((lng - grid.GetLngMin()) / grid.GetLngStep());
		x = std::min(x, grid.GetSide() * 2 - 1);
		y = std::min(y, grid.GetSide() * 2 - 1);
		(*result)[x][y] += row.second;
	}
}

}  // namespace processing
