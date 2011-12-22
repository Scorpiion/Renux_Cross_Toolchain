#!/bin/bash

# ************************************************************* #
# createCrossToolchain.bash
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
export src="${PWD}/src"
export processFile="${PWD}/process.txt"
export crossSrcPrefix="Renux_cross"
export buildPackage=""
export host=$(uname -m)-pc-linux-gnu
export build=$(uname -m)-pc-linux-gnu
export target=arm-linux-gnueabi
export linuxarch=arm
export prefix="${PWD}/${target}-crossToolChain"
export sysroot="${prefix}/sysroot"
export JN=$(($(cat /proc/cpuinfo | grep processor | wc -l)*3)) 
export CFLAGS=" "
export gccVersionAltered="n"
export eraseSdcard="y"
export installToolchain="n"
export PKGVERSION="Renux_cross_toolchain"
# (JN is passed to "-j " for make, $JN is the number of cores
# times 3)

# ************************************************************* #
# Check Gcc version
# ************************************************************* #

echo ""
echo "Checking Gcc version..."
echo ""
gccVersion=$(gcc -v 2>&1 | tail -1 | awk '{print $3}' | cut -c 1-3)
if [ "$gccVersion" != "4.5" ] ; then 
  echo "Gcc 4.5 is not default Gcc... Checking if Gcc-4.5 is installed..."
  ls /usr/bin | grep gcc-4.5
  
  if [ "$?" != "0" ] ; then 
    echo "Gcc 4.5 is not installed!"
    echo ""
    echo "Try and install it with:"
    echo "sudo apt-get install gcc-4.5"
    echo ""
    echo "If that does not work, try this: (copy this text somewhere, during the "
    echo "install of gcc a lot of text will be printed to the screen, answer yes if asked"
    echo "to restart services)"
    echo "sudo sed -i 's/oneiric/lucid/g' /etc/apt/sources.list &> /dev/null"
    echo "sudo apt-get update &> /dev/null"
    echo "sudo apt-get install gcc-4.5"
    echo "sudo sed -i 's/lucid/oneiric/g' /etc/apt/sources.list &> /dev/null"
    echo "sudo apt-get update &> /dev/null"
    echo ""
    echo "If you still can't install gcc-4.5 try and search for the package here:"
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
  echo -n "Do you want this script to try and change the default Gcc version to 4.5 (running the command above)? (y/n): "
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
# Make top level directories
# ************************************************************* #
mkdir -p $src
mkdir -p $sysroot
mkdir -p $prefix

# ************************************************************* #
# Make process file to track process in case an error occured
# ************************************************************* #
cd $src
touch $processFile
echo "Process file for createCrossToolchain.bash created..." > $processFile
echo "" >> $processFile

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
echo "clear && tail -f $processFile"
echo ""
echo "Copy that line before pressing enter if you don't"
echo "remember it. When ready to start the script please "
echo "press enter."

read dummy

# ************************************************************* #
# Get source code
# ************************************************************* #
cd $src
echo "Downloading source code" >> $processFile

srcPackages=("binutils" "gcc" "eglibc")
for buildPackage in "${srcPackages[@]}" ; do
  if [ ! -d "$src/${crossSrcPrefix}_${buildPackage}" ] ; then
    echo "Downloading ${buildPackage} sources"
    echo "  Downloading ${buildPackage} sources" >> $processFile
    git clone git://github.com/Scorpiion/Renux_cross_${buildPackage}.git
  else
    echo "${buildPackage} sources already downloaded, checking for changes"
    echo "  ${buildPackage} sources already downloaded, checking for changes" >> $processFile
    git pull git://github.com/Scorpiion/Renux_cross_${buildPackage}.git
  fi
  echo ""
done

# ************************************************************* #
# Make build directories
# ************************************************************* #
srcPackages=("binutils" "gcc" "eglibc")
for buildPackage in "${srcPackages[@]}" ; do
  mkdir -p $src/${crossSrcPrefix}_${buildPackage}/build_${buildPackage}
done

# ************************************************************* #
# Check software versions
# ************************************************************* #
binutilsVersion=$(cat $src/${crossSrcPrefix}_binutils/version.txt | awk 'NR == 1 {print $1}')
gccVersion=$(cat $src/${crossSrcPrefix}_gcc/version.txt | awk 'NR == 1 {print $1}')
gmpVersion=$(cat $src/${crossSrcPrefix}_gcc/version.txt | awk 'NR == 2 {print $1}')
mpcVersion=$(cat $src/${crossSrcPrefix}_gcc/version.txt | awk 'NR == 3 {print $1}')
mpfrVersion=$(cat $src/${crossSrcPrefix}_gcc/version.txt | awk 'NR == 4 {print $1}')
eglibcVersion=$(cat $src/${crossSrcPrefix}_eglibc/version.txt | awk 'NR == 1 {print $1}')
linuxVersion=$(cat $src/${crossSrcPrefix}_eglibc/version.txt | awk 'NR == 2 {print $1}')

# ************************************************************* #
# Build binutils
# ************************************************************* #
buildPackage="binutils"
packageVersion=$binutilsVersion

echo "Starting to build $buildPackage" >> $processFile
echo "  Configuring $buildPackage sources" >> $processFile
cd $src/${crossSrcPrefix}_${buildPackage}/build_${buildPackage}
$src/${crossSrcPrefix}_${buildPackage}/${buildPackage}-${packageVersion}/configure \
--target=$target \
--prefix=$prefix \
--with-sysroot=$sysroot \
--with-pkgversion=$PKGVERSION
echo "  Compiling $buildPackage" >> $processFile
make -j $JN
if [ "$?" != "0" ] ; then exit; fi
echo "  Installing $buildPackage" >> $processFile
make -j $JN install
if [ "$?" != "0" ] ; then exit; fi

# ************************************************************* #
# Create symbollinks for gcc libraries
# ************************************************************* #
buildPackage="gcc"
packageVersion=$gccVersion

echo "  Create symbollinks for gcc libraries" >> $processFile
cd $src/${crossSrcPrefix}_${buildPackage}/${buildPackage}-${packageVersion}
ln -s ../gmp-${gmpVersion} gmp
ln -s ../mpc-${mpcVersion} mpc
ln -s ../mpfr-${mpfrVersion} mpfr

# ************************************************************* #
# Build GCC stage 1
# ************************************************************* #
buildPackage="gcc"
packageVersion=$gccVersion

echo "Starting to build GCC stage 1" >> $processFile
cd $src/${crossSrcPrefix}_${buildPackage}/build_${buildPackage}
rm -rf *
echo "  Configuring gcc (stage 1) sources" >> $processFile
$src/${crossSrcPrefix}_${buildPackage}/${buildPackage}-${packageVersion}/configure \
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

echo "  Compiling $buildPackage (stage 1)" >> $processFile
PATH=$prefix/bin:$PATH make -j $JN all-gcc
if [ "$?" != "0" ] ; then exit; fi
echo "  Installing $buildPackage (stage 1)" >> $processFile
PATH=$prefix/bin:$PATH make -j $JN install-gcc
if [ "$?" != "0" ] ; then exit; fi

# ************************************************************* #
# Install header files (Linux and eglibc, needed for stage 2)
# ************************************************************* #
buildPackage="linux"
packageVersion=$linuxVersion

echo "Starting to install Linux headers" >> $processFile
cd $src/${crossSrcPrefix}_eglibc/${buildPackage}-${packageVersion}
mkdir -p $sysroot/usr
PATH=$prefix/bin:$PATH \
make headers_install CROSS_COMPILE=$target- \
INSTALL_HDR_PATH=$sysroot/usr ARCH=$linuxarch
if [ "$?" != "0" ] ; then exit; fi

buildPackage="eglibc"
packageVersion=$eglibcVersion

echo "Starting to install Eglibc headers" >> $processFile
cd $src/${crossSrcPrefix}_${buildPackage}/${buildPackage}-${packageVersion}
cp -r ports libc

# Configure headers
echo "  Configuring eglibc sources (headers only)" >> $processFile
cd $src/${crossSrcPrefix}_${buildPackage}/build_${buildPackage}

BUILD_CC=gcc
CC=$prefix/bin/$target-gcc \
AR=$prefix/bin/$target-ar \
RANLIB=$prefix/bin/$target-ranlib \
$src/${crossSrcPrefix}_${buildPackage}/${buildPackage}-${packageVersion}/libc/configure \
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

echo "  Installing eglibc headers" >> $processFile
make -j $JN install-headers \
install_root=$sysroot \
install-bootstrap-headers=yes
if [ "$?" != "0" ] ; then exit; fi

echo "Fixing some header installation by hand" >> $processFile
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
buildPackage="gcc"
packageVersion=$gccVersion

echo "Starting to build GCC stage 2" >> $processFile
cd $src/${crossSrcPrefix}_${buildPackage}/build_${buildPackage}
rm -rf *
echo "  Configuring gcc (stage 2) sources" >> $processFile
$src/${crossSrcPrefix}_${buildPackage}/${buildPackage}-${packageVersion}/configure \
--target=$target \
--prefix=$prefix \
--with-sysroot=$sysroot \
--disable-libssp \
--disable-libgomp \
--disable-libmudflap \
--enable-languages=c \
--with-pkgversion=$PKGVERSION
if [ "$?" != "0" ] ; then exit; fi

echo "  Compiling $buildPackage (stage 2)" >> $processFile
PATH=$prefix/bin:$PATH make -j $JN 
if [ "$?" != "0" ] ; then exit; fi
echo "  Installing $buildPackage (stage 2)" >> $processFile
PATH=$prefix/bin:$PATH make -j $JN install
if [ "$?" != "0" ] ; then exit; fi

# ************************************************************* #
# Build complete Eglibc with the new stage 2 GCC compiler
# ************************************************************* #
buildPackage="eglibc"
packageVersion=$eglibcVersion

echo "Starting to complete eglibc" >> $processFile
cd $src/${crossSrcPrefix}_${buildPackage}/build_${buildPackage}
rm -rf *
echo "  Configuring eglibc sources (complete)" >> $processFile
BUILD_CC=gcc \
CC=$prefix/bin/$target-gcc \
AR=$prefix/bin/$target-ar \
RANLIB=$prefix/bin/$target-ranlib \
$src/${crossSrcPrefix}_${buildPackage}/${buildPackage}-${packageVersion}/libc/configure \
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

echo "  Compiling $buildPackage (complete)" >> $processFile
PATH=$prefix/bin:$PATH make -j $JN
if [ "$?" != "0" ] ; then exit; fi
echo "  Installing $buildPackage (complete)" >> $processFile
PATH=$prefix/bin:$PATH make -j $JN install install_root=$sysroot
if [ "$?" != "0" ] ; then exit; fi

# ************************************************************* #
# Build GCC stage 3 (fully functional cross compiler)
# With the new stage 2 compiler, a GCC compiler compiled with 
# a c library so that it could generate it's own libraries like
# libgcc etc.
# ************************************************************* #
buildPackage="gcc"
packageVersion=$gccVersion

echo "Starting to build GCC stage 3" >> $processFile
cd $src/${crossSrcPrefix}_${buildPackage}/build_${buildPackage}
rm -rf *
echo "  Configuring gcc (stage 3) sources" >> $processFile
$src/${crossSrcPrefix}_${buildPackage}/${buildPackage}-${packageVersion}/configure \
--target=$target \
--prefix=$prefix \
--with-sysroot=$sysroot \
--disable-libssp \
--disable-libgomp \
--disable-libmudflap \
--enable-languages=c,c++ \
--with-pkgversion=$PKGVERSION
if [ "$?" != "0" ] ; then exit; fi

echo "  Compiling $buildPackage (stage 3)" >> $processFile
PATH=$prefix/bin:$PATH make -j $JN 
if [ "$?" != "0" ] ; then exit; fi
echo "  Installing $buildPackage (stage 3)" >> $processFile
PATH=$prefix/bin:$PATH make -j $JN install
if [ "$?" != "0" ] ; then exit; fi

# ************************************************************* #
# Complete the sysroot with some additional libraries not added
# by GCC (since GCC is not build to construct sysroot's)
# ************************************************************* #
echo "Completing the sysroot by installing some by hand" >> $processFile
cp -d $prefix/$target/lib/libgcc_s.so* $sysroot/lib
cp -d $prefix/$target/lib/libstdc++.so $sysroot/usr/lib

# ************************************************************* #
# Now a complete installtion of the toolchains is at $prefix 
# and a complete EGLIB installtion in $sysroot
#
# Creating a test c file, and compiling it with the new compiler,
# checking the ARCH and ABI with the help of the command readelf
# ************************************************************* #
echo "Creating a test.c file" >> $processFile
cd $src

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

echo "Compiling test.c with new compiler" >> $processFile
$prefix/bin/$target-gcc -o test test.c
if [ "$?" != "0" ] ; then exit; fi

echo "Checking the newly created executeble with readelf" >> $processFile
readelf -h test |  awk 'NR==1 || NR ==3 || (NR>3 && NR<10) || NR==14'
if [ "$?" != "0" ] ; then exit; fi

echo "  Checking if machine type is ARM..." >> $processFile
checkMachine=$(readelf -h test |  awk 'NR==9 {print $2}')
if [ "$checkMachine" == "ARM" ] 
then 
  echo "    Success, machine type of outputfile is ARM"'!' >> $processFile
  echo ""
  echo "Success, the compiler could compile the output file and it's format is ARM"'!'
else 
  echo "    Error, machine type does not seam to be \"ARM\", check the output of \"readelf -h test\" for more info" >> $processFile
  echo ""
  echo "Error, machine type does not seam to be \"ARM\", check the output of \"readelf -h test\" for more info"
fi

# ************************************************************* #
# Install toolchain
# ************************************************************* #
if [ "$installToolchain" == "n" ]; then
  echo -n "Do you want to install the script to install the toolchain? (y/n) "
  read installToolchain
  echo ""
fi

if [ "$installToolchain" == "y" ]; then
  sudo cp -r arm-linux-gnueabi-crossToolChain /opt/
  pushd . &> /dev/null
  cd /opt/arm-linux-gnueabi-crossToolChain/bin
  for file in * ; do
    sudo ln -s $PWD/$file /usr/bin/$file
  done
  popd &> /dev/null
fi

# ************************************************************* #
# Finish up script
# ************************************************************* #
if [ "$gccVersionAltered" == "y" ] ; then 
  echo ""
  echo "Your default Gcc version was changed by this script, if you want to set"
  echo "the gcc version back, execute this command:"
  echo "sudo mv /usr/bin/gcc.old /usr/bin/gcc"
fi

echo ""  >> $processFile
echo ""
echo "Program done, please the main window if the build was successfull" >> $processFile

