cmake_minimum_required(VERSION 3.20)

if (NOT ${WIN32})
  message(STATUS "This project is designed to deploy dll on windows.")
  return()
endif ()

message("CMAKE_CXX_COMPILER_ID = ${CMAKE_CXX_COMPILER_ID}")


# Tells if the given file is a dll
function(DLLD_is_dll library_file out_var_name)
  cmake_path(GET library_file EXTENSION extension)
  if (extension STREQUAL .dll)
    set(${out_var_name} ON PARENT_SCOPE)
    return()
  endif ()

  set(${out_var_name} OFF PARENT_SCOPE)
endfunction()

# Tells if the given file is a system library
function(DLLD_is_system_dll lib_file out_var_name)
  DLLD_is_dll(${lib_file} is_dll)
  if (NOT ${is_dll})
    message(WARNING "The given file \"${lib_file}\" is not an dynamic library.")
    set(${out_var_name} OFF PARENT_SCOPE)
    return()
  endif ()


  set(${out_var_name} OFF PARENT_SCOPE)
  cmake_path(GET lib_file FILENAME lib_file)

  set(DLLD_system_prefixes C:/Windows/system32/;C:/Windows/;C:/Windows/System32/Wbem/;C:/Windows/System32/WindowsPowerShell/v1.0/;C:/Windows/System32/OpenSSH/)

  foreach (system_prefix ${DLLD_system_prefixes})
    string(CONCAT temp ${system_prefix} ${lib_file})
    if (EXISTS ${temp})
      set(${out_var_name} ON PARENT_SCOPE)
      return()
    endif ()
  endforeach ()

  if (${lib_file} MATCHES "api-ms-win-*")
    set(${out_var_name} ON PARENT_SCOPE)
    return()
  endif ()
endfunction(DLLD_is_system_dll)

# Get the location. If the target is a target, return its location; otherwise return the value of target
function(DLLD_get_location target result_var_name)
  unset(${result_var_name} PARENT_SCOPE)
  if (TARGET ${target})
    get_target_property(loc ${target} LOCATION)
    if (loc)
      set(${result_var_name} ${loc} PARENT_SCOPE)
    endif ()
  else ()
    set(${result_var_name} ${target} PARENT_SCOPE)
  endif ()
endfunction()
if (NOT DEFINED DLLD_msvc_utils)
  if (${MSVC})
    # if the compiler is msvc-like use msvc utils
    set(DLLD_msvc_utils_default_val ON)
  else ()
    if (${CMAKE_CXX_COMPILER_ID} STREQUAL "GNU")
      # gcc
      set(DLLD_msvc_utils_default_val OFF)
    endif ()

    if (${CMAKE_CXX_COMPILER_ID} STREQUAL "Clang")
      cmake_path(GET CMAKE_CXX_COMPILER PARENT_PATH compiler_prefix)
      cmake_path(GET compiler_prefix PARENT_PATH compiler_prefix)

      if (EXISTS ${compiler_prefix}/bin/c++.exe)
        # Clang with mingw abi
        set(DLLD_msvc_utils_default_val OFF)
      else ()
        # clang-msvc with gnu-like command line
        set(DLLD_msvc_utils_default_val ON)
      endif ()
    endif ()


    if (${CMAKE_CXX_COMPILER_ID} STREQUAL "MSVC")
      set(DLLD_msvc_utils_default_val ON)
    endif ()
  endif ()

endif ()
option(DLLD_msvc_utils "Use msvc utils" ${DLLD_msvc_utils_default_val})

if (${DLLD_msvc_utils})
  find_program(DLLD_msvc_lib_exe NAMES lib)
  find_program(DLLD_msvc_dumpbin_exe NAMES dumpbin)

  # List all direct link targets of an export lib
  function(DLLD_get_export_lib_targets export_lib_file link_targets_out_var_name)
    unset(${link_targets_out_var_name} PARENT_SCOPE)
    if (NOT DLLD_msvc_lib_exe)
      message(FATAL_ERROR "lib.exe is not found on this computer, but you are using a msvc-like compiler, please install msvc and make sure the environment variables are initialized for msvc.")
    endif ()

    execute_process(COMMAND ${DLLD_msvc_lib_exe} /list ${export_lib_file}
      OUTPUT_VARIABLE lib_output
      #OUTPUT_QUIET
      COMMAND_ERROR_IS_FATAL ANY)

    string(REPLACE "\n" ";" lib_output ${lib_output})
    #message("lib_output = ${lib_output}")

    set(result)

    foreach (output ${lib_output})
      if (${output} MATCHES "Microsoft (R)*")
        continue()
      endif ()
      if (${output} MATCHES "Copyright (C)*")
        continue()
      endif ()

      cmake_path(GET output EXTENSION ext)
      if (NOT ext STREQUAL .dll)
        #message("${output} is not a dll file, skipped")
        continue()
      endif ()

      list(FIND result ${output} index)
      #message("index = ${index}")
      if (${index} GREATER_EQUAL 0)
        continue()
      endif ()

      list(APPEND result ${output})
      #message("Added ${output} to result")
    endforeach ()
    set(${link_targets_out_var_name} ${result} PARENT_SCOPE)
  endfunction(DLLD_get_export_lib_targets)

  # Get dll dependents of a dll
  function(DLLD_get_dll_dependents dll_file result_var_name)
    DLLD_is_dll(${dll_file} is_dll)
    if (NOT ${is_dll})
      message(WARNING "${dll_file} is not a dll file, but it was passed to function DLLD_get_dll_dependents. Nothing will be done to it.")
      return()
    endif ()

    if (NOT DLLD_msvc_dumpbin_exe)
      message(FATAL_ERROR "dumpbin.exe is not found on this computer, but you are using a msvc-like compiler, please install msvc and make sure the environment variables are initialized for msvc.")
    endif ()

    execute_process(COMMAND ${DLLD_msvc_dumpbin_exe} /dependents ${dll_file}
      OUTPUT_VARIABLE lib_output
      #OUTPUT_QUIET
      COMMAND_ERROR_IS_FATAL ANY)


    string(REPLACE "\n" ";" lib_output ${lib_output})
    set(result)
    foreach (output ${lib_output})
      string(STRIP ${output} output)
      if (output MATCHES "Dump of file")
        continue()
      endif ()

      if (NOT output MATCHES .dll)
        #message("\"${output}\" doesn't refer to a filename, skip it.")
        continue()
      endif ()
      list(APPEND result ${output})
    endforeach ()

    #message("result = ${result}")
    set(${result_var_name} ${result} PARENT_SCOPE)
  endfunction(DLLD_get_dll_dependents)
else ()
  cmake_path(GET CMAKE_CXX_COMPILER PARENT_PATH compiler_bin_dir)
  find_program(DLLD_gnu_objdump_exe
    NAMES objdump
    HINTS ${compiler_bin_dir})
  # Add binutils-based functions here

  function(DLLD_get_export_lib_targets export_lib_file link_targets_out_var_name)
    unset(${link_targets_out_var_name} PARENT_SCOPE)
    if (NOT ${export_lib_file} MATCHES ".dll.a")
      message(WARNING "${export_lib_file} is not a export lib.")
      return()
    endif ()
    cmake_path(GET export_lib_file FILENAME export_lib_file)
    string(LENGTH ${export_lib_file} len)
    math(EXPR len "${len}-2")
    string(SUBSTRING ${export_lib_file} 0 ${len} result)

    set(${link_targets_out_var_name} ${result} PARENT_SCOPE)
  endfunction()

  # Get dll dependents of a dll
  function(DLLD_get_dll_dependents dll_file result_var_name)
    unset(${result_var_name} PARENT_SCOPE)
    if (NOT DLLD_gnu_objdump_exe)
      message(FATAL_ERROR "You are using a non-msvc compiler, but objdump is not found")
    endif ()

    execute_process(COMMAND ${DLLD_gnu_objdump_exe} ${dll_file} -x --section=.idata
      COMMAND findstr "DLL Name:"
      OUTPUT_VARIABLE outputs
      COMMAND_ERROR_IS_FATAL ANY)

    string(REPLACE "\n" ";" outputs ${outputs})

    set(result)
    foreach (output ${outputs})
      string(STRIP ${output} output)
      if (NOT ${output} MATCHES "DLL Name:")
        #message("\"${output}\" doesn't contains dll information.")
        continue()
      endif ()

      string(REPLACE "DLL Name: " "" output ${output})
      list(APPEND result ${output})
      #message("output = ${output}")
    endforeach ()
    set(${result_var_name} ${result} PARENT_SCOPE)

  endfunction(DLLD_get_dll_dependents)

endif ()

# Tells the type of library file. The result may be: unknown, dynamic_lib, static_lib, export_lib
function(DLLD_library_type lib_file type_out_var_name)
  set(${type_out_var_name} "unknown" PARENT_SCOPE)
  if (TARGET ${lib_file})
    get_target_property(target_type ${lib_file} TYPE)

    #message("The type of target ${lib_file} is ${target_type}")

    set(exclude_target_types
      INTERFACE_LIBRARY
      OBJECT_LIBRARY
      EXECUTABLE
      )

    if (${target_type} IN_LIST exclude_target_types)
      #message(STATUS "The type of ${lib_file} is ${target_type}, so the result is set to unknown.")
      return()
    endif ()

    get_target_property(actual_file_location ${lib_file} LOCATION)
    #message("actual_file_location = ${actual_file_location}")
    DLLD_library_type(${actual_file_location} temp_var)
    set(${type_out_var_name} ${temp_var} PARENT_SCOPE)
    return()
  endif ()

  DLLD_is_dll(${lib_file} is_dll)
  if (${is_dll})
    set(${type_out_var_name} "dynamic_lib" PARENT_SCOPE)
    return()
  endif ()
  # Deduce the type of library from the filename

  if (${lib_file} MATCHES ".dll.a")
    set(${type_out_var_name} "export_lib" PARENT_SCOPE)
    return()
  endif ()


  cmake_path(GET lib_file EXTENSION extension)
  string(TOLOWER ${extension} extension)
  if (extension STREQUAL .a)
    set(${type_out_var_name} "static_lib" PARENT_SCOPE)
    return()
  endif ()

  if (extension STREQUAL .lib)
    DLLD_get_export_lib_targets(${lib_file} targets)
    list(LENGTH targets target_num)
    if (${target_num} GREATER 0)
      set(${type_out_var_name} "export_lib" PARENT_SCOPE)
    else ()
      set(${type_out_var_name} "static_lib" PARENT_SCOPE)
    endif ()
    return()
  endif ()

  message(WARNING "Failed to deduce the library type of ${lib_file}")
endfunction(DLLD_library_type)


function(DLLD_deploy_dll dll_location destination)
  #message("ARGV of DLLD_deploy_dll = ${ARGV}")
  cmake_parse_arguments(DLLD_deploy_dll
    "NO_RECURSE;INSTALL_SYSTEM_DLL" "" "" ${ARGN})
  #message("DLLD_deploy_dll_NO_RECURSE = ${DLLD_deploy_dll_NO_RECURSE}")
  #message("DLLD_deploy_dll_INSTALL_SYSTEM_DLL = ${DLLD_deploy_dll_INSTALL_SYSTEM_DLL}")

  DLLD_is_system_dll(${dll_location} is_system_dll)

  install(FILES ${dll_location} DESTINATION ${destination})
  message("Install ${dll_location} to ${destination}")

  # do not install recursively for system dlls
  if (${DLLD_deploy_dll_NO_RECURSE} OR ${is_system_dll})
    return()
  endif ()

  DLLD_get_dll_dependents(${dll_location} deps)

  cmake_path(GET dll_location PARENT_PATH dll_install_prefix)
  cmake_path(GET dll_install_prefix PARENT_PATH dll_install_prefix)
  #message("dll_install_prefix = ${dll_install_prefix}")

  list(LENGTH deps dep_num)
  if (${dep_num} LESS_EQUAL 0)
    return()
  endif ()

  #message("The dependents of ${dll_location} are: ${deps}")
  foreach (dep ${deps})
    DLLD_is_system_dll(${dep} is_system_dll)
    if (${is_system_dll})
      if (NOT ${DLLD_deploy_dll_INSTALL_SYSTEM_DLL})
        continue()
      endif ()
      #message("${dep} is skipped because it is a system dll")
    endif ()
    #message("Deploying ${dep} for ${dll_location}")

    unset(dep_location)
    if (EXISTS "${dll_install_prefix}/bin/${dep}")
      set(dep_location "${dll_install_prefix}/bin/${dep}")
    else ()
      find_file(dep_location
        NAMES ${dep}
        PATH_SUFFIXES bin
        REQUIRED
        NO_CACHE)
    endif ()


    DLLD_deploy_dll(${dep_location} ${destination} ${ARGN})

  endforeach ()
  #message("")
endfunction(DLLD_deploy_dll)


# Install required dlls for target
function(DLLD_deploy_lib target destination)

  cmake_parse_arguments(DLLD_deploy_lib
    "NO_RECURSE;INSTALL_SYSTEM_DLL" "" "" ${ARGN})
  #message("DLLD_deploy_lib_NO_RECURSE = ${DLLD_deploy_lib_NO_RECURSE}")
  #message("DLLD_deploy_lib_INSTALL_SYSTEM_DLL = ${DLLD_deploy_lib_INSTALL_SYSTEM_DLL}")

  set(extra_flags)
  if (${DLLD_deploy_lib_NO_RECURSE})
    list(APPEND extra_flags NO_RECURSE)
  endif ()
  if (${DLLD_deploy_lib_INSTALL_SYSTEM_DLL})
    list(APPEND extra_flags INSTALL_SYSTEM_DLL)
  endif ()
  #message("extra_flags = ${extra_flags}")

  DLLD_library_type(${target} type)
  if ((${type} STREQUAL "static_lib") OR (${type} STREQUAL "unknown"))
    return()
  endif ()

  DLLD_get_location(${target} location)
  if (${type} STREQUAL "dynamic_lib")
    DLLD_deploy_dll(${location} ${destination} ${extra_flags})
    return()
  endif ()

  if (${type} STREQUAL "export_lib")


    DLLD_get_export_lib_targets(${location} dll_files)

    #message("${location} is a export lib, following files are required: ${dll_files}")

    foreach (dll_file ${dll_files})
      DLLD_is_system_dll(${dll_file} is_system_dll)
      if (${is_system_dll})
        message("${dll_file} is a system dll, skip.")
        continue()
      endif ()


      cmake_path(GET location PARENT_PATH export_lib_install_prefix)
      cmake_path(GET export_lib_install_prefix PARENT_PATH export_lib_install_prefix)
      #message("export_lib_install_prefix = ${export_lib_install_prefix}")

      unset(dll_location)
      if (EXISTS "${export_lib_install_prefix}/bin/${dll_file}")
        set(dll_location "${export_lib_install_prefix}/bin/${dll_file}")
      else ()
        find_file(dll_location ${dll_file}
          PATH_SUFFIXES bin
          REQUIRED
          NO_CACHE)
      endif ()

      DLLD_deploy_dll(${dll_location} ${destination} ${extra_flags})

    endforeach ()
    return()
  endif ()

  message(FATAL_ERROR "Unhandled condition")
endfunction(DLLD_deploy_lib)


#function(DLLD_deploy_deps_for_target target destination)
#
#  set(target_dep_list)
#  set(target_grab_property_list
#    IMPORTED_LINK_DEPENDENT_LIBRARIES
#    IMPORTED_LINK_DEPENDENT_LIBRARIES
#    LINK_DEPENDS
#    MANUALLY_ADDED_DEPENDENCIES
#    IMPORTED_LIBNAME
#    INTERFACE_LINK_LIBRARIES
#    LINK_INTERFACE_LIBRARIES
#    LINK_LIBRARIES)
#  foreach (prop_name ${target_grab_property_list})
#    unset(temp)
#    get_target_property(temp ${target} ${prop_name})
#    if (NOT temp)
#      continue()
#    endif ()
#    message("${prop_name} of ${target} = ${temp}")
#    list(APPEND target_dep_list ${temp})
#  endforeach ()
#
#  message(STATUS "Going through the dependents of ${target}...")
#  foreach (dep ${target_dep_list})
#    # if dep is a generator expression, extract it
#    string(FIND ${dep} "$<LINK_ONLY:" find_result)
#    if (${find_result} GREATER_EQUAL 0)
#      #message("Detected generator expression: ${dep}")
#      string(LENGTH ${dep} dep_strlen)
#      math(EXPR dep_strlen "${dep_strlen}-13")
#      string(SUBSTRING ${dep} 12 ${dep_strlen} dep)
#      #message("The extracted dep is: ${dep}")
#    endif ()
#
#    if (EXISTS ${dep})
#      DLLD_deploy_lib(${dep} ${destination})
#      continue()
#    endif ()
#
#    if (TARGET ${dep})
#      DLLD_deploy_lib(${dep} ${destination})
#      DLLD_deploy_deps_for_target(${dep} ${destination})
#      continue()
#    endif ()
#
#    find_library(dep_lib_location ${dep} QUIET)
#    if (dep_lib_location)
#      DLLD_deploy_lib(${dep_lib_location} ${destination})
#      continue()
#    endif ()
#
#    message(WARNING "No rule to handel dep named ${dep}")
#  endforeach ()
#
#endfunction(DLLD_deploy_deps_for_target)

#function(DLLD_glob_target_deps target out_var)
#  unset(out_var PARENT_SCOPE)
#  message(WARNING "This function will not work properly because fucking cmake doesn't support function recursing")
#
#  if(NOT TARGET ${target})
#    message(FATAL_ERROR "${target} is not a target.")
#  endif ()
#
#  set(prefix "${CMAKE_CURRENT_BINARY_DIR}/DLLD_glob_target_deps_")
#  set(suffix "_deps.txt")
#  file(WRITE "${prefix}${target}${suffix}" "")
#
#  cmake_parse_arguments(DLLD_glob_target_deps
#    "NO_RECURSE;NO_SYSTEM_DLL" "" "" ${ARGN})
#
#  set(target_dep_list)
#  set(target_grab_property_list
#    IMPORTED_LINK_DEPENDENT_LIBRARIES
#    IMPORTED_LINK_DEPENDENT_LIBRARIES
#    LINK_DEPENDS
#    MANUALLY_ADDED_DEPENDENCIES
#    IMPORTED_LIBNAME
#    INTERFACE_LINK_LIBRARIES
#    LINK_INTERFACE_LIBRARIES
#    LINK_LIBRARIES)
#  foreach (prop_name ${target_grab_property_list})
#    unset(temp)
#    get_target_property(temp ${target} ${prop_name})
#    if (NOT temp)
#      continue()
#    endif ()
#    message("${prop_name} of ${target} = ${temp}")
#    file(APPEND "${prefix}${target}${suffix}" ${temp})
#    #list(APPEND target_dep_list ${temp})
#  endforeach ()
#
#  message(STATUS "Going through the dependents of ${target}...")
#  foreach (dep ${target_dep_list})
#    # if dep is a generator expression, extract it
#    string(FIND ${dep} "$<LINK_ONLY:" find_result)
#    if (${find_result} GREATER_EQUAL 0)
#      #message("Detected generator expression: ${dep}")
#      string(LENGTH ${dep} dep_strlen)
#      math(EXPR dep_strlen "${dep_strlen}-13")
#      string(SUBSTRING ${dep} 12 ${dep_strlen} dep)
#      #message("The extracted dep is: ${dep}")
#    endif ()
#
#    # If is dep is a target
#    if (TARGET ${dep})
#      #set(${out_var} ${${out_var}} ${dep} PARENT_SCOPE)
#      file(APPEND "${prefix}${target}${suffix}" ${dep})
#      #list(APPEND result ${dep})
#      message("Add target ${dep} to result")
#      message("result = ${${out_var}}")
#      unset(temp)
#
#      DLLD_glob_target_deps(${dep} dep_deps)
#      message("dep_deps = ${dep_deps}")
#      list(LENGTH dep_deps dep_deps_len)
#      if(${dep_deps_len} GREATER 0)
#        message("Add ${dep_deps} to result")
#        #set(${out_var} ${${out_var}} ${dep_deps} PARENT_SCOPE)
#        file(APPEND "${prefix}${target}${suffix}" ${dep_deps})
#        #message("result = ${${out_var}}")
#        #list(APPEND result x)
#      endif ()
#
#      continue()
#
#    endif ()
#
#    if (EXISTS ${dep})
#      file(APPEND "${prefix}${target}${suffix}" ${dep})
#      #set(${out_var} ${${out_var}} ${dep} PARENT_SCOPE)
#      message("Add file ${dep} to result")
#      message("result = ${${out_var}}")
#      continue()
#    endif ()
#
#    find_library(dep_loc NAMES ${dep} QUIET)
#    if (dep_loc)
#      message("${dep} is recognized as ${dep_loc}")
#      file(APPEND "${prefix}${target}${suffix}" ${dep_loc})
#      #set(${out_var} ${${out_var}} ${dep_loc} PARENT_SCOPE)
#      message("Add library ${dep_loc} to result")
#      message("result = ${${out_var}}")
#      continue()
#    endif ()
#
#    message(WARNING "Unknown dep \"${dep}\" is not a file or target")
#
#  endforeach ()
#  #file(APPEND "${prefix}${target}${suffix}" ${dep_deps})
#  file(READ "${prefix}${target}${suffix}" temp_file_read_result)
#  set(${out_var} ${temp_file_read_result} PARENT_SCOPE)
#  message("end of function, result = ${out_var}")
#
#endfunction()


#function(DLLD_deploy_for_exe target destination)
#  cmake_parse_arguments(DLLD_deploy_for_exe
#    "NO_RECURSE;INSTALL_SYSTEM_DLL" "" "" ${ARGN})
#
#  if (NOT TARGET ${target})
#    message(FATAL_ERROR "The given target \"${target}\" is not a target.")
#  endif ()
#
#  get_target_property(target_type ${target} TYPE)
#
##  if (NOT ${target_type} STREQUAL EXECUTABLE)
##    message(FATAL_ERROR "The given target \"${target}\" is not an executable.")
##  endif ()
#
#  message("Deploying dependents for \"${target}\"")
#  set(target_grab_property_list
#    IMPORTED_LINK_DEPENDENT_LIBRARIES
#    IMPORTED_LINK_DEPENDENT_LIBRARIES
#    LINK_DEPENDS
#    MANUALLY_ADDED_DEPENDENCIES
#    IMPORTED_LIBNAME
#    INTERFACE_LINK_LIBRARIES
#    LINK_INTERFACE_LIBRARIES
#    LINK_LIBRARIES)
#  foreach (prop_name ${target_grab_property_list})
#    unset(temp)
#    get_target_property(temp ${target} ${prop_name})
#    if (NOT temp)
#      continue()
#    endif ()
#    message("${prop_name} of ${target} = ${temp}")
#    foreach (dep ${temp})
#
#      string(FIND ${dep} "$<LINK_ONLY:" find_result)
#      if (${find_result} GREATER_EQUAL 0)
#        message("Detected generator expression: ${dep}")
#        string(LENGTH ${dep} dep_strlen)
#        math(EXPR dep_strlen "${dep_strlen}-13")
#        string(SUBSTRING ${dep} 12 ${dep_strlen} dep)
#        #message("The extracted dep is: ${dep}")
#      endif ()
#
#      if (EXISTS ${dep})
#        message("Handing file ${dep}")
#        DLLD_deploy_lib(${dep} ${destination})
#        continue()
#      endif ()
#
#      if (TARGET ${dep})
#        message("Handing target ${dep}")
#        DLLD_deploy_lib(${dep} ${destination})
#        DLLD_deploy_for_exe(${dep} ${destination})
#        continue()
#      endif ()
#
#      find_library(dep_lib_location ${dep} QUIET)
#      if (dep_lib_location)
#        message("Handing name only library ${dep}")
#        DLLD_deploy_lib(${dep_lib_location} ${destination})
#        continue()
#      endif ()
#
#      message(WARNING "No rule to handel dep named ${dep}")
#    endforeach ()
#
#  endforeach ()
#endfunction()

function(test_recurse folder out_var)
    unset(${out_var} PARENT_SCOPE)

    file(GLOB temp_list "${folder}/*")
    set(file_list_temp)
    foreach (item ${temp_list})
        if(IS_DIRECTORY ${item})
            test_recurse(${item} temp_var)
            list(APPEND file_list_temp ${temp_var})
        else ()
            list(APPEND file_list_temp ${item})
        endif ()
    endforeach ()
    set(${out_var} ${file_list_temp} PARENT_SCOPE)
endfunction(test_recurse)

function(DLLD_get_target_deps target_name out_var)
    unset(${out_var} PARENT_SCOPE)
    if(NOT TARGET ${target_name})
        return()
    endif ()

      set(target_grab_property_list
        IMPORTED_LINK_DEPENDENT_LIBRARIES
        IMPORTED_LINK_DEPENDENT_LIBRARIES
        LINK_DEPENDS
        MANUALLY_ADDED_DEPENDENCIES
        IMPORTED_LIBNAME
        INTERFACE_LINK_LIBRARIES
        LINK_INTERFACE_LIBRARIES
        LINK_LIBRARIES)

    set(temp_list)
    foreach (prop_name ${target_grab_property_list})
        get_target_property(prop_values ${target_name} ${prop_name})
        if(prop_values)
            list(APPEND temp_list ${prop_values})
        endif ()
    endforeach ()

    set(${out_var} ${temp_list} PARENT_SCOPE)
endfunction()


function(glob_deps_recurse target_name out_var)
    unset(${out_var} PARENT_SCOPE)
    if(NOT TARGET ${target_name})
        return()
    endif ()

    DLLD_get_target_deps(${target_name} target_deps)
    set(dep_list_recurse)
    foreach (dep ${target_deps})
        list(APPEND dep_list_recurse ${dep})
        if(TARGET ${dep})
            glob_deps_recurse(${dep} deps_of_dep)
            list(APPEND dep_list_recurse ${deps_of_dep})
        endif ()
    endforeach ()

    set(${out_var} ${dep_list_recurse} PARENT_SCOPE)
endfunction()
