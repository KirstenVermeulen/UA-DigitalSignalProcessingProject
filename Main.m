%% --- Load Raw Data --- %%
path = "PP01/S1_MVC_delt_links.txt";

header = jsondecode(strrep(string(textscan(fopen(path, "r"),'%s',1,'delimiter','\n', 'headerlines',1)),"# ", ""));
    
X = readmatrix(path, 'HeaderLines', 3, 'ExpectedNumVariables', 7);
X(:,1:2) = [];

%% --- Scale to mV --- %%
for r=1:size(X,1)
    for k=2:size(X,2)
        X(r,k) = ToMiliVoltage(X(r,k), 3, 1000, header.x00_07_80_3B_46_63.resolution(k-1));
    end
end

%% --- Properties --- %%
Fs = header.x00_07_80_3B_46_63.samplingRate;      % Sampling frequency (Hertz)
T = 1/Fs;                                         % Sampling period (Seconds/Sample)
L = size(X, 1) / Fs;                              % Length of the signal (Seconds)
t = linspace(0,L,size(X,1));                      % Time Axis (Vector)

%% --- Plot 1 --- %%

plot(t,X(:,2))
title('Time-domain signal')
xlabel('t (seconds)')
ylabel('X(t)')

%% --- FFT Analyse --- %%
Y = fft(X);                    % Fast Fourier Transform

P1 = 

for i = 1:size(Y,2)
    P2 = abs(Y(:,i)/L);      % two-sided spectrum
    P1 = P2(1:L/2+1);   % single-sided spectrum
    P1(2:end-1) = 2*P1(2:end-1);
end

%% --- Plot 2 --- %
f = Fs * (0:(L/2)) / L;

plot(f,P1);
title('Single-Sided Amplitude Spectrum of X(t)');
xlabel('f (Hz)');
ylabel('|P1(f)|');

%%
f = samplingRate * (0:(signalLength/2))/signalLength;       % Frequency axis

PlotData(f, singleSided, 1);

%%%%%%%% https://nl.mathworks.com/help/matlab/ref/fft.html %%%%%%%%

N = size(t,1);                                              % Number of samples

%% --- Outlier Removal --- %%
A = [57 59 60 100 59 58 57 58 300 61 62 60 62 58 57];
disp(outLierRemoval(A,2));

%% Processing Track A %%
Y = TrackA(20, 120, 'iir', 0.95, 0.95);

%% --- Processing Track B --- %%
y = TrackB(20, Y);

%% Export Data %%
ExportData(processed, 1)

%% Normalise
norm_data = zeros(size(processed,1), size(processed,2));
for k=1:size(norm_data,2)
    norm_data(:, k) = Normalise(processed(:, k));
end

%% Export Data %%
ExportData(norm_data, 2)

%% --- Frequency spectrum --- %%
tiledlayout(5,1)

for i=2:1:6
    ax = nexttile;
    plot(ax, f, abs(norm_data(:,i))/N);
    %plot(ax, f, abs(processed)/N);          % Sine Wave
    title("Sensor " + i)
end
