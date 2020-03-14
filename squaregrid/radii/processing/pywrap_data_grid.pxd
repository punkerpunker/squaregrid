from libcpp.vector cimport vector

from grids.pywrap_grid_metadata cimport GridMetadata

cdef extern from "processing/data_grid.h" namespace "processing":
	cdef cppclass DataGrid[DataType]:
		DataGrid(const GridMetadata&)
		DataGrid(const DataGrid[DataType]&)
		DataGrid()
		DataGrid(int)
		DataGrid(int, int)

		vector[DataType]& operator[](int)
		vector[vector[DataType]]& data()

		int NumRows() const
		int NumCols() const
