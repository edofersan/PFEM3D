close all; clc;
% ----------------- The directory and name of set of resutls --------------
Test_Case       =   'dropFallInFluid';
Problem         =   'testIncomp';
Info            =   'additional_info';
dim             =   '2D';
Set_of_Results  =   strcat([dim,'/',Test_Case,'/',Problem,'_',Info]);

% ----------------- untar results ----------------------------------------- 
cd ../../results ; cd (Set_of_Results);
untar('gmsh_Results.tar.gz','gmsh_files');
untar('txt_Results.tar.gz','txt_files');

% ----------------- generate the .geo files and the .sh file --------------
Element_Lines   = 'no' ;                  % Draw the element lines?
spheres         = 'yes';                  % nodes as spheres?
spheres_Size    =  3   ;                  % size of node points
MaxValuePlot    =  7   ;                  % maximum value of ke 
MinValuePlot    =  0   ;                  % minimum value of ke

cd ../../../../PostProc/Matlab_Scripts
SH_Script_to_Generate_Pictures(Set_of_Results,Element_Lines,...
                           spheres,spheres_Size,MaxValuePlot,MinValuePlot);

% ----------------- save the data from the .txt files ---------------------
Read_Mass_and_save_Mat(Set_of_Results);


%{ 
#if you use WSL, to run GMSH_ScreeShots.sh remember to:
 
export DISPLAY="`grep nameserver /etc/resolv.conf | sed 's/nameserver //'`:0"
echo $DISPLAY
export DISPLAY=$(ip route get 0.0.0.0 | awk '{print $NF}'):0
export LIBGL_ALWAYS_INDIRECT=1
export LIBGL_ALWAYS_INDIRECT
%}