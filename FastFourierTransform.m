function [Y, P2, P1] = FastFourierTransform(X, signalLength)
    Y = fft(X);                    % Fast Fourier Transform

    P2 = abs(Y/signalLength);      % two-sided spectrum
    P1 = P2(1:signalLength/2+1);   % single-sided spectrum
    P1(2:end-1) = 2*P1(2:end-1);
end

