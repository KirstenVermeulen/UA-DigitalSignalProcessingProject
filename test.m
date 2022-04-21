%% read raw data
path = "PP01/S1_MVC_delt_links.txt";
fid=fopen(path, "r");
header = jsondecode(strrep(string(textscan(fid,'%s',1,'delimiter','\n', 'headerlines',1)),"# ", ""));
data = readmatrix(path, 'HeaderLines', 3, 'ExpectedNumVariables', 6);
data(:,2) = []; % colom 2 zegt enkel dat de data input waarden zijn

samplingrate = header.x00_07_80_3B_46_63.samplingRate;


%% alle waarden omzetten naar mV
for r=1:size(data,1)
    for k=1:size(data,2)
        data(r,k) = EMG_mVoltage(data(r,k), 3, 1000, header.x00_07_80_3B_46_63.resolution(k));
    end
end

%% outlier removal
A = [57 59 60 100 59 58 57 58 300 61 62 60 62 58 57];
disp(outLierRemoval(A,2));
