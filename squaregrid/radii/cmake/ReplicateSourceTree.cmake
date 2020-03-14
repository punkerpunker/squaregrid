# Note: when executed in the build dir, then CMAKE_CURRENT_SOURCE_DIR is the
# build dir.
file( COPY grids primary processing utils DESTINATION "${CMAKE_ARGV3}"
  FILES_MATCHING PATTERN "*.py" )
file( COPY templates DESTINATION "${CMAKE_ARGV3}"
	FILES_MATCHING PATTERN "*.html" )
