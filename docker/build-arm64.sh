#!/bin/bash
#===============================================================================
# Build script for cross-compiling EmulationStation FCAMOD for arm64
# This script runs inside the Docker container
#===============================================================================

set -e

SYSROOT="/usr/aarch64-linux-gnu-sysroot"
BUILD_DIR="build-arm64-docker"

#===============================================================================
# PREPARE
#===============================================================================
cd /src

# Initialize git submodules if needed
if [ -f .gitmodules ]; then
    echo "Initializing git submodules..."
    git submodule update --init --recursive 2>/dev/null || true
fi

# Clean previous build
echo "Preparing build directory..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

#===============================================================================
# CONFIGURE
#===============================================================================
echo "Configuring with CMake..."

CMAKE_ARGS=(
    -DCMAKE_TOOLCHAIN_FILE=/src/docker/aarch64-linux-gnu.cmake
    -DCMAKE_FIND_ROOT_PATH="$SYSROOT"
    -DCMAKE_SYSROOT="$SYSROOT"
    -DGLES=ON
    -DCMAKE_BUILD_TYPE=Release
)

# Optional: ScreenScraper credentials
[ -n "$SCREENSCRAPER_DEV_LOGIN" ] && CMAKE_ARGS+=(-DSCREENSCRAPER_DEV_LOGIN="$SCREENSCRAPER_DEV_LOGIN")
[ -n "$GAMESDB_APIKEY" ] && CMAKE_ARGS+=(-DGAMESDB_APIKEY="$GAMESDB_APIKEY")
[ -n "$SCREENSCRAPER_SOFTNAME" ] && CMAKE_ARGS+=(-DSCREENSCRAPER_SOFTNAME="$SCREENSCRAPER_SOFTNAME")

cmake .. "${CMAKE_ARGS[@]}"

#===============================================================================
# BUILD
#===============================================================================
echo "Building EmulationStation..."
make -j$(nproc)

#===============================================================================
# VERIFY
#===============================================================================
echo ""
echo "=========================================="
echo "Verifying build..."
echo "=========================================="

# Binary is output to source directory (set by EXECUTABLE_OUTPUT_PATH in CMakeLists.txt)
BINARY_PATH="/src/emulationstation"

if [ -f "$BINARY_PATH" ]; then
    echo "Binary: $BINARY_PATH"
    echo "Size: $(du -h "$BINARY_PATH" | cut -f1)"
    echo ""
else
    echo "ERROR: Binary not found!"
    exit 1
fi

#===============================================================================
# FIX PERMISSIONS
#===============================================================================
if [ -n "$HOST_UID" ] && [ -n "$HOST_GID" ]; then
    echo ""
    echo "Fixing permissions for host user..."
    chown -R "$HOST_UID:$HOST_GID" /src/${BUILD_DIR}
    chown -R "$HOST_UID:$HOST_GID" /src/emulationstation
fi

#===============================================================================
# DONE
#===============================================================================
echo ""
echo "=========================================="
echo "Build complete!"
echo "Binary: /src/emulationstation"
echo "=========================================="
