# set up the external libraries that aren't popular enough to be found on most
# package managers are included with the project (in the 'external' folder)

add_subdirectory("nanosvg")
add_subdirectory("pugixml")

#-------------------------------------------------------------------------------
# libgo2 - Support library for ODROID-GO Advance / rk3326 devices
# Build from source since librga is available in the cross-compile sysroot
#-------------------------------------------------------------------------------
if(GLES)
    # Create the include/go2 directory structure at configure time
    set(LIBGO2_INCLUDE_DIR ${CMAKE_CURRENT_BINARY_DIR}/libgo2/include)
    set(LIBGO2_SRC_DIR ${CMAKE_CURRENT_BINARY_DIR}/libgo2/src)
    file(MAKE_DIRECTORY ${LIBGO2_INCLUDE_DIR}/go2)
    file(MAKE_DIRECTORY ${LIBGO2_SRC_DIR})

    # Copy headers to include/go2/ to match expected include path <go2/display.h>
    # Also copy to src dir for local includes like "display.h"
    file(GLOB LIBGO2_HEADERS ${CMAKE_CURRENT_SOURCE_DIR}/libgo2/src/*.h)
    foreach(HEADER ${LIBGO2_HEADERS})
        get_filename_component(HEADER_NAME ${HEADER} NAME)
        configure_file(${HEADER} ${LIBGO2_INCLUDE_DIR}/go2/${HEADER_NAME} COPYONLY)
        configure_file(${HEADER} ${LIBGO2_SRC_DIR}/${HEADER_NAME} COPYONLY)
    endforeach()

    # Copy source files to build directory so we can patch them
    file(GLOB LIBGO2_ORIG_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/libgo2/src/*.c)
    foreach(SRC ${LIBGO2_ORIG_SOURCES})
        get_filename_component(SRC_NAME ${SRC} NAME)
        configure_file(${SRC} ${LIBGO2_SRC_DIR}/${SRC_NAME} COPYONLY)
    endforeach()

    # Patch display.c to make conflicting symbols static (avoids multiple definition errors)
    execute_process(
        COMMAND sed -i
            -e "s/^const char\\* BACKLIGHT_BRIGHTNESS_NAME/static const char* BACKLIGHT_BRIGHTNESS_NAME/"
            -e "s/^const char\\* BACKLIGHT_BRIGHTNESS_MAX_NAME/static const char* BACKLIGHT_BRIGHTNESS_MAX_NAME/"
            ${LIBGO2_SRC_DIR}/display.c
        RESULT_VARIABLE SED_RESULT
    )
    if(NOT SED_RESULT EQUAL 0)
        message(WARNING "Failed to patch display.c, may have multiple definition errors")
    endif()

    # Source files for libgo2 (from patched copies in build dir)
    set(LIBGO2_SOURCES
        ${LIBGO2_SRC_DIR}/audio.c
        ${LIBGO2_SRC_DIR}/display.c
        ${LIBGO2_SRC_DIR}/hardware.c
        ${LIBGO2_SRC_DIR}/input.c
        ${LIBGO2_SRC_DIR}/queue.c
    )

    # Build libgo2 as a static library
    add_library(go2 STATIC ${LIBGO2_SOURCES})

    # Find required packages
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(DRM REQUIRED libdrm)
    pkg_check_modules(LIBEVDEV REQUIRED libevdev)
    pkg_check_modules(LIBPNG libpng)

    # Find OpenAL
    find_library(OPENAL_LIBRARY
        NAMES openal OpenAL al
        PATHS ${CMAKE_FIND_ROOT_PATH}/usr/lib/aarch64-linux-gnu
              ${CMAKE_FIND_ROOT_PATH}/usr/lib
    )

    # Find librga
    find_library(RGA_LIBRARY
        NAMES rga
        PATHS ${CMAKE_FIND_ROOT_PATH}/usr/lib/aarch64-linux-gnu
              ${CMAKE_FIND_ROOT_PATH}/usr/lib
    )

    # Include directories for building libgo2
    target_include_directories(go2 PRIVATE
        ${LIBGO2_SRC_DIR}
        ${DRM_INCLUDE_DIRS}
        ${LIBEVDEV_INCLUDE_DIRS}
        ${LIBPNG_INCLUDE_DIRS}
        ${CMAKE_FIND_ROOT_PATH}/usr/local/include  # For rga/RgaApi.h
        ${CMAKE_FIND_ROOT_PATH}/usr/include/AL     # For OpenAL
    )

    # Export the include directory so other targets can use <go2/display.h>
    target_include_directories(go2 PUBLIC
        ${LIBGO2_INCLUDE_DIR}
    )

    # Link required libraries
    target_link_libraries(go2 PUBLIC
        ${DRM_LIBRARIES}
        ${LIBEVDEV_LIBRARIES}
        ${LIBPNG_LIBRARIES}
    )
    if(OPENAL_LIBRARY)
        target_link_libraries(go2 PUBLIC ${OPENAL_LIBRARY})
    endif()
    if(RGA_LIBRARY)
        target_link_libraries(go2 PUBLIC ${RGA_LIBRARY})
    endif()

    # Compiler options
    target_compile_options(go2 PRIVATE -Wall)

    # Set C standard
    set_target_properties(go2 PROPERTIES
        C_STANDARD 99
        C_STANDARD_REQUIRED ON
    )
endif()
