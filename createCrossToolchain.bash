#!/bin/bash

# ************************************************************* #
# createCrossGcc_4_5_0.bash
# Script to create a cross compilation toolchain based on 
# GCC 4.5.0, binutils 2.20.1a and eglibc-2-14. Compiled
# with Linux header from kernel version 2.6.33.3
# ************************************************************* #
# Copyright (C) 2011 Robert Åkerblom-Andersson
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# ************************************************************* #
# Author: Robert Åkerblom-Andersson
# Date: 2011-11-04
# Email: Robert.nr1@gmail.com
# ************************************************************* #

# ************************************************************* #
# Set variables
# ************************************************************* #
export BUILDROOT=$PWD/crossBuild
export PROCESS_FILE=$BUILDROOT/process.txt
export host=$(uname -m)-pc-linux-gnu
export build=$(uname -m)-pc-linux-gnu
export target=arm-linux-gnueabi
export linuxarch=arm
export sysroot=$BUILDROOT/sysroot
export prefix=$BUILDROOT/$target-crossToolChain
export JN=$(($(cat /proc/cpuinfo | grep processor | wc -l)*3)) 
export CFLAGS=" "
export gccVersionAltered="n"
export eraseSdcard="y"
export PKGVERSION="Robert_CrossTools"
# (JN is passed to "-j " for make, $JN is the number of cores
# times 3)

# ************************************************************* #
# Makes sure that the user has the right tools 
# ************************************************************* #
sudo apt-get update
sudo apt-get install build-essential
sudo apt-get install subversion
sudo apt-get install gcc-4.5
sudo apt-get install gperf
sudo apt-get build-dep gcc-4.5

echo ""
echo "Checking Gcc version..."
echo ""
gccVersion=$(gcc -v 2>&1 | tail -1 | awk '{print $3}' | cut -c 1-3)
if [ "$gccVersion" != "4.5" ] ; then 
  echo "Gcc 4.5 is not default Gcc... Checking if Gcc-4.5 is installed"
  echo ""
  ls /usr/bin | grep gcc-4.5
  
  if [ "$?" != "0" ] ; then 
    echo ""
    echo "Gcc 4.5 is not installed and the script failed to install it."
    echo "This is probably because you don't have Gcc 4.5 in your repos."
    echo ""
    echo "You can try and search with: "
    echo "sudo apt-cache search gcc | grep gcc-4.5"
    echo ""
    echo "If you can't find gcc-4.5 try and search here:"
    echo "http://packages.ubuntu.com/"
    echo ""
    echo "Good luck..."
    exit 1
  fi

  echo ""
  echo "You have Gcc 4.5 installed, but it is not your default Gcc version,"
  echo "the default version is \"$gccVersion\""
  echo ""
  echo "You can do it yourself with these commands:"
  echo "sudo mv /usr/bin/gcc /usr/bin/gcc.old"
  echo "sudo ln -s /usr/bin/gcc-4.5 /usr/bin/gcc"
  echo ""
  echo -n "Do you want the script change Gcc 4.5 to the default version (running the command above)? (y/n): "
  read trySetupGcc
  if [ "$trySetupGcc" == "n" ]; then
    echo "Okey, good bye"
    exit
  fi

  sudo mv /usr/bin/gcc /usr/bin/gcc.old
  sudo ln -s /usr/bin/gcc-4.5 /usr/bin/gcc  
  echo "Checking Gcc version..."
  echo ""
  gccVersion=$(gcc -v 2>&1 | tail -1 | awk '{print $3}' | cut -c 1-3)
  if [ "$gccVersion" != "4.5" ] ; then 
    echo "The script failed to change your default gcc version..."
    exit 1
  fi

  gccVersionAltered="y"
  echo "Okey, gcc is now setup correctly!"
  echo ""
fi

# ************************************************************* #
# Make directories
# ************************************************************* #
mkdir -p $BUILDROOT
cd $BUILDROOT

mkdir -p $sysroot
mkdir -p $prefix
mkdir -p binutils
mkdir -p gcc
mkdir -p eglibc

# ************************************************************* #
# Make process file to track process in case an error occured
# ************************************************************* #
cd $BUILDROOT
touch $PROCESS_FILE
echo "Process file for createCrossGcc_4_5_0.bash created..." > $PROCESS_FILE
echo "" >> $PROCESS_FILE

# ************************************************************* #
# Tell the user about the program and process file 
# ************************************************************* #
clear
echo "This program will download source code, and the compile a"
echo "cross compilation toolchain for the ARM architecture."
echo ""
echo "The script does run continuously until it get is finished"
echo "(or some error occurs). If you want to follow the process"
echo "open a new terminal and type the command:"
echo "clear && tail -f $PROCESS_FILE"
echo ""
echo "Copy that line before pressing enter if you don't"
echo "remember it. When ready to start the script please "
echo "press enter."
echo ""

read dummy

# ************************************************************* #
# Get source code
# ************************************************************* #
echo "Downloading source code" >> $PROCESS_FILE
cd $BUILDROOT
echo "  Downloading linux sources" >> $PROCESS_FILE
wget ftp://ftp.fu-berlin.de/unix/linux/ftp.kernel.org/kernel/v2.6/linux-2.6.33.3.tar.gz
cd $BUILDROOT/binutils
echo "  Downloading binutils sources" >> $PROCESS_FILE
wget ftp://ftp.fu-berlin.de/unix/gnu/binutils/binutils-2.20.1a.tar.bz2
cd $BUILDROOT/gcc
echo "  Downloading gcc sources" >> $PROCESS_FILE
wget ftp://ftp.fu-berlin.de/unix/gnu/gcc/gcc-4.5.0/gcc-4.5.0.tar.gz
echo "    Downloading gmp sources" >> $PROCESS_FILE
wget ftp://gcc.gnu.org/pub/gcc/infrastructure/gmp-4.3.2.tar.bz2
echo "    Downloading mpfr sources" >> $PROCESS_FILE
wget ftp://gcc.gnu.org/pub/gcc/infrastructure/mpfr-2.4.2.tar.bz2
echo "    Downloading mpc sources" >> $PROCESS_FILE
wget ftp://gcc.gnu.org/pub/gcc/infrastructure/mpc-0.8.1.tar.gz
echo "    Downloading eglibc sources" >> $PROCESS_FILE
cd $BUILDROOT/eglibc
svn co http://www.eglibc.org/svn/branches/eglibc-2_14 eglibc-2.14

# ************************************************************* #
# Build binutils
# ************************************************************* #
cd $BUILDROOT
echo "Starting to build binutils" >> $PROCESS_FILE
cd $BUILDROOT/binutils
echo "  Unpacking binutils sources" >> $PROCESS_FILE
tar -jxvf binutils-2.20.1a.tar.bz2 
mkdir build
cd build
echo "  Configuring binutils sources" >> $PROCESS_FILE
../binutils-2.20.1/configure \
--target=$target \
--prefix=$prefix \
--with-sysroot=$sysroot \
--with-pkgversion=$PKGVERSION
echo "  Compiling binutils" >> $PROCESS_FILE
make -j $JN
if [ "$?" != "0" ] ; then exit; fi
echo "  Installing binutils" >> $PROCESS_FILE
make -j $JN install
if [ "$?" != "0" ] ; then exit; fi

# ************************************************************* #
# Unpack packages needed by GCC into GCC folder
# ************************************************************* #
echo "  Unpacking gcc sources" >> $PROCESS_FILE
cd $BUILDROOT/gcc
tar -zxvf gcc-4.5.0.tar.gz
echo "Unpack packages needed by GCC" >> $PROCESS_FILE
cd $BUILDROOT/gcc/gcc-4.5.0
echo "  Unpacking gmp sources" >> $PROCESS_FILE
tar -jxvf ../gmp-4.3.2.tar.bz2
echo "  Unpacking mpfr sources" >> $PROCESS_FILE
tar -jxvf ../mpfr-2.4.2.tar.bz2
echo "  Unpacking mpc sources" >> $PROCESS_FILE
tar -zxvf ../mpc-0.8.1.tar.gz
echo "    Create symbollinks for packages" >> $PROCESS_FILE
ln -s gmp-4.3.2 gmp
ln -s mpfr-2.4.2 mpfr
ln -s mpc-0.8.1 mpc

# ************************************************************* #
# Build GCC stage 1
# ************************************************************* #
echo "Starting to build GCC stage 1" >> $PROCESS_FILE
cd $BUILDROOT/gcc
mkdir build
cd build
echo "  Configuring gcc (stage 1) sources" >> $PROCESS_FILE
../gcc-4.5.0/configure \
--target=$target \
--prefix=$prefix \
--without-headers \
--with-newlib \
--disable-shared \
--disable-threads \
--disable-libssp \
--disable-libgomp \
--disable-libmudflap \
--enable-languages=c \
--with-pkgversion=$PKGVERSION
if [ "$?" != "0" ] ; then exit; fi

echo "  Compiling gcc (stage 1)" >> $PROCESS_FILE
PATH=$prefix/bin:$PATH make -j $JN all-gcc
if [ "$?" != "0" ] ; then exit; fi
echo "  Installing gcc (stage 1)" >> $PROCESS_FILE
PATH=$prefix/bin:$PATH make -j $JN install-gcc
if [ "$?" != "0" ] ; then exit; fi

# ************************************************************* #
# Install header files (Linux and eglibc, needed for stage 2)
# ************************************************************* #
echo "Starting to install Linux headers" >> $PROCESS_FILE
cd $BUILDROOT
echo "  Unpacking Linux sources" >> $PROCESS_FILE
tar -zxvf linux-2.6.33.3.tar.gz
cd linux-2.6.33.3
mkdir -p $sysroot/usr
PATH=$prefix/bin:$PATH \
make headers_install CROSS_COMPILE=$target- \
INSTALL_HDR_PATH=$sysroot/usr ARCH=$linuxarch
if [ "$?" != "0" ] ; then exit; fi

echo "Starting to install Eglibc headers" >> $PROCESS_FILE
cd $BUILDROOT
cd eglibc
cp -r eglibc-2.14/ports eglibc-2.14/libc
mkdir build
cd build
# Configure headers
echo "  Configuring eglibc sources (headers only)" >> $PROCESS_FILE
BUILD_CC=gcc
CC=$prefix/bin/$target-gcc \
AR=$prefix/bin/$target-ar \
RANLIB=$prefix/bin/$target-ranlib \
../eglibc-2.14/libc/configure \
--prefix=/usr \
--with-headers=$sysroot/usr/include \
--build=$build \
--host=$target \
--disable-profile \
--without-gd \
--without-cvs \
--enable-add-on \
--with-pkgversion=$PKGVERSION
if [ "$?" != "0" ] ; then exit; fi

echo "  Installing eglibc headers" >> $PROCESS_FILE
make -j $JN install-headers \
install_root=$sysroot \
install-bootstrap-headers=yes
if [ "$?" != "0" ] ; then exit; fi

echo "Fixing some header installation by hand" >> $PROCESS_FILE
# Fix some stuff by hand
mkdir -p $sysroot/usr/lib
make -j $JN csu/subdir_lib
cd csu
cp crt1.o crti.o crtn.o $sysroot/usr/lib

# Produce dummy "libc.so" by compiling with "/dev/null" as simulated c file
$prefix/bin/$target-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o $sysroot/usr/lib/libc.so

# ************************************************************* #
# Build GCC stage 2
# eglibc headers and selected objects files and now installed,
# now we can build GCC stage 2
# ************************************************************* #
echo "Starting to build GCC stage 2" >> $PROCESS_FILE
cd $BUILDROOT
cd gcc/build
rm -rf *
echo "  Configuring gcc (stage 2) sources" >> $PROCESS_FILE
../gcc-4.5.0/configure \
--target=$target \
--prefix=$prefix \
--with-sysroot=$sysroot \
--disable-libssp \
--disable-libgomp \
--disable-libmudflap \
--enable-languages=c \
--with-pkgversion=$PKGVERSION
if [ "$?" != "0" ] ; then exit; fi

echo "  Compiling gcc (stage 2)" >> $PROCESS_FILE
PATH=$prefix/bin:$PATH make -j $JN 
if [ "$?" != "0" ] ; then exit; fi
echo "  Installing gcc (stage 2)" >> $PROCESS_FILE
PATH=$prefix/bin:$PATH make -j $JN install
if [ "$?" != "0" ] ; then exit; fi

# ************************************************************* #
# Build complete Eglibc with the new stage 2 GCC compiler
# ************************************************************* #
echo "Starting to complete eglibc" >> $PROCESS_FILE
cd $BUILDROOT
cd eglibc/build
rm -rf *
echo "  Configuring eglibc sources (complete)" >> $PROCESS_FILE
BUILD_CC=gcc \
CC=$prefix/bin/$target-gcc \
AR=$prefix/bin/$target-ar \
RANLIB=$prefix/bin/$target-ranlib \
../eglibc-2.14/libc/configure \
--prefix=/usr \
--with-headers=$sysroot/usr/include \
--build=$build \
--host=$target \
--disable-profile \
--without-gd \
--without-cvs \
--enable-add-ons \
--with-pkgversion=$PKGVERSION
if [ "$?" != "0" ] ; then exit; fi

echo "  Compiling eglibc (complete)" >> $PROCESS_FILE
PATH=$prefix/bin:$PATH make -j $JN
if [ "$?" != "0" ] ; then exit; fi
echo "  Installing eglibc (complete)" >> $PROCESS_FILE
PATH=$prefix/bin:$PATH make -j $JN install install_root=$sysroot
if [ "$?" != "0" ] ; then exit; fi

# ************************************************************* #
# Build GCC stage 3 (fully functional cross compiler)
# With the new stage 2 compiler, a GCC compiler compiled with 
# a c library so that it could generate it's own libraries like
# libgcc etc.
# ************************************************************* #
echo "Starting to build GCC stage 3" >> $PROCESS_FILE
cd $BUILDROOT
cd gcc/build
rm -rf *
../gcc-4.5.0/configure \
--target=$target \
--prefix=$prefix \
--with-sysroot=$sysroot \
--disable-libssp \
--disable-libgomp \
--disable-libmudflap \
--enable-languages=c,c++ \
--with-pkgversion=$PKGVERSION
if [ "$?" != "0" ] ; then exit; fi

echo "  Compiling gcc (stage 3)" >> $PROCESS_FILE
PATH=$prefix/bin:$PATH make -j $JN 
if [ "$?" != "0" ] ; then exit; fi
echo "  Installing gcc (stage 3)" >> $PROCESS_FILE
PATH=$prefix/bin:$PATH make -j $JN install
if [ "$?" != "0" ] ; then exit; fi

# ************************************************************* #
# Complete the sysroot with some additional libraries not added
# by GCC (since GCC is not build to construct sysroot's)
# ************************************************************* #
echo "Completing the sysroot by installing some by hand" >> $PROCESS_FILE
cp -d $prefix/$target/lib/libgcc_s.so* $sysroot/lib
cp -d $prefix/$target/lib/libstdc++.so $sysroot/usr/lib

# ************************************************************* #
# Now a complete installtion of the toolchains is at $prefix 
# and a complete EGLIB installtion in $sysroot
#
# Creating a test c file, and compiling it with the new compiler,
# checking the ARCH and ABI with the help of the command readelf
# ************************************************************* #
echo "Creating a test.c file" >> $PROCESS_FILE
cd $BUILDROOT

cat > test.c << "EOF"
#include <stdio.h>

int main () {
    int a, b, c, *d;
    d = &a;
    a = b + c;
    printf ("%d", a);
    return 0;
}
EOF

echo "Compiling test.c with new compiler" >> $PROCESS_FILE
$prefix/bin/$target-gcc -o test test.c
if [ "$?" != "0" ] ; then exit; fi

echo "Checking the newly created executeble with readelf" >> $PROCESS_FILE
readelf -h test
if [ "$?" != "0" ] ; then exit; fi

echo ""
echo "createCrossGcc_4_5_0.bash is now done."
echo "If the output above says:"
echo "  ..."
echo "  Machine:                           ARM"
echo "  ..."
echo "  Flags:                             0x5000002, has entry point, Version5 EABI"
echo "  ..."
echo ""
echo "Then the cross compiler seams to work!"
echo ""
echo "Otherwise, check the file \"$PROCESS_FILE\" to see how far the script came"
echo "before it failed and try to debug from there."

echo ""
echo "Moving toolchain out of build directory..."
mv $prefix ..

if [ "$gccVersionAltered" != "y" ] ; then 
  echo ""
  echo "Your default Gcc version was changed by this script, if you want to set"
  echo "the gcc version back, execute this command:"
  echo "sudo mv /usr/bin/gcc.old /usr/bin/gcc"
fi

echo ""  >> $PROCESS_FILE
echo ""
echo "Program done, please the main window if the build was successfull" >> $PROCESS_FILE
