clear all; close all;

%% RESULTS TO BE PROCESSED
Set_of_Results = 'damBreakKoshizuka/Incomp';
cd ../../results/
cd (Set_of_Results)

%% 
fid          = fopen('mass.txt') ; % reading the file with the mass of the model  
tline        = fgetl(fid)        ; % getting the lines of the file
MassTot      = zeros(10000,1)    ; % preallocating arrays.
TimeTot      = zeros(10000,1)    ; % preallocating arrays.
k            = 0;
while ischar(tline)
    tline    = fgetl(fid);
    if length(tline)>5
        k             = k+1;
        TimeTot(k,1)  = str2double(tline(1:8));
        MassTot(k,1)  = str2double(tline(10:end)); 
    end
end
MassTot = MassTot(1:k,1)        ; % reducing the size of the array.
TimeTot = TimeTot(1:k,1)        ; % reducing the size of the array.
RelativeMass = (MassTot-MassTot(1,1))/MassTot(1,1)*100 ;

figure(1); 
plot(TimeTot,RelativeMass,'b','linewidth',1.5); hold on;
plot([0 TimeTot(end,1)],[0 0],'--k','linewidth',0.5); hold off;
ylabel('$\mathrm{M} / \mathrm{M}_\mathrm{initial} [\%]$','interpreter','latex','fontsize',15);
xlabel('$\mathrm{time}$','interpreter','latex','fontsize',15);
axis([0 TimeTot(end,1) min(RelativeMass(:)) max(RelativeMass(:))]);
fclose(fid);
fclose all;

DATA = {TimeTot,MassTot};
save('DATA','DATA');
print('figure_1','-dpng','-r200');

cd ../../../PostProc/Matlab_Scripts