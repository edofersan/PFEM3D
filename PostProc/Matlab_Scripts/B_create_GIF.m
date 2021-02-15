close all; clc;
% ----------------- The directory and name of set of resutls --------------
GifName         =   'GIF_results.gif'       ; % name of the generated gif
timeMax         =          20               ; % maximum time step to include
delay           =          0.1              ; % time delay between frames (s)
Test_Case       =   'dropFallInFluid'       ;
Problem         =   'testIncomp'            ;
Info            =   'additional_info'       ;
dim             =   '2D'                    ;
Set_of_Results  =   strcat([dim,'/',Test_Case,'/',Problem,'_',Info]);

gif_Creator(Set_of_Results,GifName,timeMax,delay)