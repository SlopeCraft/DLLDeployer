message(STATUS "Tesing DLLD_is_system_dll")


function(DLLD_private_add_test_is_system_dll filename)
  DLLD_is_system_dll(${filename} result)
  if(${result})
    message("${filename} is a system dll")
  else ()
    message("${filename} is not a system dll")
  endif ()
endfunction()

DLLD_private_add_test_is_system_dll(C:/Windows/System32/MSVCRT.dll)
DLLD_private_add_test_is_system_dll(zip.dll)
DLLD_private_add_test_is_system_dll(api-ms-win-crt-time-l1-1-0.dll)
DLLD_private_add_test_is_system_dll(vcruntime140.dll)
DLLD_private_add_test_is_system_dll(vcruntime140-1.dll)
DLLD_private_add_test_is_system_dll(OpenCL.dll)
