function [] = Third_gif_Creator()
clear all; close all;

%% RESULTS TO BE PROCESSED
Set_of_Results = 'damBreakKoshizuka/Incomp';
cd ../../results/
cd (Set_of_Results)

%% 
load('DATA.mat');
tMass    = DATA{1};
Mass     = DATA{2};
dTData   = 0.01;

%% The gif ====================================================
ResultsPictures = dir('*.png');
GifName         = 'GIF_results.gif';
delay           = 0.01;             % Delay between frames (s)
FilesNames      = cell(size(ResultsPictures,1),1);

% sorting the time steps: --------------------
time_sort = zeros(size(ResultsPictures,1),1);
k = 0;
for i = 1:size(ResultsPictures,1)
    NAME = ResultsPictures(i).name;
    if strcmp('r_',NAME(1:2))
        k = k+1;
        time_sort(k) = round(str2double(NAME(3:end-4))*1000)/1000;
        FilesNames{k} = NAME;
    end
end
time_sort = time_sort(1:k);
FilesNames = FilesNames(1:k);
[~,ind] = sort(time_sort);
FilesNames = FilesNames(ind);
time_sort  = time_sort(ind);
% --------------------------------------------
for i = 1:size(FilesNames,1)
    NAME = FilesNames{i};
    [A, ~]   = imread(NAME);
    [X, map] = rgb2ind(A, 256);

    % additional information on the figure ----------------------------
    time   = time_sort(i);
    [~,j]  = min(abs(time - tMass));
    M      = round(Mass(j)./Mass(1,1)*100);
    X = AddTextToImage(X,strcat([' t  :   ',num2str(time,'%1.4f')]),[100 200],[0 0 0],'Arial',15);
    X = AddTextToImage(X,strcat(['M :   ',num2str(M),' %']),[50 200],[0 0 0],'Arial',15);
    %------------------------------------------------------------------

    if i == 1
        imwrite(X, map, GifName, 'gif', 'LoopCount', inf, 'DelayTime', delay)
    else
        imwrite(X, map, GifName, 'gif', 'WriteMode', 'append', 'DelayTime', delay)
    end

    % report progress
    fprintf(1,'\n time step : %1.4f',time);
end

fprintf(1,'\n');

cd ../../../PostProc/Matlab_Scripts

%% =======================================================================
% ========================================================================
function Image = AddTextToImage(Image,String,Position,Color,Font,FontSize)
% Image = AddTextToImage(Image,String,Position,Color,Font,FontSize)
%
%   Overlays a rasterized version of the text in String on top of the given
%   Image. The top-left coordinate in pixels is set by Position. Text
%   colour is specified in the variable Color. Font may either be a
%   structure output by BitmapFont or a string specifying a font name.  If
%   the latter, BitmapFont will be called for this font with its size in
%   pixels as specified by FontSize.
%
%   Images may be 1- or 3-channel. Images of class double should have range
%   [0 1] and images of class double should have range [0 255].
%
%   Color specifications should be in the range [0 1] for all RGB and
%   grayscale images regardless of their class.
%
% Daniel Warren
% Particle Therapy Cancer Research Institute
% University of Oxford
if ~exist('Image','var') || isempty(Image)
    % Sample image
    Image = linspace(0,1,500)'*(linspace(0,1,500));
    Image = cat(3,Image,rot90(Image),rot90(Image,2));
end
if ~exist('String','var')
    String = 'No string specified.';
end
if ~exist('Position','var')
    Position = [1 1];
end
if ~exist('Color','var')
    Color = [1 1 0];
end
if ~exist('Font','var')
    Font = 'Arial';
end
if ~exist('FontSize','var')
    FontSize = 32;
end
% uint8 images go from 0 to 255, whereas double ones go from 0 to 1
if isa(Image, 'uint8')
    ScaleFactor = 255;
else
    ScaleFactor = 1;
end
% monochrome images need monochrome text, colour images need colour text
if ndims(Image) == 2 %#ok<ISMAT>
    Color = mean(Color(:));
end
if ndims(Image) == 3 && numel(Color) == 1
    Color = [Color Color Color];
end
% remove overflowing text and/or pad mask to image size
TextMask = RasterizeText(String,Font,FontSize);
% only try adding text if some of it will actually overlay the image
if Position(1) < size(Image,1) && Position(2) < size(Image,2) ...
        && Position(1) + size(TextMask,1) > 0 && Position(2) + size(TextMask,2) > 0
    if Position(1) + size(TextMask,1) > size(Image,1)
        TextMask = TextMask(1:(size(Image,1)-Position(1)),:);
    end
    if Position(2) + size(TextMask,2) > size(Image,2)
        TextMask = TextMask(:,1:(size(Image,2)-Position(2)));
    end
    if any(size(TextMask) ~= [size(Image,1) size(Image,2)]-Position) % save the bottom-right pixel if it's already in the mask
        TextMask(size(Image,1)-Position(1),size(Image,2)-Position(2)) = false;
    end
    
    if Position(1) > 0
        TextMask = cat(1,false(Position(1),size(TextMask,2)),TextMask);
    else
        TextMask = TextMask(1-Position(1):end,:);
    end
    
    if Position(2) > 0
		TextMask = cat(2,false(size(TextMask,1),Position(2)),TextMask);
    else
        TextMask = TextMask(:,1-Position(2):end);
    end
    
    Color = ScaleFactor*Color;
    for i=1:length(Color)
        tmp = Image(:,:,i); % to use logical indexing;
        tmp(TextMask) = Color(i);
        Image(:,:,i) = tmp;
    end
end

%% ========================================================================
function Font = BitmapFont(Name,Size,Characters,Padding)
% Font = BitmapFont(Name,Size,Characters,Padding)
%
%   Outputs a structure with rasterised binary representations of the
%   non-whitespace characters specified in string Characters. Font used is
%   specified by Name and its size in pixels by Size. Padding is the
%   padding applied after each character in pixels.
%
%   All arguments optional. Default is Courier New at 32 px with 2% kerning
%   with the characters abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXY
%   Z1234567890''м!"Ј$%&/()=?^и+тащ,.-<\|;:_>*@#[]{}
%
%   Variable width fonts will work, but fixed width fonts are likely to
%   have fewer kerning issues. Works via screenshots and pops up a figure
%   window, which is unideal and may fail on headless systems: a workaround
%   would be to save pre-generated font files on a desktop machine.
%
%   Will produce better results if font smoothing (ClearType, etc.) is
%   turned off.
%
% Daniel Warren
% Particle Therapy Cancer Research Institute
% University of Oxford
if ~exist('Name','var')
    Name = 'Courier New';
end
if ~exist('Size','var')
    Size = 32;
end
if ~exist('Characters','var')
    Characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890''м!"Ј$%&/()=?^и+тащ,.-<\|;:_>*@#[]{}';
end
if ~exist('Padding','var')
    Padding = 0.02*Size;
end
Size = ceil(Size);
Padding = ceil(Padding);
Bitmaps = cell(1,length(Characters));
% Use a single figure and axis for maximum speed. White background.
fighandle = figure('Position',[50 50 150+Size 150+Size],'Units','pixels','Color',[1 1 1]);
axes('Position',[0 0 1 1],'Units','Normalized');
axis off;
for i = 1:length(Characters)
    % Place each character in the middle of the figure
    texthandle = text(0.5,1,Characters(i),'Units','Normalized','FontName',Name,'FontUnits','pixels','FontSize',Size,'HorizontalAlignment','Center','VerticalAlignment','Top','Interpreter','None','Color',[0 0 0]);
	drawnow;
    % Take a snapshot
    Bitmap = getframe(gcf);
    delete(texthandle);
    % Average RGB to minimise effect of ClearType etc.
    Bitmap = mean(Bitmap.cdata,3);
    % Crop height as appropriate (in MATLAB images, first dimension is
    % height). Some characters will be larger than Size (eg. y and g) -
    % allow for this.
    Bitmap = Bitmap(1:find(mean(Bitmap,2)~=255,1,'last'),:);
    % Crop width to remove all white space
    Bitmap = Bitmap(:,find(mean(Bitmap,1)~=255,1,'first'):find(mean(Bitmap,1)~=255,1,'last'));
    % Pad with kerning value
	Bitmap(:,end:(end+Padding)) = 255;
    % Invert and store in binary format
    Bitmaps{i} = false(size(Bitmap));
    Bitmaps{i}(Bitmap < 160) = true; % This threshold could be changed
end
close(fighandle);
Font.Name = Name;
Font.Size = Size;
Font.Characters = Characters;
Font.Bitmaps = Bitmaps;

%% =======================================================================
function Image = RasterizeText(String,Font,FontSize)
% Image = RasterizeText(String,Font,FontSize)
%
%   Creates a monochrome image with a rasterized version of the text
%   specified in String with font specified by Font. Font can either be a
%   structure produced by BitmapFont or a string containing a font name. If
%   the latter, BitmapFont will be called for this font with its size in
%   pixels as specified by FontSize.
%
%   No line wrapping occurs, but the function can process the newline
%   character. Output size is unpredictable without first analysing the
%   font. Best results are likely with fixed width fonts.
%
% Daniel Warren
% Particle Therapy Cancer Research Institute
% University of Oxford
if ~exist('String','var')
    String = 'No string specified.';
end
if ~exist('Font','var')
    Font = 'Arial';
end
if ~exist('FontSize','var')
    FontSize = 32;
end
% Preprocess text. Only allowing two types of whitespace: \n and space
% Replace tab with four spaces. Remove all other ASCII control characters.
String = strrep(String,sprintf('\t'),sprintf('    '));
String = strrep(String,sprintf('\r\n'),sprintf('\n'));
ControlChars = sprintf('%c',[0:9 11:31 127]);
for i = 1:length(ControlChars)
    String(String==ControlChars(i)) = [];
end
% Create a rasterized font
Characters = unique(String(String ~= ' ' & String ~= sprintf('\n')));
if ~isstruct(Font)
    Font = BitmapFont(Font,FontSize,Characters);
elseif ~all(ismember(Characters,Font.Characters))
    error('The font provided is missing some of the necessary characters.');
end
Image = logical([]); % This array will grow as the output is built up
l = 0; % Line number - starts at 0
x = 0; % X location - starts a 0, but 0 will never be written to
SpaceSize = ceil(0.33*FontSize);
for i = 1:length(String)
    switch String(i)
        case ' '
            % Avoid overwriting parts of characters below the baseline on
            % the line above by only assigning one element.
            Image(l*Font.Size + Font.Size, x + SpaceSize) = false;
            x = x+SpaceSize;
        case sprintf('\n')
            l = l+1;
            % Unnecessary to grow array, but could help speed. Again, only
            % assign one element.
            Image(l*Font.Size + Font.Size, size(Image,2)) = false;
            x = 0;
        otherwise
            index = Font.Characters==String(i);
            CharSize = size(Font.Bitmaps{index});
            % Grow array so can perform boolean OR, which will avoid
            % background of character overwriting characters extending
            % below the baseline on the line above.
            Image(l*Font.Size + CharSize(1), x + CharSize(2)) = false;
            Image(l*Font.Size + (1:CharSize(1)), x + (1:CharSize(2))) = ...
                Image(l*Font.Size + (1:CharSize(1)), x + (1:CharSize(2))) | Font.Bitmaps{index};
            x = x+CharSize(2);
    end
end
