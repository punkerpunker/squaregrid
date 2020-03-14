#include "grid_metadata.h"

#include <cmath>
#include <cassert>

#include <iostream>
#include <string>
#include <vector>

#include "easylogging++.h"

namespace grids {

using utils::GeoCoords;

GridMetadata::GridMetadata(
		float_t lat_min, float_t lat_max,
		float_t lng_min, float_t lng_max,
		float_t lat_step, float_t lng_step,
		int side,
		std::string region, std::string town, int id) {

	id_ = id;
	lat_bbox_[0] = lat_min;
	lat_bbox_[1] = lat_max;
	lng_bbox_[0] = lng_min;
	lng_bbox_[1] = lng_max;
	lat_step_ = lat_step;
	lng_step_ = lng_step;
	side_ = side;
	region_ = region;
	town_ = town;
}

int GridMetadata::GetId() const {
	return id_;
}

int GridMetadata::GetSide() const {
	return side_;
}

float_t GridMetadata::GetLatMin() const {
	return lat_bbox_[0];
}

float_t GridMetadata::GetLatMax() const {
	return lat_bbox_[1];
}

float_t GridMetadata::GetLngMin() const {
	return lng_bbox_[0];
}

float_t GridMetadata::GetLngMax() const {
	return lng_bbox_[1];
}

float_t GridMetadata::GetLatStep() const {
	return lat_step_;
}

float_t GridMetadata::GetLngStep() const {
	return lng_step_;
}

GeoCoords GridMetadata::GetSWCorner(int lat_i, int lng_j) const {
	return GeoCoords(
			lat_bbox_[0] + lat_i * lat_step_,
			lng_bbox_[0] + lng_j * lng_step_
	);
}

GeoCoords GridMetadata::GetCenter(int lat_i, int lng_j) const {
	auto p = GetSWCorner(lat_i, lng_j);
	return {p.lat + lat_step_ / 2, p.lng + lng_step_ / 2};
}

std::string GridMetadata::GetName() const {
	std::string name_raw = std::to_string(id_), name;
	while (name_raw.size() < 3) name_raw = "0" + name_raw;
	name_raw += "_" + region_ + "___" + town_;

	for (std::size_t i = 0; i < name_raw.size(); ++i) {
		if (name_raw[i] == ' ' || name_raw[i] == '-') {
			name += '_';
		} else if (name_raw[i] == ',') {
			name += "__";
		} else {
			name += name_raw[i];
		}
	}
	name += "_";
	name += std::to_string(2 * side_) + "x" + std::to_string(2 * side_);
	return name;
}

bool GridMetadata::GetSquareId(const GeoCoords &c, int *id) const {
	float_t lat = c.lat, lng = c.lng;
	if (!std::isfinite(lat) || !std::isfinite(lng)) return false;
	if (lat_bbox_[0] > lat || lat > lat_bbox_[1]) return false;
	if (lng_bbox_[0] > lng || lng > lng_bbox_[1]) return false;
	if (id != nullptr) {
		int x = std::floor((lat - lat_bbox_[0]) / lat_step_);
		int y = std::floor((lng - lng_bbox_[0]) / lng_step_);
		x = std::min(x, side_ * 2 - 1);
		y = std::min(y, side_ * 2 - 1);
		int dx = x - side_, dy = y - side_;
		int r = std::max({-dx, dx + 1, -dy, dy + 1});
		*id = 4 * (r - 1) * (r - 1);
		if (dy == -r) {
			*id += (dx + r);
		} else if (dx == r - 1) {
			*id += (2 * r + dy + r - 1);
		} else if (dy == r - 1) {
			*id += (4 * r - 1 + (r - 2 - dx));
		} else if (dx == -r) {
			*id += (6 * r - 2 + (r - 2 - dy));
		} else {
			assert(false);
		}
	}
	return true;
}

bool GridMetadata::GetSquareCoords(const GeoCoords &c, int *x, int *y) const {
	float_t lat = c.lat, lng = c.lng;
	if (!std::isfinite(lat) || !std::isfinite(lng)) return false;
	if (lat_bbox_[0] > lat || lat > lat_bbox_[1]) return false;
	if (lng_bbox_[0] > lng || lng > lng_bbox_[1]) return false;
	if (x != nullptr) {
		*x = std::min(
				(int) std::floor((lat - lat_bbox_[0]) / lat_step_),
				side_ * 2 - 1);
	}
	if (y != nullptr) {
		*y = std::min(
				(int) std::floor((lng - lng_bbox_[0]) / lng_step_),
				side_ * 2 - 1);
	}
	return true;
}

std::vector< std::pair<int, int> > EnumerateGridCells(int side) {
	std::vector< std::pair<int, int> > res;
	for (int r = 1; r <= side; ++r) {
		int dx = -r, dy = -r;
		const int dir[4][2] = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}};
		for (int j = 0; j < 4; ++j) {
			while (true) {
				if (j == 3 && dx == -r && dy == -r) break;
				if (!res.size() ||
						res.back().first != side + dx ||
						res.back().second != side + dy) {
					res.emplace_back(side + dx, side + dy);
				}
				dx += dir[j][0], dy += dir[j][1];
				if (std::max({-dx, dx + 1, -dy, dy + 1}) != r) {
					dx -= dir[j][0], dy -= dir[j][1];
					break;
				}
			}
		}
	}
	assert((int) res.size() == 4 * side * side);
	return res;
}

std::vector< std::vector<int> > GetGridCellsIds(int side) {
	std::vector< std::vector<int> > res(2 * side, std::vector<int>(2 * side));
	auto cells = EnumerateGridCells(side);
	for (size_t i = 0; i < cells.size(); ++i) {
		res[cells[i].first][cells[i].second] = i;
	}
	return res;
}

std::vector<GridMetadata> LoadGridMetadata(pqxx::connection *db_conn) {
	static const std::string &sql_query = std::string("SELECT ") +
		"city_id, latmin, latmax, longmin, longmax, latstep, longstep, " +
		"latlength, longlength, region, town FROM metadata.cities_grids where country_id = 0 " +
		"ORDER BY city_id;";
	try {
		std::vector<GridMetadata> regions;
		pqxx::work worker(*db_conn);
		pqxx::result res = worker.exec(sql_query);
		LOG(DEBUG) << "Fetched " << res.size() << " grids";
		for (const auto &grid: res) {
			assert(grid[7].as<int>() == grid[8].as<int>());
			regions.emplace_back(
					grid[1].as<float_t>(), grid[2].as<float_t>(),
					grid[3].as<float_t>(), grid[4].as<float_t>(),
					grid[5].as<float_t>(), grid[6].as<float_t>(),
					grid[7].as<int>(),
					grid[9].as<std::string>(), grid[10].as<std::string>(),
					grid[0].as<int>());
		}
		return regions;
	} catch (const pqxx::sql_error &e) {
		LOG(ERROR) << "Failed to fetch metadata.\nError:\n" << e.what()
			<< "\nQuery:" << e.query();
		return std::vector<GridMetadata>();
	}
}

}  // namespace grids
