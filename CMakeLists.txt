cmake_minimum_required(VERSION 3.20)
project(DLLDeployer LANGUAGES C CXX)

if(NOT CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    message(STATUS "DLLDeployer is added as a subproject, no tests will be added")
    return()
endif ()

if(${WIN32})
    include(DLLDeployer.cmake)
endif ()
include(QtDeployer.cmake)

add_executable(test main.cpp)

find_package(libzip CONFIG REQUIRED)
target_link_libraries(test PRIVATE libzip::zip)

find_package(OpenMP REQUIRED)
target_link_libraries(test PRIVATE OpenMP::OpenMP_CXX)

find_package(Qt6 6.4.0
    COMPONENTS Core Widgets)
if(${Qt6_FOUND})
    target_link_libraries(test PRIVATE Qt6::Core Qt6::Widgets)
    set_target_properties(test PROPERTIES
        WIN32_EXECUTABLE ON
        MACOSX_BUNDLE_GUI_IDENTIFIER "com.github.ToKiNoBug.SlopeCraft"
        MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
        MACOSX_BUNDLE TRUE)
    target_compile_definitions(test PRIVATE QT_SUPPORT)
endif ()

install(TARGETS test
    RUNTIME DESTINATION bin
    BUNDLE DESTINATION bin)

if(${Qt6_FOUND})
    if(${APPLE})
#        QD_add_deployqt(test
#            INSTALL_MODE INSTALL_DESTINATION bin
#            FLAGS -no-translations)
    else ()
        QD_add_deployqt(test
            BUILD_MODE ALL
            INSTALL_MODE INSTALL_DESTINATION bin
            FLAGS -no-translations)
    endif ()

endif ()

if(${WIN32})
    DLLD_add_deploy(test
        BUILD_MODE ALL
        INSTALL_MODE
        INSTALL_DESTINATION bin)
endif ()

set(CPACK_PACKAGE_NAME "${PROJECT_NAME}_${CMAKE_CXX_COMPILER_ID}")
include(CPack)
