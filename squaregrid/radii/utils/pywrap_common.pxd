ctypedef float float_t

cdef extern from "utils/common.h" namespace "utils":
	cdef cppclass GeoCoords:
		float_t lat
		float_t lng

		GeoCoords()
		GeoCoords(float_t, float_t)
