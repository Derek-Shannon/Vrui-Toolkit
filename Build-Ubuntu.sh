#!/bin/bash

# 1. Get prerequisite packages
PREREQUISITE_PACKAGES="build-essential g++ libudev-dev libdbus-1-dev libusb-1.0-0-dev zlib1g-dev libssl-dev libpng-dev libjpeg-dev libtiff-dev libasound2-dev libspeex-dev libopenal-dev libv4l-dev libdc1394-dev libtheora-dev libbluetooth-dev libfreetype6-dev libxi-dev libxrandr-dev mesa-common-dev libgl1-mesa-dev libglu1-mesa-dev"
echo "Please enter your password to install Vrui's prerequisite packages"
sudo apt-get install -y $PREREQUISITE_PACKAGES
INSTALL_RESULT=$?

if [ $INSTALL_RESULT -ne 0 ]; then
    echo "Problem while downloading prerequisite packages; please fix the issue and try again"
    exit $INSTALL_RESULT
fi

# 2. Create and enter src directory
echo "Navigating to source code directory $HOME/src"
mkdir -p $HOME/src
cd $HOME/src || exit 1

# 3. Determine Vrui version
# If you specifically need 8.0-002, you can hardcode these:
# VRUI_VERSION="8.0"
# VRUI_RELEASE="002"
VRUI_CURRENT_RELEASE=$(wget -q -O - http://web.cs.ucdavis.edu/~okreylos/ResDev/Vrui/CurrentVruiRelease.txt)
read VRUI_VERSION VRUI_RELEASE <<< "$VRUI_CURRENT_RELEASE"

VRUI_DIR="Vrui-$VRUI_VERSION-$VRUI_RELEASE"

# 4. Download and unpack only if the directory doesn't exist
if [ -d "$VRUI_DIR" ]; then
    echo "Directory $VRUI_DIR already exists. Skipping download to preserve your manual fixes (like SoundContext.h)."
else
    echo "Downloading $VRUI_DIR..."
    wget -O - http://web.cs.ucdavis.edu/~okreylos/ResDev/Vrui/$VRUI_DIR.tar.gz | tar xfz -
fi

# 5. Move into the directory (Crucial step)
cd "$VRUI_DIR" || { echo "Could not enter directory $VRUI_DIR"; exit 1; }

# 6. Resolve TLS Mismatch (Clean the bad files)
echo "Cleaning old object files to resolve TLS reference mismatch..."
rm -rf o/
rm -rf lib/

# 7. Set up installation directory
VRUI_INSTALLDIR=/usr/local
if [ $# -ge 1 ]; then
    VRUI_INSTALLDIR=$1
fi

INSTALL_NEEDS_SUDO=1
[[ $VRUI_INSTALLDIR = $HOME* ]] && INSTALL_NEEDS_SUDO=0
VRUI_MAKEDIR=$VRUI_INSTALLDIR/share/Vrui-$VRUI_VERSION/make
[[ $VRUI_INSTALLDIR = *Vrui-$VRUI_VERSION* ]] && VRUI_MAKEDIR=$VRUI_INSTALLDIR/share/make 

NUM_CPUS=$(nproc)

# 8. Build Vrui with modern compatibility flags
echo "Building Vrui on $NUM_CPUS CPUs..."
# -fPIC: Position Independent Code for shared libraries
# -fpermissive: Downgrade some C++ errors to warnings
# -ftls-model: Ensure all files use the same Thread-Local Storage model
COMPILER_FLAGS="-fPIC -fpermissive -ftls-model=global-dynamic"

make -j$NUM_CPUS INSTALLDIR=$VRUI_INSTALLDIR CXXFLAGS="$COMPILER_FLAGS"
BUILD_RESULT=$?

if [ $BUILD_RESULT -ne 0 ]; then
    echo "Build unsuccessful. If you still see TLS errors, try running 'rm -rf o/ lib/' inside $PWD and run this script again."
    exit $BUILD_RESULT
fi

# 9. Install Vrui
echo "Build successful; installing Vrui in $VRUI_INSTALLDIR"
if [ $INSTALL_NEEDS_SUDO -ne 0 ]; then
    sudo make INSTALLDIR=$VRUI_INSTALLDIR install
else
    make INSTALLDIR=$VRUI_INSTALLDIR install
fi

# 10. Install device permission rules
sudo make INSTALLDIR=$VRUI_INSTALLDIR installudevrules

# 11. Build Vrui example applications
cd ExamplePrograms
echo "Building Vrui example programs..."
make -j$NUM_CPUS VRUI_MAKEDIR=$VRUI_MAKEDIR INSTALLDIR=$VRUI_INSTALLDIR CXXFLAGS="$COMPILER_FLAGS"

# 12. Install Vrui example applications
if [ $INSTALL_NEEDS_SUDO -ne 0 ]; then
    sudo make VRUI_MAKEDIR=$VRUI_MAKEDIR INSTALLDIR=$VRUI_INSTALLDIR install
else
    make VRUI_MAKEDIR=$VRUI_MAKEDIR INSTALLDIR=$VRUI_INSTALLDIR install
fi

echo "Installation complete."
echo "Running ShowEarthModel application..."
$VRUI_INSTALLDIR/bin/ShowEarthModel