%% --- Load Raw Data --- %%

% --- File IO --- %
path = "PP01/S1_MVC_delt_links.txt";
header = jsondecode(strrep(string(textscan(fopen(path, "r"),'%s',1,'delimiter','\n', 'headerlines',1)),"# ", ""));

data = readmatrix(path, 'HeaderLines', 3, 'ExpectedNumVariables', 7);
data(:,2) = [];

samplingRate = header.x00_07_80_3B_46_63.samplingRate;      % Samples/Second (Hertz)

% --- Scale to mV --- %
for r=1:size(data,1)
    for k=2:size(data,2)
        data(r,k) = EMG_mVoltage(data(r,k), 3, 1000, header.x00_07_80_3B_46_63.resolution(k-1));
    end
end

% --- Sine wave (testing) --- %
%Fc = 12;                                           % hertz
%x = cos(2*pi*Fc*t) + cos(2*pi*100*t);

%% --- FFT Analyse --- %%

fourierTransform = fft(data);
%fourierTransform = fft(x);                                 % Sine Wave
%fourierData = fourierTransform(size(fourierTransform, 1)/2:size(fourierTransform, 1), :);
%f = f(size(f, 1)/2:size(f, 1), :);

%% --- Outlier Removal --- %%
A = [57 59 60 100 59 58 57 58 300 61 62 60 62 58 57];
filloutliers(input,'center','mean','ThresholdFactor', 3); %% laatste paramter vul je jouw std in

%% Processing Track A %%

% --- Band-pass --- %
% lowerbound = 20;
% upperbound = 120;
% impulseResponse = 'iir';
% steepnessLowerBound = 0.95;
% steepnessUpperBound = 0.95;
% 
% for k=1:size(fourierTransform,2)
%     fourierTransform(:, k) = bandpass(fourierTransform(:, k), [lowerbound, upperbound], samplingRate, 'ImpulseResponse', impulseResponse,'Steepness', [steepnessLowerBound , steepnessUpperBound]);
% end 

%% --- Processing Track B --- %%
windowSize = 20;
processed = zeros(size(fourierTransform,1), size(fourierTransform,2));

for k=1:size(fourierTransform,2)
    processed(:,k) = RMSWindow(fourierTransform(:,k), windowSize );
end

%% Export Data %%
ExportData(processed, 1)

%% Normalise
norm_data = zeros(size(processed,1), size(processed,2));
for k=1:size(norm_data,2)
    norm_data(:, k) = Normalise(processed(:, k));
end

%% Export Data %%
ExportData(norm_data, 2)

%% --- Time spectrum --- %%

% --- Specifications --- %

dt = 1/samplingRate;                                        % Seconds/Sample

stopTime = size(processed, 1)/samplingRate;                      % Seconds
%stopTime = 1;                                              % Sine Wave

t = (0:dt:stopTime-dt)';                                    % Time Axis
N = size(t,1);                                              % Number of samples

% --- Visualisation --- %
tiledlayout(5,1)

for i=1:1:5
    ax = nexttile;
    plot(ax, data(:,1), data(:,(i+1)));
    title("Sensor " + i);
end

%% --- Frequency spectrum --- %%

% --- Specifications --- %
df = samplingRate/N;                                        % Hertz
f = (-samplingRate/2:df:samplingRate/2-df)';                % Hertz

% --- Visualisation --- %
tiledlayout(5,1)

for i=2:1:6
    ax = nexttile;
    plot(ax, f, abs(processed(:,i))/N);
    %plot(ax, f, abs(processed)/N);          % Sine Wave
    title("Sensor " + i)
end
