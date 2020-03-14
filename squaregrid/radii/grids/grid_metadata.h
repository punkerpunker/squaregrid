#pragma once

#include <vector>
#include <string>

#include <pqxx/pqxx>

#include "utils/common.h"

namespace grids {

class GridMetadata {
	public:
		GridMetadata(
				float_t lat_min, float_t lat_max,
				float_t lng_min, float_t lng_max,
				float_t lat_step, float_t lng_step,
				int side,
				std::string region, std::string town, int id);

		bool GetSquareId(const utils::GeoCoords &c, int *id) const;
		bool GetSquareCoords(const utils::GeoCoords &c, int *x, int *y) const;
		std::string GetName() const;

		int GetId() const;
		int GetSide() const;
		float_t GetLatMin() const;
		float_t GetLatMax() const;
		float_t GetLngMin() const;
		float_t GetLngMax() const;
		float_t GetLatStep() const;
		float_t GetLngStep() const;

		utils::GeoCoords GetSWCorner(int lat_i, int lng_j) const;
		utils::GeoCoords GetCenter(int lat_i, int lng_j) const;

	private:
		int id_;
		float_t lat_bbox_[2], lng_bbox_[2];
		float_t lat_step_, lng_step_;
		int side_;
		std::string region_, town_;
};

std::vector< std::pair<int, int> > EnumerateGridCells(int side);
std::vector< std::vector<int> > GetGridCellsIds(int side);
std::vector<GridMetadata> LoadGridMetadata(pqxx::connection *db_conn);

}  // namespace grids
