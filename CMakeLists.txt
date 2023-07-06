cmake_minimum_required(VERSION 3.20)
project(DLLDeployer)

include(${CMAKE_CURRENT_SOURCE_DIR}/DLLDeployer.cmake)

include(${CMAKE_CURRENT_SOURCE_DIR}/test/test_DLLD_is_system_dll.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/test/test_DLLD_get_export_lib_targets.cmake)

add_executable(test main.cpp)

find_package(libzip)
if (${libzip_FOUND})
  target_link_libraries(test PRIVATE libzip::zip)
endif ()

install(TARGETS test
  RUNTIME DESTINATION bin)
