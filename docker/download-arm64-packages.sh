#!/bin/bash
# Script to download arm64 packages for cross-compilation sysroot
# This script is called during Docker image build
#
# Minimal dependency chain based on README.md requirements:
# - Boost (system, filesystem, locale, date-time)
# - FreeImage
# - FreeType
# - cURL
# - ALSA
# - SDL2, SDL2_mixer
# - VLC
# - libdrm, libgbm (for go2 display)
# - libevdev (for go2 input)
# - OpenAL (for go2 audio)
# - libpng (for go2 display)

set -e
cd /tmp/debs

# Function to download package, ignoring errors for optional packages
download_pkg() {
    apt-get download "$1" 2>/dev/null || echo "Warning: Could not download $1"
}

echo "Downloading arm64 packages (minimal set from README.md)..."

#===============================================================================
# CORE C/C++ RUNTIME
#===============================================================================
echo "-> Core C/C++ runtime..."
apt-get download libc6:arm64 libgcc-s1:arm64 libstdc++6:arm64

#===============================================================================
# BOOST LIBRARIES (required by EmulationStation)
#===============================================================================
echo "-> Boost libraries..."
apt-get download libboost-system1.71.0:arm64 libboost-system1.71-dev:arm64
apt-get download libboost-filesystem1.71.0:arm64 libboost-filesystem1.71-dev:arm64
apt-get download libboost-locale1.71.0:arm64 libboost-locale1.71-dev:arm64
apt-get download libboost-date-time1.71.0:arm64 libboost-date-time1.71-dev:arm64
apt-get download libboost1.71-dev:arm64
# Boost dependencies
apt-get download libicu66:arm64

#===============================================================================
# FREETYPE (required)
#===============================================================================
echo "-> FreeType..."
apt-get download libfreetype6:arm64 libfreetype-dev:arm64
# FreeType dependencies
apt-get download libpng16-16:arm64 libpng-dev:arm64
apt-get download zlib1g:arm64 zlib1g-dev:arm64
apt-get download libbz2-1.0:arm64

#===============================================================================
# FREEIMAGE (required)
#===============================================================================
echo "-> FreeImage..."
apt-get download libfreeimage3:arm64 libfreeimage-dev:arm64
# FreeImage dependencies
apt-get download libjpeg-turbo8:arm64 libjpeg8:arm64
download_pkg libjpeg-turbo8-dev:arm64
apt-get download libopenjp2-7:arm64
apt-get download libwebp6:arm64 libwebpmux3:arm64
apt-get download libtiff5:arm64
download_pkg libraw19:arm64
download_pkg libilmbase24:arm64
download_pkg libopenexr24:arm64
download_pkg libjxr0:arm64
download_pkg liblcms2-2:arm64
download_pkg libgomp1:arm64
download_pkg libzstd1:arm64
download_pkg libjbig0:arm64

#===============================================================================
# CURL (required)
#===============================================================================
echo "-> cURL..."
apt-get download libcurl4:arm64 libcurl4-openssl-dev:arm64
# cURL dependencies
apt-get download libssl1.1:arm64 libssl-dev:arm64
apt-get download libnghttp2-14:arm64
download_pkg librtmp1:arm64
download_pkg libssh-4:arm64
apt-get download libpsl5:arm64 libidn2-0:arm64 libunistring2:arm64
apt-get download libgnutls30:arm64
apt-get download libgcrypt20:arm64 libgpg-error0:arm64
apt-get download libnettle7:arm64 libhogweed5:arm64 libgmp10:arm64
apt-get download libp11-kit0:arm64 libtasn1-6:arm64 libffi7:arm64
# Kerberos (cURL dependency)
apt-get download libkrb5-3:arm64 libk5crypto3:arm64 libkrb5support0:arm64
apt-get download libgssapi-krb5-2:arm64 libkeyutils1:arm64 libcom-err2:arm64
apt-get download libcrypt1:arm64
# LDAP (optional cURL dependency)
download_pkg libldap-2.4-2:arm64
download_pkg libsasl2-2:arm64
download_pkg libsasl2-modules-db:arm64

#===============================================================================
# ALSA (required)
#===============================================================================
echo "-> ALSA..."
apt-get download libasound2:arm64 libasound2-dev:arm64

#===============================================================================
# SDL2 (required)
#===============================================================================
echo "-> SDL2..."
apt-get download libsdl2-2.0-0:arm64 libsdl2-dev:arm64
# SDL2 dependencies
apt-get download libx11-6:arm64 libx11-dev:arm64 libx11-data
apt-get download libxau6:arm64 libxdmcp6:arm64
apt-get download libxcb1:arm64 libxcb1-dev:arm64
apt-get download libxext6:arm64 libxext-dev:arm64
apt-get download libxcursor1:arm64 libxi6:arm64 libxinerama1:arm64
apt-get download libxrandr2:arm64 libxss1:arm64 libxxf86vm1:arm64
apt-get download libxfixes3:arm64 libxrender1:arm64
apt-get download x11proto-dev
apt-get download libxkbcommon0:arm64 libxkbcommon-dev:arm64
apt-get download libbsd0:arm64
# Wayland (SDL2 dependency)
apt-get download libwayland-client0:arm64 libwayland-server0:arm64
apt-get download libwayland-cursor0:arm64 libwayland-egl1:arm64
apt-get download libwayland-dev:arm64
# DBus/systemd (SDL2 dependency)
apt-get download libdbus-1-3:arm64 libsystemd0:arm64
apt-get download libexpat1:arm64
apt-get download libpcre2-8-0:arm64 libpcre3:arm64
download_pkg libselinux1:arm64
apt-get download liblzma5:arm64 liblz4-1:arm64
download_pkg libcap2:arm64

#===============================================================================
# SDL2_MIXER (required)
#===============================================================================
echo "-> SDL2_mixer..."
apt-get download libsdl2-mixer-2.0-0:arm64 libsdl2-mixer-dev:arm64
# SDL2_mixer audio format dependencies
apt-get download libflac8:arm64 libogg0:arm64
apt-get download libvorbis0a:arm64 libvorbisenc2:arm64 libvorbisfile3:arm64
apt-get download libopus0:arm64 libmpg123-0:arm64
download_pkg libmodplug1:arm64
download_pkg libopusfile0:arm64

#===============================================================================
# VLC (required)
#===============================================================================
echo "-> VLC..."
apt-get download libvlc5:arm64 libvlc-dev:arm64
apt-get download libvlccore9:arm64 libvlccore-dev:arm64

#===============================================================================
# LIBGO2 DEPENDENCIES (for Odroid Go Advance / rk3326 devices)
#===============================================================================
echo "-> libgo2 dependencies (DRM, GBM, evdev, OpenAL)..."

# DRM and GBM (display)
apt-get download libdrm2:arm64 libdrm-dev:arm64 libdrm-common
apt-get download libgbm1:arm64 libgbm-dev:arm64

# Input handling
apt-get download libevdev2:arm64 libevdev-dev:arm64

# OpenAL (audio)
apt-get download libopenal1:arm64 libopenal-dev:arm64
download_pkg libopenal-data
download_pkg libsndio7.0:arm64
download_pkg libsndfile1:arm64
download_pkg libasyncns0:arm64
download_pkg libwrap0:arm64

# PulseAudio (OpenAL backend)
apt-get download libpulse0:arm64

#===============================================================================
# DONE
#===============================================================================
echo ""
echo "Download complete!"
echo "Total packages downloaded: $(ls -1 *.deb 2>/dev/null | wc -l)"
