from libcpp.vector cimport vector
from libcpp.utility cimport pair
from libcpp cimport bool as bool_t

from grids.pywrap_grid_metadata cimport GridMetadata
from processing.pywrap_data_grid cimport DataGrid
from utils.pywrap_common cimport GeoCoords, float_t

cdef extern from "processing/grid_forming.h" namespace "processing":
	void FillDataGrid[DataType](
		const vector[pair[GeoCoords, DataType]] &data,
		const GridMetadata &grid,
		bool_t exclude_most_common, float_t tolerance,
		DataGrid[DataType] *result)

