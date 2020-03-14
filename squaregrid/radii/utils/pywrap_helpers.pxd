from libcpp.vector cimport vector
from libcpp.map cimport map as std_map

cdef extern from "utils/helpers.h" namespace "utils":
	cdef cppclass AddableVector[DataType]:
		vector[DataType] data
		AddableVector[DataType] operator + (const AddableVector[DataType]&)

	cdef cppclass Averager[DataType]:
		DataType sum
		int count

		Averager[DataType] operator + (const Averager[DataType]&)

	cdef cppclass OccurrenceCounter[DataType]:
		std_map[DataType, int] data

		OccurrenceCounter[DataType] operator + (const OccurrenceCounter[DataType]&)
