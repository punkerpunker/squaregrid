find_program(GRPC_CPP_PLUGIN grpc_cpp_plugin) # Get full path to plugin

find_library(GRPC_LIBRARY NAMES grpc)
find_library(GRPCPP_LIBRARY NAMES grpc++)
find_library(GPR_LIBRARY NAMES gpr)
set(GRPC_LIBRARIES ${GRPCPP_LIBRARY} ${GRPC_LIBRARY} ${GPR_LIBRARY})
if(GRPC_LIBRARIES)
	message(STATUS "Found GRPC: ${GRPC_LIBRARIES}; plugin - ${GRPC_CPP_PLUGIN}")
endif()


function(PROTOBUF_GENERATE_GRPC_CPP SRCS HDRS)
	if(NOT ARGN)
		message(SEND_ERROR "Error: PROTOBUF_GENERATE_GRPC_CPP() called without any proto files")
		return()
	endif()

	if(PROTOBUF_GENERATE_CPP_APPEND_PATH) # This variable is common for all types of output.
		# Create an include path for each file specified
		foreach(FIL ${ARGN})
			get_filename_component(ABS_FIL ${FIL} ABSOLUTE)
			get_filename_component(ABS_PATH ${ABS_FIL} PATH)
			list(FIND _protobuf_include_path ${ABS_PATH} _contains_already)
			if(${_contains_already} EQUAL -1)
				list(APPEND _protobuf_include_path -I ${ABS_PATH})
			endif()
		endforeach()
	else()
		set(_protobuf_include_path -I ${CMAKE_CURRENT_SOURCE_DIR})
	endif()

	if(DEFINED PROTOBUF_IMPORT_DIRS)
		foreach(DIR ${PROTOBUF_IMPORT_DIRS})
			get_filename_component(ABS_PATH ${DIR} ABSOLUTE)
			list(FIND _protobuf_include_path ${ABS_PATH} _contains_already)
			if(${_contains_already} EQUAL -1)
				list(APPEND _protobuf_include_path -I ${ABS_PATH})
			endif()
		endforeach()
	endif()

	set(${SRCS})
	set(${HDRS})
	foreach(FIL ${ARGN})
		get_filename_component(ABS_FIL ${FIL} ABSOLUTE)
		get_filename_component(FIL_WE ${FIL} NAME_WE)
		get_filename_component(FIL_DIR ${ABS_FIL} DIRECTORY)

		file(RELATIVE_PATH REL_DIR ${CMAKE_SOURCE_DIR} ${FIL_DIR})

		list(APPEND ${SRCS} "${CMAKE_CURRENT_BINARY_DIR}/${REL_DIR}/${FIL_WE}.pb.cc")
		list(APPEND ${HDRS} "${CMAKE_CURRENT_BINARY_DIR}/${REL_DIR}/${FIL_WE}.pb.h")
		list(APPEND ${SRCS} "${CMAKE_CURRENT_BINARY_DIR}/${REL_DIR}/${FIL_WE}.grpc.pb.cc")
		list(APPEND ${HDRS} "${CMAKE_CURRENT_BINARY_DIR}/${REL_DIR}/${FIL_WE}.grpc.pb.h")

		add_custom_command(
			OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${REL_DIR}/${FIL_WE}.pb.cc"
			"${CMAKE_CURRENT_BINARY_DIR}/${REL_DIR}/${FIL_WE}.pb.h"
			COMMAND  ${PROTOBUF_PROTOC_EXECUTABLE}
			ARGS --cpp_out=${CMAKE_CURRENT_BINARY_DIR}
			--proto_path=${CMAKE_SOURCE_DIR}
			${_protobuf_include_path} ${ABS_FIL}
			DEPENDS ${ABS_FIL} ${PROTOBUF_PROTOC_EXECUTABLE}
			COMMENT "Running C++ protocol buffer compiler on ${REL_DIR}/${FIL_WE}.proto"
			VERBATIM)

		add_custom_command(
			OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${REL_DIR}/${FIL_WE}.grpc.pb.cc"
			"${CMAKE_CURRENT_BINARY_DIR}/${REL_DIR}/${FIL_WE}.grpc.pb.h"
			COMMAND  ${PROTOBUF_PROTOC_EXECUTABLE}
			ARGS --grpc_out=${CMAKE_CURRENT_BINARY_DIR}
			--plugin=protoc-gen-grpc=${GRPC_CPP_PLUGIN}
			--proto_path=${CMAKE_SOURCE_DIR}
			${_protobuf_include_path} ${ABS_FIL}
			DEPENDS ${ABS_FIL} ${PROTOBUF_PROTOC_EXECUTABLE}
			COMMENT "Running gRPC C++ protocol buffer compiler on ${REL_DIR}/${FIL_WE}.proto"
			VERBATIM)
	endforeach()

	set_source_files_properties(${${SRCS}} ${${HDRS}} PROPERTIES GENERATED TRUE)
	set(${SRCS} ${${SRCS}} PARENT_SCOPE)
	set(${HDRS} ${${HDRS}} PARENT_SCOPE)
endfunction()

function(PROTOBUF_GENERATE_GRPC_PY SRCS TNAME)
	if(NOT ARGN)
		message(SEND_ERROR "Error: PROTOBUF_GENERATE_GRPC_PY() called without any proto files")
		return()
	endif()
	set(${SRCS})
	foreach(FIL ${ARGN})
		get_filename_component(ABS_FIL ${FIL} ABSOLUTE)
		get_filename_component(FIL_WE ${FIL} NAME_WE)
		get_filename_component(FIL_DIR ${ABS_FIL} DIRECTORY)
		get_filename_component(FIL_NAME ${ABS_FIL} NAME)

		file(RELATIVE_PATH REL_DIR ${CMAKE_SOURCE_DIR} ${FIL_DIR})
		string(REGEX REPLACE "/" "_" TNAME_SUFFIX "${REL_DIR}_${FIL_WE}")

		list(APPEND ${SRCS} "${CMAKE_CURRENT_BINARY_DIR}/${REL_DIR}/${FIL_WE}_pb2_grpc.py")
		list(APPEND ${SRCS} "${CMAKE_CURRENT_BINARY_DIR}/${REL_DIR}/${FIL_WE}_pb2.py")

		add_custom_target(${TNAME}_${TNAME_SUFFIX} ALL
			COMMAND python3 -m grpc_tools.protoc
			-I.
			--python_out=${CMAKE_CURRENT_BINARY_DIR}
			--grpc_python_out=${CMAKE_CURRENT_BINARY_DIR}
			${REL_DIR}/${FIL_NAME}
			WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
			DEPENDS ${ABS_FIL}
			COMMENT "Running gRPC python protocol buffer compiler on ${REL_DIR}/${FIL_WE}.proto"
			VERBATIM)
	endforeach()

	set_source_files_properties(${${SRCS}} PROPERTIES GENERATED TRUE)
	set(${SRCS} ${${SRCS}} PARENT_SCOPE)
endfunction()
