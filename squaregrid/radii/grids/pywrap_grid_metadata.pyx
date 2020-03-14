from grids.pywrap_grid_metadata cimport GridMetadata
from utils.pywrap_common cimport GeoCoords

from libcpp.string cimport string

import logging

cdef class PywrapGridMetadata:
	def __cinit__(
			self, float_t a0, float_t a1, float_t a2, float_t a3, float_t a4,
			float_t a5, int a6, string a7, string a8, int a9):
		self.c_grid = new GridMetadata(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9)

	def __dealloc__(self):
		del self.c_grid

	def assign_square(self, lat, lng):
		cdef GeoCoords g
		g.lat = lat
		g.lng = lng
		cdef int square_id
		if not self.c_grid.GetSquareId(g, &square_id):
			return None
		return square_id

	def lat_bbox(self):
		return (self.c_grid.GetLatMin(), self.c_grid.GetLatMax())

	def lng_bbox(self):
		return (self.c_grid.GetLngMin(), self.c_grid.GetLngMax())

	def GetId(self):
		return self.c_grid.GetId()


def LoadGridsMetadata(engine):
	sql_query = (
		"SELECT city_id, latmin, latmax, longmin, longmax, latstep, "
		"longstep, latlength, longlength, region, town FROM metadata.cities_grids where country_id = 0 "
		"ORDER BY city_id;"
	)
	try:
		grids = list()
		tuples = list(engine.execute(sql_query))
		logging.debug('Fetched %d grids' % len(tuples))
		for grid_tuple in tuples:
			assert(grid_tuple[7] == grid_tuple[8])
			grids.append(PywrapGridMetadata(
					grid_tuple[1], grid_tuple[2],
					grid_tuple[3], grid_tuple[4],
					grid_tuple[5], grid_tuple[6],
					grid_tuple[7],
					grid_tuple[9].encode('utf-8'), grid_tuple[10].encode('utf-8'),
					grid_tuple[0])
			)
		return grids
	except Exception as e:
		logging.error('Failed to fetch metadata')
		logging.exception(e)
		return list()

