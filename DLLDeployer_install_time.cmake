cmake_minimum_required(VERSION 3.20)

if (NOT ${WIN32})
    message(STATUS "This project is designed to deploy dll on windows.")
    return()
endif ()


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

    set(DLLD_system_prefixes
        C:/Windows/system32/
        C:/Windows/
        C:/Windows/System32/Wbem/
        C:/Windows/System32/WindowsPowerShell/v1.0/
        C:/Windows/System32/OpenSSH/)

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
    #find_program(DLLD_msvc_lib_exe NAMES lib REQUIRED)
    find_program(DLLD_msvc_dumpbin_exe NAMES dumpbin REQUIRED)
    # Get dll dependents of a dll
    function(DLLD_get_dll_dependents_norecurse dll_file result_var_name)
        DLLD_is_dll(${dll_file} is_dll)
#        if (NOT ${is_dll})
#            message(WARNING "${dll_file} is not a dll file, but it was passed to function DLLD_get_dll_dependents_norecurse. Nothing will be done to it.")
#            return()
#        endif ()

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
    endfunction(DLLD_get_dll_dependents_norecurse)

else ()

    cmake_path(GET CMAKE_CXX_COMPILER PARENT_PATH compiler_bin_dir)
    find_program(DLLD_gnu_objdump_exe
        NAMES objdump
        HINTS ${compiler_bin_dir})
    # Get dll dependents of a dll
    function(DLLD_get_dll_dependents_norecurse dll_file result_var_name)
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

    endfunction(DLLD_get_dll_dependents_norecurse)
endif ()

function(DLLD_get_dll_dependents dll_location out_var_name)
    unset(${out_var_name} PARENT_SCOPE)

    cmake_parse_arguments(DLLD_get_dll_dependents
        "RECURSE" "" "" ${ARGN})
    #message("DLLD_get_dll_dependents_RECURSE = ${DLLD_get_dll_dependents_RECURSE}")
    cmake_path(GET dll_location PARENT_PATH dll_parent_path)

    set(dep_list)
    DLLD_get_dll_dependents_norecurse(${dll_location} temp)
    #message("Direct deps of ${dll_location} are: ${temp}")
    foreach (dep ${temp})
        DLLD_is_system_dll(${dep} is_system)

        if(EXISTS "${dll_parent_path}/${dep}")
            set(dep_location "${dll_parent_path}/${dep}")
        else ()
            unset(dep_location)
            find_file(dep_location
                NAMES ${dep}
                PATH_SUFFIXES bin
                NO_CACHE
                REQUIRED)
        endif ()


        list(APPEND dep_list ${dep_location})

        if (${is_system})
            continue()
        endif ()

        if (${DLLD_get_dll_dependents_RECURSE})
            DLLD_get_dll_dependents(${dep_location} temp_var RECURSE)
            list(APPEND dep_list ${temp_var})
        endif ()
    endforeach ()
    #list(APPEND dep_list ${temp})

    #    if(${DLLD_get_dll_dependents_RECURSE})
    #        foreach (dep ${temp})
    #            DLLD_get_dll_dependents(${dep} temp_var RECURSE)
    #            list(APPEND dep_list ${temp_var})
    #        endforeach ()
    #    endif ()
    list(REMOVE_DUPLICATES dep_list)
    set(${out_var_name} ${dep_list} PARENT_SCOPE)
endfunction()

function(DLLD_get_exe_dependents exe_file result_var_name)
    DLLD_get_dll_dependents(${exe_file} temp RECURSE)
    set(${result_var_name} ${temp} PARENT_SCOPE)
endfunction()

function(DLLD_deploy_runtime file_location)
    cmake_path(GET file_location EXTENSION extension)
    message("extension = ${extension}")
    set(valid_extensions .exe .dll)
    if (NOT (${extension} IN_LIST valid_extensions))
        message(FATAL_ERROR "${file_location} is not a exe or dll.")
    endif ()

    cmake_parse_arguments(DLLD_deploy_runtime
        "COPY;INSTALL" "DESTINATION" "" ${ARGN})

    DLLD_get_exe_dependents(${file_location} dependent_list)

    foreach (dep ${dependent_list})
        DLLD_is_system_dll(${dep} is_system)
        if(${is_system})
            continue()
        endif ()


        if (${DLLD_deploy_runtime_COPY})
            file(COPY ${dep}
                DESTINATION ${DLLD_deploy_runtime_DESTINATION})
            message("Copy ${dep} to ${DLLD_deploy_runtime_DESTINATION}")
        endif ()
        if(${DLLD_deploy_runtime_INSTALL})
            install(FILES ${dep}
                DESTINATION ${DLLD_deploy_runtime_DESTINATION}                )
            message("Install ${dep} to ${DLLD_deploy_runtime_DESTINATION}")
        endif ()
    endforeach ()
endfunction()