add_library(grid_metadata STATIC grid_metadata.h grid_metadata.cc)
target_link_libraries(grid_metadata easyloggingpp libpqxx pq)

set_source_files_properties(
  ${CMAKE_SOURCE_DIR}/grids/pywrap_grid_metadata.pyx
  PROPERTIES CYTHON_IS_CXX TRUE)
cython_add_module(pywrap_grid_metadata pywrap_grid_metadata.pyx grid_metadata.cc
	grid_metadata.h)
target_link_libraries(pywrap_grid_metadata logging libpqxx pq)
