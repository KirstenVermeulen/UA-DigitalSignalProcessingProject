%% read raw data
path = "PP01/S1_MVC_delt_links.txt";
fid=fopen(path, "r");
header = jsondecode(strrep(string(textscan(fid,'%s',1,'delimiter','\n', 'headerlines',1)),"# ", ""));
data = readmatrix(path, 'HeaderLines', 3, 'ExpectedNumVariables', 7);
data(:,2) = []; % colom 2 zegt enkel dat de data input waarden zijn

samplingrate = header.x00_07_80_3B_46_63.samplingRate;

%% RMS window op raw data
windowSize = 10;
processed = zeros(size(data,1)-windowSize, size(data,2));
for k=size(data,2)
    processed(:,k) = RMSWindow(data(:,k), windowSize );
end


%% alle waarden omzetten naar mV
for r=1:size(data,1)
    for k=2:size(data,2)
        data(r,k) = EMG_mVoltage(data(r,k), 3, 1000, header.x00_07_80_3B_46_63.resolution(k-1));
    end
end

%% band pass
lowerbound = 100;
upperbound = 1000;
impulseResponse = 'iir';
steepnessLowerBound = 0.95;
steepnessUpperBound = 0.95;
for k=1:size(data,2)
    data(:, k) = bandpass(data(:, k), [lowerbound, upperbound], samplingrate, 'ImpulseResponse', impulseResponse,'Steepness', [steepnessLowerBound , steepnessUpperBound]);
end 
