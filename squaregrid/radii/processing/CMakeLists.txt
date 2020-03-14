add_library(data_grid INTERFACE)
target_sources(data_grid INTERFACE ${CMAKE_SOURCE_DIR}/processing/data_grid.h)
target_include_directories(data_grid INTERFACE ${CMAKE_SOURCE_DIR}/processing)

add_library(grid_forming INTERFACE)
target_sources(grid_forming INTERFACE ${CMAKE_SOURCE_DIR}/processing/grid_forming.h)
target_link_libraries(grid_forming INTERFACE data_grid utils_common grid_metadata)
target_include_directories(grid_forming INTERFACE ${CMAKE_SOURCE_DIR}/processing)

add_library(radii_summation INTERFACE)
target_sources(radii_summation INTERFACE ${CMAKE_SOURCE_DIR}/processing/radii_summation.h)
target_link_libraries(radii_summation INTERFACE data_grid)
target_include_directories(radii_summation INTERFACE ${CMAKE_SOURCE_DIR}/processing)

add_library(radii_writer INTERFACE)
target_sources(radii_writer INTERFACE ${CMAKE_SOURCE_DIR}/processing/radii_writer.h)
target_link_libraries(radii_writer INTERFACE data_grid)
target_link_libraries(radii_writer INTERFACE libpqxx pq)
target_include_directories(radii_writer INTERFACE ${CMAKE_SOURCE_DIR}/processing)

add_library(table_creation INTERFACE)
target_sources(table_creation INTERFACE ${CMAKE_SOURCE_DIR}/processing/table_creation.h)
target_link_libraries(table_creation INTERFACE data_grid utils_common grid_forming radii_summation radii_writer logging)
target_link_libraries(table_creation INTERFACE libpqxx pq)
target_link_libraries(table_creation INTERFACE ${Boost_LIBRARIES})
target_include_directories(table_creation INTERFACE ${CMAKE_SOURCE_DIR}/processing)

cython_add_standalone_executable(geocoder MAIN_MODULE geocoder.py geocoder.py)
