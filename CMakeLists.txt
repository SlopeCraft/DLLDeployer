cmake_minimum_required(VERSION 3.20)
project(DLLDeployer)


include(DLLDeployer_install_time.cmake)

DLLD_get_exe_dependents("F:/ziptool.exe" ziptool_deps RECURSE)
message("ziptool_deps = ${ziptool_deps}")

DLLD_deploy_runtime("F:/ziptool.exe"
    DESTINATION "F:/" INSTALL)

add_executable(test main.cpp)

find_package(libzip)
if (${libzip_FOUND})
    target_link_libraries(test PRIVATE libzip::zip)
endif ()

find_package(OpenMP)
target_link_libraries(test PRIVATE OpenMP::OpenMP_CXX)

install(TARGETS test
    RUNTIME DESTINATION bin)

return()
#include(${CMAKE_CURRENT_SOURCE_DIR}/DLLDeployer.cmake)
#
##include(${CMAKE_CURRENT_SOURCE_DIR}/test/test_DLLD_is_system_dll.cmake)
##include(${CMAKE_CURRENT_SOURCE_DIR}/test/test_DLLD_get_export_lib_targets.cmake)
#
#add_executable(test main.cpp)
#
#find_package(libzip)
#if (${libzip_FOUND})
#  target_link_libraries(test PRIVATE libzip::zip)
#endif ()
#
#find_package(OpenMP)
#target_link_libraries(test PRIVATE OpenMP::OpenMP_CXX)
#
#install(TARGETS test
#  RUNTIME DESTINATION bin)
#
#test_recurse(${CMAKE_CURRENT_SOURCE_DIR} project_files)
#message("project_files = ${project_files}")
#
##DLLD_deploy_for_exe(test bin)
##DLLD_deploy_deps_for_target(libzip::zip bin)
##message("out from libzip::zip = ${out}")
##DLLD_glob_target_deps(OpenMP::OpenMP_CXX out)
##message("out = ${out}")
#
#DLLD_get_target_deps(test test_deps)
#message("test_deps = ${test_deps}")
#
#glob_deps_recurse(test test_deps_recurse)
#message("test_deps_recurse = ${test_deps_recurse}")
#
#
#DLLD_get_target_deps(libzip::zip test_deps)
#message("libzip::zip_deps = ${test_deps}")