#pragma once

#include <utility>

typedef float float_t;

namespace utils {
	struct GeoCoords {
		float_t lat, lng;

		GeoCoords() {}
		GeoCoords(float_t nlat, float_t nlng): lat(nlat), lng(nlng) {}
	};
}
