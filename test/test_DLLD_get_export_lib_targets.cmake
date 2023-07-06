message(STATUS "Testing DLLD_get_export_lib_targets")

function(DLLD_private_add_test lib_name)
  DLLD_library_type(${lib_name} type)
  message("Type of ${lib_name} is : ${type}")
  DLLD_deploy_lib(${lib_name} bin INSTALL_SYSTEM_DLL)
endfunction()


find_package(ZLIB QUIET)
if(${ZLIB_FOUND})
  DLLD_private_add_test(ZLIB::ZLIB)
endif ()


find_package(zstd QUIET)
if(${zstd_FOUND})
  if(TARGET zstd::libzstd_shared)
    DLLD_private_add_test(zstd::libzstd_shared)
  endif ()
  if(TARGET zstd::libzstd_static)
    DLLD_private_add_test(zstd::libzstd_static)
  endif ()
endif ()


find_package(Boost QUIET)
if(${Boost_FOUND})
  if(TARGET Boost::filesystem)
    DLLD_private_add_test(Boost::filesystem)
  endif ()
endif ()

find_package(Eigen3 QUIET)
if(${Eigen3_FOUND})
  DLLD_private_add_test(Eigen3::Eigen)
endif ()

find_package(BZip2 QUIET)
if(${BZip2_FOUND})
  DLLD_private_add_test(BZip2::BZip2)
endif ()

find_package(libzip)
if(${libzip_FOUND})
  DLLD_private_add_test(libzip::zip)
endif ()

find_package(OpenMP REQUIRED)
get_target_property(omp_type OpenMP::OpenMP_CXX TYPE)
message("omp_type = ${omp_type}")
get_target_property(omp_loc OpenMP::OpenMP_CXX LOCATION)
message("omp_loc = ${omp_loc}")
get_target_property(omp_link_deps OpenMP::OpenMP_CXX INTERFACE_LINK_LIBRARIES)
message("omp_link_deps = ${omp_link_deps}")