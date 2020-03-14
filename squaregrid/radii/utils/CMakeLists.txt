add_library(logging STATIC logging.h logging.cc)
target_link_libraries(logging easyloggingpp)

add_library(utils_common INTERFACE)
target_sources(utils_common INTERFACE ${CMAKE_SOURCE_DIR}/utils/common.h)
