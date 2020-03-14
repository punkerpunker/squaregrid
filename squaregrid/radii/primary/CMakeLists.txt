add_executable(data_mart_manager data_mart_manager.cc)
target_link_libraries(data_mart_manager proto_cpplib grid_metadata logging)
target_link_libraries(data_mart_manager ${Boost_LIBRARIES} gflags libpqxx pq pthread)

add_executable(calculate_radii_objects calculate_radii_objects.cc)
target_link_libraries(calculate_radii_objects logging grid_metadata table_creation)
target_link_libraries(calculate_radii_objects ${Boost_LIBRARIES} gflags libpqxx pq pthread)

add_executable(calculate_radii calculate_radii.cc)
target_link_libraries(calculate_radii table_creation logging)
target_link_libraries(calculate_radii ${Boost_LIBRARIES} gflags libpqxx pq pthread)

add_executable(calculate_radii_bin calculate_radii_bin.cc)
target_link_libraries(calculate_radii_bin table_creation logging)
target_link_libraries(calculate_radii_bin ${Boost_LIBRARIES} gflags libpqxx pq pthread)

add_executable(calculate_brands calculate_brands.cc)
target_link_libraries(calculate_brands table_creation logging)
target_link_libraries(calculate_brands ${Boost_LIBRARIES} gflags libpqxx pq pthread)

add_executable(calculate_traffic calculate_traffic.cc)
target_link_libraries(calculate_traffic logging grid_metadata)
target_link_libraries(calculate_traffic ${Boost_LIBRARIES} gflags libpqxx pq pthread)

add_executable(write_squares write_squares.cc)
target_link_libraries(write_squares grid_metadata logging)
target_link_libraries(write_squares gflags libpqxx pq pthread)

add_executable(legacy_square_ids legacy_square_ids.cc)
target_link_libraries(legacy_square_ids grid_metadata logging)
target_link_libraries(legacy_square_ids gflags pthread)

file(GLOB_RECURSE PYX_SOURCE_FILES *.pyx)
set_source_files_properties(${PYX_SOURCE_FILES} PROPERTIES CYTHON_IS_CXX TRUE)

cython_add_standalone_executable(make_data_mart MAIN_MODULE make_data_mart.py make_data_mart.py)

cython_add_standalone_executable(upload_layer MAIN_MODULE
	upload_layer.pyx upload_layer.pyx)
target_link_libraries(upload_layer grid_metadata logging)

cython_add_standalone_executable(locality_size MAIN_MODULE
	locality_size.pyx locality_size.pyx)
target_link_libraries(locality_size grid_metadata logging)

cython_add_standalone_executable(competitive_analysis MAIN_MODULE
	competitive_analysis.pyx competitive_analysis.pyx)
target_link_libraries(competitive_analysis grid_metadata logging)

cython_add_standalone_executable(pzt_generator MAIN_MODULE
	pzt_generator.pyx pzt_generator.pyx)
target_link_libraries(pzt_generator grid_metadata logging)

cython_add_standalone_executable(geoscore MAIN_MODULE
	geoscore.pyx geoscore.pyx)
target_link_libraries(geoscore grid_metadata logging)
