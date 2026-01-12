#!/bin/bash
# Helper script to build EmulationStation FCAMOD for arm64 using Docker
# Usage: ./build-docker-arm64.sh [options]
#
# Options:
#   --clean       Remove existing Docker image and rebuild
#   --shell       Open a shell in the container instead of building
#   --help        Show this help message
#
# Environment variables (optional):
#   SCREENSCRAPER_DEV_LOGIN   ScreenScraper developer credentials
#   GAMESDB_APIKEY            TheGamesDB API key
#   SCREENSCRAPER_SOFTNAME    Custom build name for ScreenScraper

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="emulationstation-arm64"
DOCKERFILE="Dockerfile.arm64"
DOCKERFILE="docker/Dockerfile.arm64"

show_help() {
    head -15 "$0" | tail -13 | sed 's/^# //' | sed 's/^#//'
    exit 0
}

# Parse arguments
CLEAN=0
SHELL_MODE=0
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN=1
            shift
            ;;
        --shell)
            SHELL_MODE=1
            shift
            ;;
        --help|-h)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

cd "$SCRIPT_DIR"

# Check if Dockerfile exists
if [[ ! -f "$DOCKERFILE" ]]; then
    echo "Error: $DOCKERFILE not found in $SCRIPT_DIR"
    exit 1
fi

# Clean if requested
if [[ $CLEAN -eq 1 ]]; then
    echo "Removing existing Docker image..."
    docker rmi "$IMAGE_NAME" 2>/dev/null || true
fi

# Build Docker image if it doesn't exist
if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo "Building Docker image '$IMAGE_NAME'..."
    docker build -f "$DOCKERFILE" -t "$IMAGE_NAME" .
fi

# Prepare environment variables for Docker
DOCKER_ENV="-e HOST_UID=$(id -u) -e HOST_GID=$(id -g)"
if [[ -n "$SCREENSCRAPER_DEV_LOGIN" ]]; then
    DOCKER_ENV="$DOCKER_ENV -e SCREENSCRAPER_DEV_LOGIN=$SCREENSCRAPER_DEV_LOGIN"
fi
if [[ -n "$GAMESDB_APIKEY" ]]; then
    DOCKER_ENV="$DOCKER_ENV -e GAMESDB_APIKEY=$GAMESDB_APIKEY"
fi
if [[ -n "$SCREENSCRAPER_SOFTNAME" ]]; then
    DOCKER_ENV="$DOCKER_ENV -e SCREENSCRAPER_SOFTNAME=$SCREENSCRAPER_SOFTNAME"
fi

# Run Docker container
if [[ $SHELL_MODE -eq 1 ]]; then
    echo "Opening shell in container..."
    docker run --rm -it \
        -v "$SCRIPT_DIR:/src" \
        $DOCKER_ENV \
        "$IMAGE_NAME" \
        /bin/bash
else
    echo "Starting arm64 cross-compilation build..."
    docker run --rm \
        -v "$SCRIPT_DIR:/src" \
        $DOCKER_ENV \
        "$IMAGE_NAME"

    echo ""
    echo "=========================================="
    echo "Build completed successfully!"
    echo "Binary location: $SCRIPT_DIR/"
    echo "=========================================="
fi
