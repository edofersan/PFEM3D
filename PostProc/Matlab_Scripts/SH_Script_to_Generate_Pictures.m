function [] = SH_Script_to_Generate_Pictures(Set_of_Results)
cd ../../results/
cd (Set_of_Results)
cd gmsh_files

%% draw element lines?
ELines = 'no';
MaxValuePlot = 7;
MinValuePlot = 0;

%% retrieving the test_case for positioning the screeshot 
j = strfind(Set_of_Results,'/');
Test_case = Set_of_Results(j(1)+1:j(2)-1);

%% Reading the name of the .msh files.
GmshFiles  = dir('*.msh')              ; % finding all .msh files
Nfiles     = size(GmshFiles,1)         ; % getting the ammount of files
FileNameSH = 'GMSH_ScreeShots.sh'      ; % the .sh file to be generated
fileSHID   = fopen(FileNameSH,'w')     ; % id to the .sh file

for i=1:Nfiles
    % the name of the .geo file to be created: Post_gmsh_'FileName'.geo
    FileName = strcat(['Post_gmsh_',GmshFiles(i).name(1:end-3),'geo']);
    fileID   = fopen(FileName,'w');
    
    % the gmsh command lines to read the .msh file, 
    %                        to set the window size
    %                        to set the field to be plotted
    %                        to set the range of the field
    %                        to place properly the model
    %                        to scale the model
        
    fprintf(fileID,'\n Merge "%s";',GmshFiles(i).name);
    fprintf(fileID,'\n General.GraphicsWidth = 820 ;');
    fprintf(fileID,'\n General.GraphicsHeight = 640 ;');
    fprintf(fileID,'\n View[0].Visible = 0;');
    fprintf(fileID,'\n View[1].Visible = 1;');
    fprintf(fileID,'\n View[1].RangeType = 2;');
    fprintf(fileID,'\n View[1].CustomAbscissaMax = %1.2f;',MaxValuePlot);
    fprintf(fileID,'\n View[1].CustomAbscissaMin = %1.2f;',MinValuePlot');
    fprintf(fileID,'\n View[1].CustomMax = %1.2f;',MaxValuePlot);
    fprintf(fileID,'\n View[1].CustomMin = %1.2f;',MinValuePlot');
    
    if strcmp(ELines,'no')
        fprintf(fileID,'\n Mesh.SurfaceEdges = 0;');   % comment to plot element lines
    end
    
    switch Test_case
        case 'damBreakKoshizuka'
            fprintf(fileID,'\n General.TranslationX = 0.3;');
            fprintf(fileID,'\n General.TranslationY = -0.15;');
            fprintf(fileID,'\n General.ManipulatorPositionY = 0;');
            fprintf(fileID,'\n General.ScaleX = 4;');
            fprintf(fileID,'\n General.ScaleY = 4;');
        case 'damBreakWithObstacle'
            fprintf(fileID,'\n General.TranslationX = -0.3;');
            fprintf(fileID,'\n General.TranslationY = -0.2;');
            fprintf(fileID,'\n General.ManipulatorPositionY = 0;');
            fprintf(fileID,'\n General.ScaleX = 3.5;');
            fprintf(fileID,'\n General.ScaleY = 3.5;');
        otherwise
            error('no Test_case known');
    end
    
    
    % finding the time step to place it in the name
    % of the saved figure.
    dash = findstr('_',GmshFiles(i).name);
    ext  = findstr('.msh',GmshFiles(i).name);
    time = GmshFiles(i).name(dash+1:ext-1);
    
    % the name of the figure to be saved by gmsh.
    fprintf(fileID,'\n Print Sprintf("r_%s.png");',time);
    fprintf(fileID,'\n Exit;');
    fclose(fileID);
    
    % commands to be writen in the .sh file 
    % in order to execute all the .geo files
    fprintf(fileSHID,'\n gmsh %s',FileName);
    fprintf(fileSHID,'\n rm %s',FileName);
    fprintf(fileSHID,'\n rm %s',GmshFiles(i).name);   
end

fclose all;

cd ../../../../../PostProc/Matlab_Scripts

end

%% if you use WSL, remember to:
%{ 
export DISPLAY="`grep nameserver /etc/resolv.conf | sed 's/nameserver //'`:0"
echo $DISPLAY
export DISPLAY=$(ip route get 0.0.0.0 | awk '{print $NF}'):0
export LIBGL_ALWAYS_INDIRECT=1
export LIBGL_ALWAYS_INDIRECT
%}

