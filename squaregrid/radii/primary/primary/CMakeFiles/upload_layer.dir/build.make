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
include primary/CMakeFiles/upload_layer.dir/depend.make

# Include the progress variables for this target.
include primary/CMakeFiles/upload_layer.dir/progress.make

# Include the compile flags for this target's objects.
include primary/CMakeFiles/upload_layer.dir/flags.make

primary/upload_layer_static.cxx: upload_layer.pyx
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --blue --bold --progress-dir=/home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/CMakeFiles --progress-num=$(CMAKE_PROGRESS_1) "Compiling Cython CXX source for upload_layer_static..."
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/primary && /usr/local/bin/cython --cplus -I /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry -I /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary -I /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/external/libpqxx/include -I /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/external/libpqxx/config/sample-headers/compiler/gcc-4.4 -I /usr/include/postgresql -I /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/external/easyloggingpp/src -I /usr/include -I /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/external/gflags/include -I /usr/include/python3.5m -3 --embed --output-file /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/primary/upload_layer_static.cxx /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/upload_layer.pyx

primary/CMakeFiles/upload_layer.dir/upload_layer_static.cxx.o: primary/CMakeFiles/upload_layer.dir/flags.make
primary/CMakeFiles/upload_layer.dir/upload_layer_static.cxx.o: primary/upload_layer_static.cxx
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/CMakeFiles --progress-num=$(CMAKE_PROGRESS_2) "Building CXX object primary/CMakeFiles/upload_layer.dir/upload_layer_static.cxx.o"
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/primary && /usr/bin/c++   $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -o CMakeFiles/upload_layer.dir/upload_layer_static.cxx.o -c /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/primary/upload_layer_static.cxx

primary/CMakeFiles/upload_layer.dir/upload_layer_static.cxx.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing CXX source to CMakeFiles/upload_layer.dir/upload_layer_static.cxx.i"
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/primary && /usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -E /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/primary/upload_layer_static.cxx > CMakeFiles/upload_layer.dir/upload_layer_static.cxx.i

primary/CMakeFiles/upload_layer.dir/upload_layer_static.cxx.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling CXX source to assembly CMakeFiles/upload_layer.dir/upload_layer_static.cxx.s"
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/primary && /usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -S /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/primary/upload_layer_static.cxx -o CMakeFiles/upload_layer.dir/upload_layer_static.cxx.s

primary/CMakeFiles/upload_layer.dir/upload_layer_static.cxx.o.requires:

.PHONY : primary/CMakeFiles/upload_layer.dir/upload_layer_static.cxx.o.requires

primary/CMakeFiles/upload_layer.dir/upload_layer_static.cxx.o.provides: primary/CMakeFiles/upload_layer.dir/upload_layer_static.cxx.o.requires
	$(MAKE) -f primary/CMakeFiles/upload_layer.dir/build.make primary/CMakeFiles/upload_layer.dir/upload_layer_static.cxx.o.provides.build
.PHONY : primary/CMakeFiles/upload_layer.dir/upload_layer_static.cxx.o.provides

primary/CMakeFiles/upload_layer.dir/upload_layer_static.cxx.o.provides.build: primary/CMakeFiles/upload_layer.dir/upload_layer_static.cxx.o


# Object files for target upload_layer
upload_layer_OBJECTS = \
"CMakeFiles/upload_layer.dir/upload_layer_static.cxx.o"

# External object files for target upload_layer
upload_layer_EXTERNAL_OBJECTS =

primary/upload_layer: primary/CMakeFiles/upload_layer.dir/upload_layer_static.cxx.o
primary/upload_layer: primary/CMakeFiles/upload_layer.dir/build.make
primary/upload_layer: /usr/lib/x86_64-linux-gnu/libpython3.5m.so
primary/upload_layer: grids/libgrid_metadata.a
primary/upload_layer: utils/liblogging.a
primary/upload_layer: liblibpqxx.a
primary/upload_layer: libeasyloggingpp.a
primary/upload_layer: primary/CMakeFiles/upload_layer.dir/link.txt
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --bold --progress-dir=/home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/CMakeFiles --progress-num=$(CMAKE_PROGRESS_3) "Linking CXX executable upload_layer"
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/primary && $(CMAKE_COMMAND) -E cmake_link_script CMakeFiles/upload_layer.dir/link.txt --verbose=$(VERBOSE)

# Rule to build all files generated by this target.
primary/CMakeFiles/upload_layer.dir/build: primary/upload_layer

.PHONY : primary/CMakeFiles/upload_layer.dir/build

primary/CMakeFiles/upload_layer.dir/requires: primary/CMakeFiles/upload_layer.dir/upload_layer_static.cxx.o.requires

.PHONY : primary/CMakeFiles/upload_layer.dir/requires

primary/CMakeFiles/upload_layer.dir/clean:
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/primary && $(CMAKE_COMMAND) -P CMakeFiles/upload_layer.dir/cmake_clean.cmake
.PHONY : primary/CMakeFiles/upload_layer.dir/clean

primary/CMakeFiles/upload_layer.dir/depend: primary/upload_layer_static.cxx
	cd /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/primary /home/marketinglogic/marketing_logic/02_Personal_scripts/06_Dmitry/primary/primary/CMakeFiles/upload_layer.dir/DependInfo.cmake --color=$(COLOR)
.PHONY : primary/CMakeFiles/upload_layer.dir/depend

