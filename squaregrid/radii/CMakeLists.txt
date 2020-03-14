cmake_minimum_required(VERSION 3.0)
project(MarketingLogicTools VERSION 0.1)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake/")

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17 -fPIC")
set(CMAKE_CXX_FLAGS_DEBUG
	"${CMAKE_CXX_FLAGS_DEBUG} -Wall -Wextra -pedantic\
	-Wshadow -Wformat=2 -Wfloat-equal -Wconversion -Wlogical-op -Wcast-qual\
	-Wcast-align -fsanitize=address -fsanitize=undefined -fno-sanitize-recover")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O2")
include_directories(${CMAKE_SOURCE_DIR})
include_directories(${CMAKE_CURRENT_BINARY_DIR})

add_custom_target(ReplicateSourceTree ALL ${CMAKE_COMMAND} -P
  ${CMAKE_CURRENT_SOURCE_DIR}/cmake/ReplicateSourceTree.cmake
  ${CMAKE_CURRENT_BINARY_DIR}
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})

# External dependencies

# cython
include(UseCython)
set(ENV${PYTHONPATH} ${CMAKE_CURRENT_SOURCE_DIR})

# gtest
set(GTEST_INCLUDE_DIRS ${CMAKE_SOURCE_DIR}/external/googletest/googletest/include)
set(GTEST_SOURCE_DIRS ${CMAKE_SOURCE_DIR}/external/googletest/googletest/src)
enable_testing()
set(CMAKE_POLICY_DEFAULT_CMP0048 OLD)
add_subdirectory(external/googletest external/googletest)

## libpqxx
file(GLOB_RECURSE LIBPQXX_SOURCE_FILES
	${CMAKE_SOURCE_DIR}/external/libpqxx/src/*.cxx
)

add_library(libpqxx STATIC ${LIBPQXX_SOURCE_FILES})
target_compile_definitions(libpqxx PUBLIC -DPQXX_HAVE_STD_ISNAN)
target_compile_definitions(libpqxx PUBLIC -DPQXX_HAVE_STD_ISINF)
include_directories(
	${CMAKE_SOURCE_DIR}/external/libpqxx/include/
	# TODO: below is hack
	${CMAKE_SOURCE_DIR}/external/libpqxx/config/sample-headers/compiler/gcc-4.4/
	/usr/include/postgresql
)

## easylogging++
file(GLOB_RECURSE EASYLOGGINGPP_SOURCE_FILES
	${CMAKE_SOURCE_DIR}/external/easyloggingpp/src/*.cc
)
include_directories(
	${CMAKE_SOURCE_DIR}/external/easyloggingpp/src
)
add_definitions(-DELPP_THREAD_SAFE)
add_library(easyloggingpp STATIC ${EASYLOGGINGPP_SOURCE_FILES})

# boost
set(Boost_USE_STATIC_LIBS ON)
set(Boost_USE_MULTITHREADED ON)
set(Boost_USE_STATIC_RUNTIME ON)
find_package(Boost 1.58 COMPONENTS system filesystem thread REQUIRED)
include_directories(${Boost_INCLUDE_DIR})

# protobuf
set(Protobuf_IMPORT_DIRS ${CMAKE_SOURCE_DIR})
find_package(Protobuf REQUIRED)
find_package(GRPC REQUIRED)
include_directories(${PROTOBUF_INCLUDE_DIR})

file(GLOB_RECURSE PROTO_FILES ${CMAKE_SOURCE_DIR}/*.proto)
PROTOBUF_GENERATE_GRPC_CPP(PROTO_CPP_GRPC_SRC PROTO_CPP_GRPC_HDR "${PROTO_FILES}")
add_library(proto_cpplib STATIC
	${PROTO_CPP_GRPC_SRC} ${PROTO_CPP_GRPC_HDR})
target_link_libraries(proto_cpplib ${PROTOBUF_LIBRARY} grpc++ grpc++_reflection ssl)
PROTOBUF_GENERATE_GRPC_PY(PROTO_GRPC_PY proto_pylib "${PROTO_FILES}")

# gflags
set(GFLAGS_BUILD_SHARED_LIBS OFF)
set(GFLAGS_BUILD_STATIC_LIBS ON)
set(GFLAGS_BUILD_gflags_LIB ON)
set(GFLAGS_BUILD_gflags_nothreads_LIB OFF)
set(GFLAGS_IS_SUBPROJECT TRUE)
add_subdirectory(external/gflags external/gflags)
include_directories(
  ${CMAKE_SOURCE_DIR}/external/gflags/include/
)

add_subdirectory(utils utils)
add_subdirectory(grids grids)
add_subdirectory(processing processing)
add_subdirectory(primary primary)
add_subdirectory(tests tests)
