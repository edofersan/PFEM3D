close all; clc;
% ----------------- The directory and name of set of resutls --------------
Test_Case       =   'damBreakKoshizuka';
Problem         =   'testIncomp';
Info            =   'ref';
dim             =   '2D';
Set_of_Results  =   strcat([dim,'/',Test_Case,'/',Problem,'_',Info]);

% ----------------- untar results ----------------------------------------- 
cd ../../results ; cd (Set_of_Results);
untar('gmsh_Results.tar.gz','gmsh_files');
untar('txt_Results.tar.gz','txt_files');

% ----------------- generate the .geo files and the .sh file --------------
cd ../../../../PostProc/Matlab_Scripts
SH_Script_to_Generate_Pictures(Set_of_Results);

% ----------------- save the data from the .txt files ---------------------
Read_Mass_and_save_Mat(Set_of_Results);