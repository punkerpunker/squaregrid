#include <vector>

#include <gtest/gtest.h>

#include "utils/common.h"
#include "grids/grid_metadata.h"
#include "processing/data_grid.h"
#include "processing/radii_summation.h"

TEST(TestRadiiSummation, TestCalculateRadii) {
	int n = 4, radii = 2;
	std::vector< std::vector<int> > input(n, std::vector<int>(n));
	processing::DataGrid<int> grid(n, n);
	for (int i = 0; i < n; ++i) {
		for (int j = 0; j < n; ++j) {
			input[i][j] = 1 << (i * n + j);
			grid[i][j] =  1 << (i * n + j);
		}
	}
	std::vector< std::vector< std::pair<int, int> > > shifts = {
		{{0, 0}},
		{{-1, -1}, {-1, 0}, {-1, 1}, {0, -1}, {0, 1}, {1, -1}, {1, 0}, {1, 1}},
		{
			{-2, -1}, {-2, 0}, {-2, 1}, {-1, -2}, {-1, 2}, {0, -2}, {0, 2}, {1, -2},
			{1, 2}, {2, -1}, {2, 0}, {2, 1}
		},
	};
	std::vector< std::vector< std::vector<int> > > expected_result;
	for (int it = 0; it <= radii; ++it) {
		expected_result.emplace_back(n, std::vector<int>(n));
		for (int i = 0; i < n; ++i) {
			for (int j = 0; j < n; ++j) {
				for (const auto &p: shifts[it]) {
					int ni = i + p.first, nj = j + p.second;
					if (ni < 0 || nj < 0 || ni >= n || nj >= n) continue;
					expected_result[it][i][j] += input[ni][nj];
				}
			}
		}
	}
	std::vector< processing::DataGrid<int> > result;
	processing::CalculateRadii(grid, radii, &result, false);
	ASSERT_EQ(result.size(), radii + 1);
	for (int it = 0; it <= radii; ++it) {
		EXPECT_EQ(result[it].data(), expected_result[it]);
	}
}
