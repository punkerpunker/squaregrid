from utils.pywrap_common cimport float_t, GeoCoords

from libcpp.vector cimport vector
from libcpp.string cimport string
from libcpp.utility cimport pair
from libcpp cimport bool as bool_t

cdef extern from "grids/grid_metadata.h" namespace "grids":
	cdef cppclass GridMetadata:
		GridMetadata(
				float_t, float_t, float_t, float_t, float_t, float_t,
				int, string, string, int)

		bool_t GetSquareId(const GeoCoords&, int*)
		bool_t GetSquareCoords(const GeoCoords&, int*, int*)
		string GetName()

		int GetId()
		int GetSide()
		float_t GetLatMin()
		float_t GetLatMax()
		float_t GetLngMin()
		float_t GetLngMax()
		float_t GetLatStep()
		float_t GetLngStep()

		pair[float_t, float_t] GetNWCorner(int, int)
		pair[float_t, float_t] GetCenter(int, int)

	cdef vector[pair[int, int]] EnumerateGridCells(int)
	cdef vector[vector[int]] GetGridCellsIds(int)

cdef class PywrapGridMetadata:
	cdef GridMetadata* c_grid
