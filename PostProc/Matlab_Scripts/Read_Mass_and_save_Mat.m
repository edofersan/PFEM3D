function [] = Read_Mass_and_save_Mat(Set_of_Results)

%% RESULTS TO BE PROCESSED
cd ../../results/
cd (Set_of_Results)
cd txt_files

%% reading the mass -------------------------------------------------------
fid          = fopen('mass.txt') ; % reading the file with the mass of the model  
tline        = fgetl(fid)        ; % getting the lines of the file
Mass         = zeros(10000,1)    ; % preallocating arrays.
TimeMass     = zeros(10000,1)    ; % preallocating arrays.
k            = 0;
while ischar(tline)
    tline    = fgetl(fid);
    if length(tline)>5
        k             = k+1;
        TimeMass(k,1)  = str2double(tline(1:8));
        Mass(k,1)  = str2double(tline(10:end)); 
    end
end
Mass         = Mass(1:k,1)             ; % reducing the size of the array.
TimeMass     = TimeMass(1:k,1)         ; % reducing the size of the array.
RelativeMass = (Mass-Mass(1,1))/Mass(1,1)*100 ;
fclose(fid);

%% reading alpha ----------------------------------------------------------
fid          = fopen('alpha.txt') ; % reading the file with the mass of the model  
tline        = fgetl(fid)        ; % getting the lines of the file
Alpha        = zeros(10000,1)    ; % preallocating arrays.
TimeAlpha    = zeros(10000,1)    ; % preallocating arrays.
k            = 0;
while ischar(tline)
    tline    = fgetl(fid);
    if length(tline)>5
        k             = k+1;
        TimeAlpha(k,1)  = str2double(tline(1:8));
        Alpha(k,1)  = str2double(tline(10:end)); 
    end
end
Alpha        = Alpha(1:k,1)        ; % reducing the size of the array.
TimeAlpha    = TimeAlpha(1:k,1)    ; % reducing the size of the array.
fclose(fid);
fclose all;

%% Saving info ------------------------------------------------------------ 
figure(1); 
plot(TimeMass,RelativeMass,'b','linewidth',1.5); hold on;
plot([0 TimeMass(end,1)],[0 0],'--k','linewidth',0.5); hold off;
ylabel('$\mathrm{M} / \mathrm{M}_\mathrm{initial} [\%]$','interpreter','latex','fontsize',15);
xlabel('$\mathrm{time}$','interpreter','latex','fontsize',15);
axis([0 TimeMass(end,1) min(RelativeMass(:)) max(RelativeMass(:))]);
print('figure_mass','-dpng','-r200');

figure(2); 
plot(TimeAlpha,Alpha,'b','linewidth',1.5); hold on;
plot([0 TimeAlpha(end,1)],[1.2 1.2],'--k','linewidth',0.5); hold off;
ylabel('$\mathrm{M} / \mathrm{M}_\mathrm{initial} [\%]$','interpreter','latex','fontsize',15);
xlabel('$\mathrm{time}$','interpreter','latex','fontsize',15);
axis([0 TimeAlpha(end,1) 0.9 1.5]);
print('figure_alpha','-dpng','-r200');

DATA = {TimeMass,Mass,TimeAlpha,Alpha};
save('DATA','DATA');

cd ../../../../../PostProc/Matlab_Scripts
end