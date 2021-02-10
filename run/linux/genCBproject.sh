#!/bin/sh
#Do not forget to install libgfortran3  on your system!
#You will also need need lua 5.3 (i.e. liblua5.3-dev), CGAL 4.14 (i.e. libcgal-dev), eigen 3 (i.e. libeigen3-dev), nlohmann json (i.e. nlohmann-json3-dev), swig 4.0 (i.e. swig4.0) and python 3 (i.e. libpython3-dev) (at least)
#This project needs a C++17 compliant compiler

cd ../../
if [ ! -d "dependencies" ]; then
    mkdir dependencies
fi

cd dependencies/

if [ ! -d "sol" ]; then
  mkdir sol
  cd sol
  wget https://github.com/ThePhD/sol2/releases/download/v3.2.2/sol.hpp
  wget https://github.com/ThePhD/sol2/releases/download/v3.2.2/forward.hpp
  wget https://github.com/ThePhD/sol2/releases/download/v3.2.2/config.hpp
  cd ../
fi

if [ ! -d "gmsh-4.7.1-Linux64-sdk" ]; then
  wget http://gmsh.info/bin/Linux/gmsh-4.7.1-Linux64-sdk.tgz
  tar -xf gmsh-4.7.1-Linux64-sdk.tgz 
  rm -rf gmsh-4.7.1-Linux64-sdk.tgz 
fi

export GMSHSDK=${PWD}/gmsh-4.7.1-Linux64-sdk/
export EIGENSDK=/usr/include/eigen3/
export SOLSDK=${PWD}/

export PATH=${GMSHSDK}/bin:${GMSHSDK}/lib:"${PATH}"
export INCLUDE=${GMSHSDK}/include:"${INCLUDE}"
export INCLUDE=${EIGENSDK}:"${INCLUDE}"
export INCLUDE=${SOLSDK}:"${INCLUDE}"
export LIB=${GMSHSDK}/lib:"${LIB}"
export PYTHONPATH=${GMSHSDK}/lib:"${PYTHONPATH}"
export DYLD_LIBRARY_PATH=${GMSHSDK}/lib:"${DYLD_LIBRARY_PATH}"

cd ../

rm -rf build
mkdir build
cd build

cmake ../ -DCMAKE_BUILD_TYPE=Debug  -G "CodeBlocks - Unix Makefiles"

cp ../run/linux/run.sh bin/

cd bin
mkdir examples
cd ../

cd ../

cd examples

find . -name "*.msh" | cpio -pdm ../build/bin/examples 
