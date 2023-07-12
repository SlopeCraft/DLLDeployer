# DLL Deployer

A cmake script to deploy dlls during installation and packaging. Compatible with cpack.

This script is compatible with gcc(mingw), msvc and clang. 
For clang, all c++ standard libs(msvc, libstdc++ and libc++) are supported.

## Usage:
DLLDeployer:
```cmake
include(DLLDeployer.cmake)

add_executable(test ...)
target_link_libraries(test PRIVATE ...)
install(TARGETS test
    RUNTIME DESTINATION bin)

# Deploy dlls at binary dir, but not automatically
DLLD_add_deploy(test BUILD_MODE)
# Automatically
DLLD_add_deploy(test BUILD_MODE ALL)

# Deploy dlls at installation prefix
DLLD_add_deploy(test INSTALL_MODE INSTALL_DESTINATION bin)
```

QtDeployer:
```cmake
include(QtDeployer.cmake)
add_executable(test ...)
find_package(Qt6 COMPONENTS Widgets Tools REQUIRED)
target_link_libraries(test PRIVATE Qt6::Widgets)

install(TARGETS test 
    RUNTIME DESTINATION bin)
QD_add_deployqt(test
    BUILD_MODE ALL
    INSTALL_MODE INSTALL_DESTINATION bin
    FLAGS -no-translations)
```

## Documentation:

### Main functions:
#### 1. `DLLD_add_deploy(target_name)`

This function is used to deploy required dlls for an executable target.

The complete function prototype is:
```cmake
DLLD_add_deploy(target_name 
[BUILD_MODE] [ALL]
[INSTALL_MODE] [INSTALL_DESTINATION])
```
   
`DLLD_add_deploy` can work in two modes: build mode and install mode. In the **build mode**, it deploys dlls to the binary dir where your executable is compiled, and in the **install mode**, it deploys dlls in the installation dir.

1. Build mode

    In build mode,
    this function will create a custom target named `DLLD_deploy_for_${target_name}` to execute during compilation.
    If `ALL` is assigned, the custom target will be built if you run `cmake --build .`. 
    
    Another custom target `DLLD_deploy_all` will be also added. If you build this target, all custom targets that are created by `DLLD_add_deploy` will be built automatically.

2.  Install mode

    In the install mode, you must the installation prefix of `${target_name}` to `INSTALL_DESTINATION`,
    otherwise DLLDeployer will not be able to find the installed executable.
    
    It's strongly recommended to pass installation prefix in a **relative path**, because installation not only happens when you run `cmake --install .`, but also when you run `cpack -G ...`,
    using an absolute path will stop DllDeployer for deploying dlls correctly when cpack is working.

#### 2. `QD_add_deployqt(target_name)`

This function is used to run `windeployqt` for an executable target. `windeployqt.exe` can copy all required Qt dlls and compiler runtime to the parent path of an executable.

The complete function prototype is:
```cmake
QD_add_deployqt(target_name
[BUILD_MODE] [ALL]
[INSTALL_MODE] [INSTALL_DESTINATION]
[FLAGS])
```

`FLAGS` refers to flags passed to `windeployqt.exe`.

`BUILD_MODE`, `ALL`, `INSTALL_MODE` and `INSTALL_DESTINATION` have same effect in `DLLD_add_deploy`. The only difference is that, `DLLD_deploy_for_${target_name}` will be replaced with `QD_deploy_for_${target_name}` and `DLLD_deploy_all` will be replaced with `QD_deploy_all`.

Note that `windeployqt` is not part of `qtbase`, but provided by another submodule named `qttools`.
**If your Qt is built by yourself, don't forget `qttols`.**

### Internal functions:

1. `DLLD_is_dll(library_file out_var_name)`

   Tells if the given file is a dll.
2. `DLLD_is_system_dll(lib_file out_var_name)`

   Tells if the given file is a system dll.

3. `DLLD_get_dll_dependents_norecurse(dll_file result_var_name)`
    
    Get direct dependents of a dll. This function is implemented with binary utils.

4. `DLLD_get_dll_dependents(dll_file result_var_name)`

    Get runtime dependents of a dll. All dependents of `${dll_file}` will be stored as a list in `${result_var_name}`

    The complete function prototype is: 
    ```cmake
    DLLD_get_dll_dependents(dll_file result_var_name
    [RECURSE]
    [SKIP_SYSTEM_DLL])
    ```
    
    Passing `RECURSE` will search recursively to get all dlls required.

    Passing `SKIP_SYSTEM_DLL` will remove system dlls for the result.

5. `DLLD_get_exe_dependents(exe_file result_var_name)`
    
    Get runtime dependents of an exe. This is implemented by searching recursively with the previous function.

6. `DLLD_deploy_runtime(file_location)`
    
    Deploy dlls for a `${file_location}`, expected existing file.

    The complete function prototype is: 
    ```cmake
    DLLD_deploy_runtime(file_location
    [COPY] [INSTALL]
    [DESTINATION]...)
    ```
   
    - If `COPY` is used, all required dlls will be deployed immediately in the same dir of `${file_location}`.
    - If `INSTALL` is used, all required dlls will be deployed when you run `cmake --install ...`. You must assign the destination via `DESTINATION` parameter.
      - `COPY` and `INSTALL` can work individually.
      - `COPY` copies files with `file(COPY ...)`, so it's done immediately; but `INSTALL` does it with `install(FILES ... DESTINATION ...)`, **so copying will take place when the whole project is being installed and packed**.