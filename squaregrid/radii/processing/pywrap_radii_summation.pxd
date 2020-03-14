from libcpp.vector cimport vector
from libcpp cimport bool as bool_t

from processing.pywrap_data_grid cimport DataGrid

cdef extern from "processing/radii_summation.h" namespace "processing":
	void CalculateRadii[DataType](
			const DataGrid[DataType] &grid, int radii_count,
			vector[DataGrid[DataType]] *result,
			bool_t cumulative)
