cmake_minimum_required(VERSION 3.20)
project(DLLDeployer)

if(NOT CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    message(STATUS "DLLDeployer is added as a subproject, no tests will be added")
    return()
endif ()

include(DLLDeployer.cmake)
include(QtDeployer.cmake)

#configure_file(DLLDeployer_install_time.cmake
#    ${CMAKE_CURRENT_BINARY_DIR}/DLLDeployer_configured.cmake
#    @ONLY)

#DLLD_get_exe_dependents("F:/ziptool.exe" ziptool_deps RECURSE)
#message("ziptool_deps = ${ziptool_deps}")
#
#DLLD_deploy_runtime("F:/ziptool.exe"
#    DESTINATION "F:/" INSTALL)


add_executable(test main.cpp)

find_package(libzip REQUIRED)
if (${libzip_FOUND})
    target_link_libraries(test PRIVATE libzip::zip)
endif ()

find_package(OpenMP REQUIRED)
target_link_libraries(test PRIVATE OpenMP::OpenMP_CXX)

find_package(Qt6 6.4.0
    COMPONENTS Core Widgets
    REQUIRED)
target_link_libraries(test PRIVATE Qt6::Core Qt6::Widgets)
set_target_properties(test PROPERTIES
    WIN32_EXECUTABLE ON)

install(TARGETS test
    RUNTIME DESTINATION bin)

QD_add_deployqt(test
    BUILD_MODE ALL
    INSTALL_MODE INSTALL_DESTINATION bin
    FLAGS -no-translations)

#DLLD_add_deploy(test )
DLLD_add_deploy(test
    BUILD_MODE ALL
    INSTALL_MODE
    INSTALL_DESTINATION bin
    IGNORE libbz2.dll)


include(CPack)
