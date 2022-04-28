%% File IO %%
path = "PP01/S1_MVC_delt_links.txt";

fid=fopen(path, "r");
header = jsondecode(strrep(string(textscan(fid,'%s',1,'delimiter','\n', 'headerlines',1)),"# ", ""));

data = readmatrix(path, 'HeaderLines', 3, 'ExpectedNumVariables', 7);

data(:,2) = [];

%% RMS window op raw data
windowSize = 10;
processed = zeros(size(data,1)-windowSize, size(data,2));
for k=size(data,2)
    processed(:,k) = RMSWindow(data(:,k), windowSize );
end

%% Scale to mV %%
for r=1:size(data,1)
    for k=2:size(data,2)
        data(r,k) = EMG_mVoltage(data(r,k), 3, 1000, header.x00_07_80_3B_46_63.resolution(k-1));
    end
end
%% outlier removal
A = [57 59 60 100 59 58 57 58 300 61 62 60 62 58 57];
disp(outLierRemoval(A,2));


%% Specifications %%

% Time %
samplingRate = header.x00_07_80_3B_46_63.samplingRate;      % Samples/Second
dt = 1/samplingRate;                                        % Seconds/Sample
%stopTime = size(data, 1)/samplingRate;                      % Seconds
stopTime = 1;
t = (0:dt:stopTime-dt)';
N = size(t,1);

% Frequency %
df = samplingRate/N;                                        % Hertz
f = (-samplingRate/2:df:samplingRate/2-df)';                % Hertz


%% Sine wave %%
Fc = 12;                       % hertz
x = cos(2*pi*Fc*t) + cos(2*pi*100*t);

%% Fast Fourier Transform %%

%fourierTransform = fft(data);
%fourierShift = fftshift(fourierTransform);

fourierTransform = fft(x);
fourierShift = fftshift(fourierTransform);
fourierData = fourierShift(size(fourierShift, 1)/2:size(fourierShift, 1), :);
f = f(size(f, 1)/2:size(f, 1), :);


%% band pass
lowerbound = 20;
upperbound = 120;
impulseResponse = 'iir';
steepnessLowerBound = 0.95;
steepnessUpperBound = 0.95;
for k=1:size(fourierData,2)
    fourierData(:, k) = bandpass(fourierData(:, k), [lowerbound, upperbound], samplingRate, 'ImpulseResponse', impulseResponse,'Steepness', [steepnessLowerBound , steepnessUpperBound]);
end 

%% Time spectrum %%
tiledlayout(5,1)

for i=1:1:5
    ax = nexttile;
    plot(ax, data(:,1), data(:,(i + 1)));
    title("Sensor " + i);
end
%% Frequency spectrum %%
tiledlayout(5,1)

for i=1:1:5
    ax = nexttile;
    %plot(ax, f, abs(fourierShift(:,1))/N);
    plot(ax, f, abs(fourierShift)/N);
    title("Sensor " + i)
end

%% Normalise
norm_data = zeros(size(fourierData,1), size(fourierData,2));
for k=1:size(norm_data,2)
    norm_data(:, k) = Normalise(fourierData(:, k));
end

