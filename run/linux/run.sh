#!/bin/sh
#Example of usage of PFEM
#Please take care of the lib location !

Test_Case="damBreakWithObstacle"
Problem="testIncomp"
Info="ref"
dim="2D"

export GMSHSDK=../../dependencies/gmsh-4.7.1-Linux64-sdk/
export OMP_NUM_THREADS=2
export PATH=${GMSHSDK}/bin:${GMSHSDK}/lib:"${PATH}"

./pfem ../../examples/"$dim"/"$Test_Case"/"$Problem".lua ../../examples/"$dim"/"$Test_Case"/geometry.msh

tar -czvf gmsh_Results.tar.gz ./*.msh 
tar -czvf txt_Results.tar.gz ./*.msh 
rm *.msh
rm *.txt

cd ../../
if [ ! -d "results" ]; then
    mkdir results
fi

cd results
if [ ! -d "$dim" ]; then
    mkdir "$dim"
fi

cd "$dim"
if [ ! -d "$Test_Case" ]; then
    mkdir "$Test_Case"
fi

cd "$Test_Case"
if [ ! -d "$Problem""_""$Info" ]; then
    mkdir "$Problem""_""$Info"
fi

cd ../../../build/bin

cp -avr gmsh_Results.tar.gz ../../results/"$dim"/"$Test_Case"/"$Problem_$Info"
cp -avr txt_Results.tar.gz ../../results/"$dim"/"$Test_Case"/"$Problem_$Info"

rm gmsh_Results.tar.gz
rm txt_Results.tar.gz
