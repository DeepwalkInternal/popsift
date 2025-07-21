# First-order language CUDA requires at least CMake 3.18. This project uses 3.24.
cmake_minimum_required(VERSION 3.24)

project(PopSift VERSION 1.0.0 LANGUAGES CXX CUDA)

# Set build path to a folder named like "linux-x86_64"
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}")

# --- Project Options ---
option(PopSift_BUILD_EXAMPLES "Build PopSift applications." ON)
option(PopSift_BUILD_DOCS "Build PopSift documentation." OFF)
option(PopSift_USE_NVTX_PROFILING "Use CUDA NVTX for profiling." OFF)
option(PopSift_ERRCHK_AFTER_KERNEL "Synchronize and check CUDA error after every kernel." OFF)
option(PopSift_USE_POSITION_INDEPENDENT_CODE "Generate position independent code." ON)
option(PopSift_USE_GRID_FILTER "Switch off grid filtering for faster debugging compiles." ON)
option(PopSift_NVCC_WARNINGS "Switch on several additional warnings for CUDA nvcc." OFF)
option(PopSift_USE_TEST_CMD "Add testing step for functional verification." OFF)
option(BUILD_SHARED_LIBS "Build shared libraries." ON)

# --- Build Configuration ---
# Default to "Release" build if not specified
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")

# Set Position Independent Code based on option
if(PopSift_USE_POSITION_INDEPENDENT_CODE AND NOT MSVC)
  set(CMAKE_POSITION_INDEPENDENT_CODE ON)
endif()

# Handle shared/static library settings
if(BUILD_SHARED_LIBS)
  message(STATUS "Building shared libraries")
  set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
  set(CMAKE_CUDA_RUNTIME_LIBRARY Shared)
else()
  message(STATUS "Building static libraries")
  set(CMAKE_CUDA_RUNTIME_LIBRARY Static)
  # Ensure the proper linker flags when building static libs on MSVC
  if(MSVC)
    foreach(config "DEBUG" "RELEASE" "MINSIZEREL" "RELWITHDEBINFO")
      string(REPLACE "/MD" "/MT" CMAKE_C_FLAGS_${config} "${CMAKE_C_FLAGS_${config}}")
      string(REPLACE "/MD" "/MT" CMAKE_CXX_FLAGS_${config} "${CMAKE_CXX_FLAGS_${config}}")
    endforeach()
  endif()
endif()

# --- C++ and CUDA Standard Settings ---
set(PopSift_CXX_STANDARD 17)
# Use C++11 for older CUDA versions if necessary
if(CMAKE_CUDA_COMPILER_VERSION VERSION_LESS "9.0")
  set(PopSift_CXX_STANDARD 11)
endif()

set(CMAKE_CXX_STANDARD ${PopSift_CXX_STANDARD})
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_STANDARD ${PopSift_CXX_STANDARD})
set(CMAKE_CUDA_STANDARD_REQUIRED ON)

# --- CUDA Specific Configuration ---
message(STATUS "Found CUDA ${CMAKE_CUDA_COMPILER_VERSION} with compiler ${CMAKE_CUDA_COMPILER}")

# Enable CUDA separable compilation
set(CMAKE_CUDA_SEPARABLE_COMPILATION ON)

# FIXED: Default to `native` to auto-detect the GPU architecture. This is much more portable.
# Users can override this with -DCMAKE_CUDA_ARCHITECTURES="75;86" etc.
set(CMAKE_CUDA_ARCHITECTURES "native"
    CACHE STRING "Which CUDA CCs to support: native, all, all-major or an explicit list")
set_property(CACHE CMAKE_CUDA_ARCHITECTURES PROPERTY HELPSTRING "Examples: native, all, all-major, 75, 80, 86, 89, 90")

# Enable separable compilation for the project
set(CMAKE_CUDA_SEPARABLE_COMPILATION ON)

# FIXED: Use the modern `per-thread` default stream. The old `legacy` is removed in CUDA 12+.
# NOTE: This may require code changes in your kernels to ensure correct synchronization.
add_compile_options($<$<COMPILE_LANGUAGE:CUDA>:-Xcompiler=-fPIC>)
add_compile_options($<$<COMPILE_LANGUAGE:CUDA>:--default-stream=per-thread>)

# Add warnings for memory usage if enabled
if(PopSift_NVCC_WARNINGS AND CMAKE_CUDA_COMPILER_VERSION VERSION_GREATER_EQUAL "7.5")
  # Use a generator expression to apply these flags only to Release builds
  add_compile_options($<$<AND:$<COMPILE_LANGUAGE:CUDA>,$<CONFIG:Release>>:
    -Xptxas;-warn-lmem-usage
    -Xptxas;-warn-spills
  >)
endif()

# --- Compile Definitions ---
if(PopSift_ERRCHK_AFTER_KERNEL)
  message(STATUS "Synchronizing and checking errors after every kernel call")
  add_compile_definitions(ERRCHK_AFTER_KERNEL)
endif()

# Add definitions based on options and CUDA version
add_compile_definitions(
    PopSift_HAVE_SHFL_DOWN_SYNC=$<IF:$<VERSION_GREATER_EQUAL:${CMAKE_CUDA_COMPILER_VERSION},9.0>,1,0>
    DISABLE_GRID_FILTER=$<IF:$<BOOL:${PopSift_USE_GRID_FILTER}>,0,1>
    PopSift_USE_NVTX=$<IF:$<BOOL:${PopSift_USE_NVTX_PROFILING}>,1,0>
)

# --- Dependencies and Subdirectories ---
# Add local cmake modules to path
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${PROJECT_SOURCE_DIR}/cmake")

# Find standard threads package
find_package(Threads REQUIRED)

# Include GNU standard installation directories for CMAKE_INSTALL_PREFIX
include(GNUInstallDirs)

# Add source and other subdirectories
add_subdirectory(src)

if(PopSift_BUILD_DOCS)
  add_subdirectory(doc)
endif()

if(PopSift_USE_TEST_CMD)
  set(PopSift_TESTFILE_PATH "popsift-samples/datasets/sample/big_set/" CACHE STRING "Base directory where test files are stored")
  add_subdirectory(testScripts)
endif()

# --- Installation and Uninstall ---
# Add a custom uninstall target
configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/cmake/cmake_uninstall.cmake.in"
  "${CMAKE_CURRENT_BINARY_DIR}/cmake/cmake_uninstall.cmake"
  IMMEDIATE @ONLY)
add_custom_target(uninstall
  COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_BINARY_DIR}/cmake/cmake_uninstall.cmake")


# --- Summary ---
message(STATUS "\n")
message(STATUS "******************************************")
message(STATUS "PopSift Project Configuration Summary:")
message(STATUS "  Version: ${PROJECT_VERSION}")
message(STATUS "  Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  Build Shared libs: ${BUILD_SHARED_LIBS}")
message(STATUS "  Build examples: ${PopSift_BUILD_EXAMPLES}")
message(STATUS "  Install path: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "  CUDA Architectures: ${CMAKE_CUDA_ARCHITECTURES}")
message(STATUS "******************************************\n")