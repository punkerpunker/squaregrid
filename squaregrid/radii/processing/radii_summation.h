#pragma once

#include <cmath>
#include <vector>

#include "processing/data_grid.h"

namespace processing {

template <typename DataType> void CalculateRadii(
		const DataGrid<DataType> &grid,
		int max_R,
		std::vector< DataGrid<DataType> > *result,
		bool cumulative) {

	std::vector< std::tuple<int, int, int> > radii;
	for (int x = -max_R ; x <= max_R; x++) {
		for (int y = -max_R ; y <= max_R; y++) {
			float_t x_ = x, y_ = y;
			if (x > 0) x_ = x + 0.5;
			if (x < 0) x_ = x - 0.5;
			if (y > 0) y_ = y + 0.5;
			if (y < 0) y_ = y - 0.5;

			int radius = std::max(0, int(std::round(std::hypot(x_, y_))) - 1);
			if (radius > max_R) continue;
			radii.emplace_back(radius, x, y);
		}
	}

	*result = std::vector< DataGrid<DataType> >(
			max_R + 1, grid.data().size());

	int n = grid.data().size();
	for (int x = 0; x < n; ++x) {
		for (int y = 0; y < n; ++y) {
			for (const auto &t: radii) {
				int nx = x + std::get<1>(t), ny = y + std::get<2>(t);
				if (nx < 0 || nx >= n || ny < 0 || ny >= n) continue;
				(*result)[std::get<0>(t)][x][y] += grid[nx][ny];
			}
		}
	}
	if (cumulative) {
		for (int t = 1; t <= max_R; ++t) {
			for (int x = 0; x < n; ++x) {
				for (int y = 0; y < n; ++y) {
					(*result)[t][x][y] += (*result)[t - 1][x][y];
				}
			}
		}
	}
}

}  // namespace processing
