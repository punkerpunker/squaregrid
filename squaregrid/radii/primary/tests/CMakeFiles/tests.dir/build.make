# CMAKE generated file: DO NOT EDIT!
# Generated by "Unix Makefiles" Generator, CMake Version 3.5

# Delete rule output on recipe failure.
.DELETE_ON_ERROR:


#=============================================================================
# Special targets provided by cmake.

# Disable implicit rules so canonical targets will work.
.SUFFIXES:


# Remove some rules from gmake that .SUFFIXES does not remove.
SUFFIXES =

.SUFFIXES: .hpux_make_needs_suffix_list


# Suppress display of executed commands.
$(VERBOSE).SILENT:


# A target that is always out of date.
cmake_force:

.PHONY : cmake_force

#=============================================================================
# Set environment variables for the build.

# The shell in which to execute make rules.
SHELL = /bin/sh

# The CMake executable.
CMAKE_COMMAND = /usr/bin/cmake

# The command to remove a file.
RM = /usr/bin/cmake -E remove -f

# Escaping for special characters.
EQUALS = =

# The top-level source directory on which CMake was run.
CMAKE_SOURCE_DIR = /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry

# The top-level build directory on which CMake was run.
CMAKE_BINARY_DIR = /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary

# Include any dependencies generated for this target.
include tests/CMakeFiles/tests.dir/depend.make

# Include the progress variables for this target.
include tests/CMakeFiles/tests.dir/progress.make

# Include the compile flags for this target's objects.
include tests/CMakeFiles/tests.dir/flags.make

tests/CMakeFiles/tests.dir/grids/test_grid_metadata.cc.o: tests/CMakeFiles/tests.dir/flags.make
tests/CMakeFiles/tests.dir/grids/test_grid_metadata.cc.o: ../tests/grids/test_grid_metadata.cc
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/CMakeFiles --progress-num=$(CMAKE_PROGRESS_1) "Building CXX object tests/CMakeFiles/tests.dir/grids/test_grid_metadata.cc.o"
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/tests && /usr/bin/c++   $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -o CMakeFiles/tests.dir/grids/test_grid_metadata.cc.o -c /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/tests/grids/test_grid_metadata.cc

tests/CMakeFiles/tests.dir/grids/test_grid_metadata.cc.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing CXX source to CMakeFiles/tests.dir/grids/test_grid_metadata.cc.i"
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/tests && /usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -E /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/tests/grids/test_grid_metadata.cc > CMakeFiles/tests.dir/grids/test_grid_metadata.cc.i

tests/CMakeFiles/tests.dir/grids/test_grid_metadata.cc.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling CXX source to assembly CMakeFiles/tests.dir/grids/test_grid_metadata.cc.s"
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/tests && /usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -S /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/tests/grids/test_grid_metadata.cc -o CMakeFiles/tests.dir/grids/test_grid_metadata.cc.s

tests/CMakeFiles/tests.dir/grids/test_grid_metadata.cc.o.requires:

.PHONY : tests/CMakeFiles/tests.dir/grids/test_grid_metadata.cc.o.requires

tests/CMakeFiles/tests.dir/grids/test_grid_metadata.cc.o.provides: tests/CMakeFiles/tests.dir/grids/test_grid_metadata.cc.o.requires
	$(MAKE) -f tests/CMakeFiles/tests.dir/build.make tests/CMakeFiles/tests.dir/grids/test_grid_metadata.cc.o.provides.build
.PHONY : tests/CMakeFiles/tests.dir/grids/test_grid_metadata.cc.o.provides

tests/CMakeFiles/tests.dir/grids/test_grid_metadata.cc.o.provides.build: tests/CMakeFiles/tests.dir/grids/test_grid_metadata.cc.o


tests/CMakeFiles/tests.dir/processing/test_radii_summation.cc.o: tests/CMakeFiles/tests.dir/flags.make
tests/CMakeFiles/tests.dir/processing/test_radii_summation.cc.o: ../tests/processing/test_radii_summation.cc
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/CMakeFiles --progress-num=$(CMAKE_PROGRESS_2) "Building CXX object tests/CMakeFiles/tests.dir/processing/test_radii_summation.cc.o"
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/tests && /usr/bin/c++   $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -o CMakeFiles/tests.dir/processing/test_radii_summation.cc.o -c /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/tests/processing/test_radii_summation.cc

tests/CMakeFiles/tests.dir/processing/test_radii_summation.cc.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing CXX source to CMakeFiles/tests.dir/processing/test_radii_summation.cc.i"
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/tests && /usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -E /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/tests/processing/test_radii_summation.cc > CMakeFiles/tests.dir/processing/test_radii_summation.cc.i

tests/CMakeFiles/tests.dir/processing/test_radii_summation.cc.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling CXX source to assembly CMakeFiles/tests.dir/processing/test_radii_summation.cc.s"
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/tests && /usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -S /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/tests/processing/test_radii_summation.cc -o CMakeFiles/tests.dir/processing/test_radii_summation.cc.s

tests/CMakeFiles/tests.dir/processing/test_radii_summation.cc.o.requires:

.PHONY : tests/CMakeFiles/tests.dir/processing/test_radii_summation.cc.o.requires

tests/CMakeFiles/tests.dir/processing/test_radii_summation.cc.o.provides: tests/CMakeFiles/tests.dir/processing/test_radii_summation.cc.o.requires
	$(MAKE) -f tests/CMakeFiles/tests.dir/build.make tests/CMakeFiles/tests.dir/processing/test_radii_summation.cc.o.provides.build
.PHONY : tests/CMakeFiles/tests.dir/processing/test_radii_summation.cc.o.provides

tests/CMakeFiles/tests.dir/processing/test_radii_summation.cc.o.provides.build: tests/CMakeFiles/tests.dir/processing/test_radii_summation.cc.o


tests/CMakeFiles/tests.dir/processing/test_grid_forming.cc.o: tests/CMakeFiles/tests.dir/flags.make
tests/CMakeFiles/tests.dir/processing/test_grid_forming.cc.o: ../tests/processing/test_grid_forming.cc
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/CMakeFiles --progress-num=$(CMAKE_PROGRESS_3) "Building CXX object tests/CMakeFiles/tests.dir/processing/test_grid_forming.cc.o"
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/tests && /usr/bin/c++   $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -o CMakeFiles/tests.dir/processing/test_grid_forming.cc.o -c /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/tests/processing/test_grid_forming.cc

tests/CMakeFiles/tests.dir/processing/test_grid_forming.cc.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing CXX source to CMakeFiles/tests.dir/processing/test_grid_forming.cc.i"
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/tests && /usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -E /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/tests/processing/test_grid_forming.cc > CMakeFiles/tests.dir/processing/test_grid_forming.cc.i

tests/CMakeFiles/tests.dir/processing/test_grid_forming.cc.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling CXX source to assembly CMakeFiles/tests.dir/processing/test_grid_forming.cc.s"
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/tests && /usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -S /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/tests/processing/test_grid_forming.cc -o CMakeFiles/tests.dir/processing/test_grid_forming.cc.s

tests/CMakeFiles/tests.dir/processing/test_grid_forming.cc.o.requires:

.PHONY : tests/CMakeFiles/tests.dir/processing/test_grid_forming.cc.o.requires

tests/CMakeFiles/tests.dir/processing/test_grid_forming.cc.o.provides: tests/CMakeFiles/tests.dir/processing/test_grid_forming.cc.o.requires
	$(MAKE) -f tests/CMakeFiles/tests.dir/build.make tests/CMakeFiles/tests.dir/processing/test_grid_forming.cc.o.provides.build
.PHONY : tests/CMakeFiles/tests.dir/processing/test_grid_forming.cc.o.provides

tests/CMakeFiles/tests.dir/processing/test_grid_forming.cc.o.provides.build: tests/CMakeFiles/tests.dir/processing/test_grid_forming.cc.o


tests/CMakeFiles/tests.dir/tests_main.cc.o: tests/CMakeFiles/tests.dir/flags.make
tests/CMakeFiles/tests.dir/tests_main.cc.o: ../tests/tests_main.cc
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/CMakeFiles --progress-num=$(CMAKE_PROGRESS_4) "Building CXX object tests/CMakeFiles/tests.dir/tests_main.cc.o"
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/tests && /usr/bin/c++   $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -o CMakeFiles/tests.dir/tests_main.cc.o -c /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/tests/tests_main.cc

tests/CMakeFiles/tests.dir/tests_main.cc.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing CXX source to CMakeFiles/tests.dir/tests_main.cc.i"
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/tests && /usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -E /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/tests/tests_main.cc > CMakeFiles/tests.dir/tests_main.cc.i

tests/CMakeFiles/tests.dir/tests_main.cc.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling CXX source to assembly CMakeFiles/tests.dir/tests_main.cc.s"
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/tests && /usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -S /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/tests/tests_main.cc -o CMakeFiles/tests.dir/tests_main.cc.s

tests/CMakeFiles/tests.dir/tests_main.cc.o.requires:

.PHONY : tests/CMakeFiles/tests.dir/tests_main.cc.o.requires

tests/CMakeFiles/tests.dir/tests_main.cc.o.provides: tests/CMakeFiles/tests.dir/tests_main.cc.o.requires
	$(MAKE) -f tests/CMakeFiles/tests.dir/build.make tests/CMakeFiles/tests.dir/tests_main.cc.o.provides.build
.PHONY : tests/CMakeFiles/tests.dir/tests_main.cc.o.provides

tests/CMakeFiles/tests.dir/tests_main.cc.o.provides.build: tests/CMakeFiles/tests.dir/tests_main.cc.o


# Object files for target tests
tests_OBJECTS = \
"CMakeFiles/tests.dir/grids/test_grid_metadata.cc.o" \
"CMakeFiles/tests.dir/processing/test_radii_summation.cc.o" \
"CMakeFiles/tests.dir/processing/test_grid_forming.cc.o" \
"CMakeFiles/tests.dir/tests_main.cc.o"

# External object files for target tests
tests_EXTERNAL_OBJECTS =

tests/tests: tests/CMakeFiles/tests.dir/grids/test_grid_metadata.cc.o
tests/tests: tests/CMakeFiles/tests.dir/processing/test_radii_summation.cc.o
tests/tests: tests/CMakeFiles/tests.dir/processing/test_grid_forming.cc.o
tests/tests: tests/CMakeFiles/tests.dir/tests_main.cc.o
tests/tests: tests/CMakeFiles/tests.dir/build.make
tests/tests: external/googletest/googlemock/gtest/libgtest.a
tests/tests: grids/libgrid_metadata.a
tests/tests: libeasyloggingpp.a
tests/tests: /usr/lib/libboost_system.a
tests/tests: /usr/lib/libboost_filesystem.a
tests/tests: /usr/lib/libboost_thread.a
tests/tests: /usr/lib/x86_64-linux-gnu/libpthread.so
tests/tests: liblibpqxx.a
tests/tests: tests/CMakeFiles/tests.dir/link.txt
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --bold --progress-dir=/home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/CMakeFiles --progress-num=$(CMAKE_PROGRESS_5) "Linking CXX executable tests"
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/tests && $(CMAKE_COMMAND) -E cmake_link_script CMakeFiles/tests.dir/link.txt --verbose=$(VERBOSE)

# Rule to build all files generated by this target.
tests/CMakeFiles/tests.dir/build: tests/tests

.PHONY : tests/CMakeFiles/tests.dir/build

tests/CMakeFiles/tests.dir/requires: tests/CMakeFiles/tests.dir/grids/test_grid_metadata.cc.o.requires
tests/CMakeFiles/tests.dir/requires: tests/CMakeFiles/tests.dir/processing/test_radii_summation.cc.o.requires
tests/CMakeFiles/tests.dir/requires: tests/CMakeFiles/tests.dir/processing/test_grid_forming.cc.o.requires
tests/CMakeFiles/tests.dir/requires: tests/CMakeFiles/tests.dir/tests_main.cc.o.requires

.PHONY : tests/CMakeFiles/tests.dir/requires

tests/CMakeFiles/tests.dir/clean:
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/tests && $(CMAKE_COMMAND) -P CMakeFiles/tests.dir/cmake_clean.cmake
.PHONY : tests/CMakeFiles/tests.dir/clean

tests/CMakeFiles/tests.dir/depend:
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/tests /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/tests /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/tests/CMakeFiles/tests.dir/DependInfo.cmake --color=$(COLOR)
.PHONY : tests/CMakeFiles/tests.dir/depend

