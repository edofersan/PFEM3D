#!/bin/sh
#Example of usage of PFEM
#Please take care of the lib location !

export GMSHSDK=../../dependencies/gmsh-4.7.1-Linux64-sdk/

export OMP_NUM_THREADS=2

export PATH=${GMSHSDK}/bin:${GMSHSDK}/lib:"${PATH}"

./pfem ../../examples/2D/damBreakWithObstacle/testComp.lua ../../examples/2D/damBreakWithObstacle/geometry.msh
