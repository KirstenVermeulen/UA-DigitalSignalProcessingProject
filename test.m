path = "PP01/S1_MVC_delt_links.txt";

%file = BITalinoFileReader(a);
%val = jsondecode(fileread(path));

% open the file
fid=fopen(path, "r"); 
header = jsondecode(strrep(string(textscan(fid,'%s',1,'delimiter','\n', 'headerlines',1)),"# ", ""));
data = readmatrix(path, 'HeaderLines', 3, 'ExpectedNumVariables', 6);

%% d

