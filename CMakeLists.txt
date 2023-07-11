cmake_minimum_required(VERSION 3.20)
project(DLLDeployer)

include(DLLDeployer.cmake)

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

install(TARGETS test
    RUNTIME DESTINATION bin)
DLLD_deploy_for_target(test BUILD_MODE ALL)
DLLD_deploy_for_target(test INSTALL_MODE INSTALL_DESTINATION bin)

include(CPack)
