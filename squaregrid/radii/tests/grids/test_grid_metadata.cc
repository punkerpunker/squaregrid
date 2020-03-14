#include <vector>

#include <gtest/gtest.h>

#include "utils/common.h"
#include "grids/grid_metadata.h"

using utils::GeoCoords;

TEST(TestGridMetadata, TestGridNumeration) {
	int side = 3;
	grids::GridMetadata metadata(
			0, 2 * side, 0, 2 * side, 1, 1, side, "x", "y", 0);
	std::vector< std::vector<int> > expected_numeration = {
		{16, 35, 34, 33, 32, 31},
		{17,  4, 15, 14, 13, 30},
		{18,  5,  0,  3, 12, 29},
		{19,  6,  1,  2, 11, 28},
		{20,  7,  8,  9, 10, 27},
		{21, 22, 23, 24, 25, 26},
	};

	auto result = grids::GetGridCellsIds(side);
	EXPECT_EQ(result, expected_numeration);
	auto cells = grids::EnumerateGridCells(side);
	EXPECT_EQ(cells.size(), 4 * side * side);
	for (size_t i = 0; i < cells.size(); ++i) {
		const auto &p = cells[i];
		EXPECT_EQ(expected_numeration[p.first][p.second], i);
	}
	for (int i = 0; i < 2 * side; ++i) {
		for (int j = 0; j < 2 * side; ++j) {
			const float eps = 1e-6;
			int id;
			EXPECT_TRUE(metadata.GetSquareId(GeoCoords(i + eps, j + eps), &id));
			EXPECT_EQ(id, expected_numeration[i][j]);
			EXPECT_TRUE(metadata.GetSquareId(GeoCoords(i + 1 - eps, j + eps), &id));
			EXPECT_EQ(id, expected_numeration[i][j]);
			EXPECT_TRUE(metadata.GetSquareId(GeoCoords(i + eps, j + 1 - eps), &id));
			EXPECT_EQ(id, expected_numeration[i][j]);
			EXPECT_TRUE(
					metadata.GetSquareId(GeoCoords(i + 1 - eps, j + 1 - eps), &id));
			EXPECT_EQ(id, expected_numeration[i][j]);
			EXPECT_TRUE(metadata.GetSquareId(GeoCoords(i + 0.5, j + 0.5), &id));
			EXPECT_EQ(id, expected_numeration[i][j]);
		}
	}
}
