#include <vector>
#include <tuple>

#include <gtest/gtest.h>

#include "utils/common.h"
#include "grids/grid_metadata.h"
#include "processing/data_grid.h"
#include "processing/grid_forming.h"

using utils::GeoCoords;

TEST(TestGridForming, TestFillDataGrid) {
	std::vector< std::pair<GeoCoords, int> > data = {
		std::make_pair(GeoCoords{10., 10.}, 1),
		std::make_pair(GeoCoords{11., 11.}, 500),
		std::make_pair(GeoCoords{10., 20.}, 2),
		std::make_pair(GeoCoords{15., 10.}, 4),
		std::make_pair(GeoCoords{20., 20.}, 8),
		std::make_pair(GeoCoords{15., 15.}, 16),
	};
	std::vector<grids::GridMetadata> grids = {
		grids::GridMetadata(9., 17, 9., 17., 4., 4., 1, "a", "b", 0),
		grids::GridMetadata(13., 21., 13., 21., 4., 4., 1, "c", "d", 1),
	};

	std::vector< std::vector< std::vector<int> > > expected_result = {
		{{501, 0}, {4, 16}},
		{{16, 0}, {0, 8}},
	};

	for (size_t i = 0; i < grids.size(); ++i) {
		processing::DataGrid<int> result(0);
		processing::FillDataGrid(data, grids[i], false, 0, &result);

		EXPECT_EQ(result.data(), expected_result[i]);
	}
}
