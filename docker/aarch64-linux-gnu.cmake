# aarch64 cross-compilation toolchain

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# Compilers
set(CMAKE_C_COMPILER aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)
set(CMAKE_ASM_COMPILER aarch64-linux-gnu-gcc)

# Sysroot configuration (can be overridden via -DCMAKE_SYSROOT=...)
if(NOT DEFINED CMAKE_SYSROOT)
    if(DEFINED ENV{SYSROOT})
        set(CMAKE_SYSROOT $ENV{SYSROOT})
    elseif(EXISTS "/usr/aarch64-linux-gnu-sysroot")
        set(CMAKE_SYSROOT "/usr/aarch64-linux-gnu-sysroot")
    endif()
endif()

# Set find root path to sysroot if defined
if(CMAKE_SYSROOT)
    set(CMAKE_FIND_ROOT_PATH ${CMAKE_SYSROOT})

    # Add sysroot library paths
    list(APPEND CMAKE_LIBRARY_PATH
        ${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu
        ${CMAKE_SYSROOT}/lib/aarch64-linux-gnu
    )

    # Add link directories for the sysroot libraries
    # This ensures the linker can find EGL, GLES, and other libraries
    link_directories(
        ${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu
        ${CMAKE_SYSROOT}/lib/aarch64-linux-gnu
        ${CMAKE_SYSROOT}/usr/lib
    )

    # Add sysroot include paths
    list(APPEND CMAKE_INCLUDE_PATH
        ${CMAKE_SYSROOT}/usr/include
        ${CMAKE_SYSROOT}/usr/include/aarch64-linux-gnu
    )

    # Configure pkg-config for sysroot
    set(ENV{PKG_CONFIG_SYSROOT_DIR} "${CMAKE_SYSROOT}")
    set(ENV{PKG_CONFIG_LIBDIR} "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/pkgconfig:${CMAKE_SYSROOT}/usr/share/pkgconfig:/usr/share/pkgconfig")
    set(ENV{PKG_CONFIG_PATH} "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/pkgconfig:${CMAKE_SYSROOT}/usr/share/pkgconfig")
else()
    # Fallback to standard paths when no sysroot is defined
    set(ENV{PKG_CONFIG_LIBDIR} "/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig")
    set(ENV{PKG_CONFIG_PATH} "/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig")
endif()

# Ensure find operations prefer target root paths
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Compiler flags for aarch64
set(CMAKE_C_FLAGS_INIT "-march=armv8-a")
set(CMAKE_CXX_FLAGS_INIT "-march=armv8-a")

# Linker flags to ensure libraries in sysroot are found
# --no-as-needed prevents stripping of indirectly used libraries (like EGL/GLES from Mali)
# --allow-shlib-undefined allows missing transitive dependencies (resolved at runtime on target)
set(CMAKE_EXE_LINKER_FLAGS_INIT "-L${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu -Wl,--no-as-needed -Wl,--allow-shlib-undefined -Wl,-rpath-link,${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "-L${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu -Wl,--allow-shlib-undefined -Wl,-rpath-link,${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu")

# Go2 headers and library paths for cross-compilation
# These are used by CMakeLists.txt for go2 display support
if(CMAKE_SYSROOT)
    set(GO2_SRC_DIR "${CMAKE_SYSROOT}/usr/include/go2" CACHE PATH "Path to go2 source headers")
    set(LIBDRM_INCLUDE_DIR "${CMAKE_SYSROOT}/usr/include/libdrm" CACHE PATH "Path to libdrm headers")
    # librga headers are in /usr/local/include/rga (christianhaitian build)
    set(LIBRGA_INCLUDE_DIR "${CMAKE_SYSROOT}/usr/local/include" CACHE PATH "Path to librga headers")
endif()
