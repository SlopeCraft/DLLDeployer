# DLL Deployer

A cmake script to deploy dlls during installation and packaging.

## Usage:
```cmake
include(DLLDeployer.cmake)
```

## Documentation:
1. `DLLD_is_dll(library_file out_var_name)`

   Tells if the given file is a dll.
2. `DLLD_is_system_dll(lib_file out_var_name)`

   Tells if the given file is a system library.
3. `DLLD_get_location(target result_var_name)`

    Get the location of `${target}`. 

    If the `${target}` is a target, return its location; otherwise `${target}` is considered to be a file, the function will return `${target}`.

4. `DLLD_get_export_lib_targets(export_lib_file link_targets_out_var_name)`
   
    List all corresponding DLLs of an export library, for example, `zlib.dll.a`.

    This function will retrieve binary information of `${export_lib_file}` with binary utils supplied by the compiler tool chain(`lib.exe` for msvc-like and `objump.exe` for mingw-like), and stores the directly required libraries to `link_targets_out_var_name`.

    Usually one export lib corresponds to only one dynamic lib.

5. `DLLD_get_dll_dependents(dll_file result_var_name)`

    Get runtime dependents of a dll. All dependents of `${dll_file}` will be stored as a list in `${result_var_name}`

    This function is also implemented with binary utils. 

6. `DLLD_library_type(lib_file type_out_var_name)`

    Find the type of `${lib_file}` and store it into `type_out_var_name`.

    Possible results: `unknown`, `dynamic_lib`, `static_lib`, `export_lib`
   1. `unknown` means that we can not deduce the type of `${lib_file}`. It may be an interface target, or even not an executable.
   2. `dynamic_lib` refers to dlls.
   3. `static_lib` refers to real static libs, but not export libs of a dynamic lib.
   4. `export_lib` refers to export libs of dynamic libs.

7. `DLLD_deploy_dll(dll_location destination)`

    Install a dll and its dependents. By default, this function will install `${dll_location}` to `${destination}` by `install(FILES ...)`, and then go through all its dependents **recursively**. All dlls required will be installed in the same way, except system dlls.

    The full function prototype is:
    ```cmake
    DLLD_deploy_dll(dll_location destination
      NO_RECURSE
      INSTALL_SYSTEM_DLL)
    ```
    You can add extra parameters to control the behavior of this function.
    1. `NO_RECURSE` will stop the function from searching and installing dependents recursively, ony the given dll will be installed.
    2. `INSTALL_SYSTEM_DLL` will enable the function to install system dlls. Note that this function will never deploy dependents for system dlls. As a result, only directly used system dlls will be deployed, and we won't worry about copying the whole system to the installation prefix.

8. `DLLD_deploy_lib(target destination)`

    Install required dlls for `${target}`

    The full function prototype is:
    ```cmake
    DLLD_deploy_lib(target destination
      NO_RECURSE
      INSTALL_SYSTEM_DLL)
    ```
    This function will check the type of `${target}`. 
    - If `${target}` is a dynamic lib, the lib and all its dll dependent will be installed to `${destination}` .
    - If `${target}` is an export lib, the related dynamic lib will be installed like the previous line.
    - If `${target}` is a static lib, object file, interface target or an executable, nothing will be done.

    All extra flags have the same effect as to `DLLD_deploy_dll`.