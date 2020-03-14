include_directories(${GTEST_INCLUDE_DIRS})

file(GLOB_RECURSE TESTS_SOURCE_FILES ${CMAKE_SOURCE_DIR}/tests/test_*.cc)
set(TESTS_SOURCE_FILES ${TESTS_SOURCE_FILES} tests_main.cc)

add_executable(tests ${TESTS_SOURCE_FILES})
target_link_libraries(tests gtest grid_metadata easyloggingpp ${Boost_LIBRARIES})
add_test(AllTests tests)
