close all; clc;
% ----------------- The directory and name of set of resutls --------------
Test_Case       =   'damBreakKoshizuka';
Problem         =   'testIncomp';
Info            =   'ref';
dim             =   '2D';
Set_of_Results  =   strcat([dim,'/',Test_Case,'/',Problem,'_',Info]);

gif_Creator(Set_of_Results)