#include <iostream>
#include <fstream>
#include <string>
#include <vector>

#include <gflags/gflags.h>
#include <easylogging++.h>

#include "grids/grid_metadata.h"

static bool ValidatePositive(const char*, int value) {
	return value > 0;
}

DEFINE_int32(grid_half_size, 0, "table with squares");
DEFINE_validator(grid_half_size, &ValidatePositive);
DEFINE_string(output, "", "Output file name");
DEFINE_string(delimiter, ",", "Delimiter");

int main(int argc, char **argv) {
	START_EASYLOGGINGPP(argc, argv);
	gflags::ParseCommandLineFlags(&argc, &argv, true);

	auto cells = grids::EnumerateGridCells(FLAGS_grid_half_size);
	std::ostream *out = (
			FLAGS_output.empty() ? &std::cout : new std::ofstream(FLAGS_output));
	(*out) << "id" << FLAGS_delimiter << "legacy_id" << std::endl;
	for (size_t id = 0; id < cells.size(); ++id) {
		(*out) << id << FLAGS_delimiter;
		(*out) << cells[id].first * 2 * FLAGS_grid_half_size + cells[id].second;
		(*out) << std::endl;
	}
	if (!FLAGS_output.empty()) {
		delete out;
	}
	return 0;
}
