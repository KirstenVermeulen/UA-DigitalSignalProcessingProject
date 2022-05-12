function [out] = TrackA(lowerBound, upperBound, impulseResponse, steepnessLowerBound, steepnessUpperBound)
    
    
    for k=1:size(fourierTransform,2)
        % use Butter
        fourierTransform(:, k) = bandpass(fourierTransform(:, k), [lowerbound, upperbound], samplingRate, 'ImpulseResponse', impulseResponse,'Steepness', [steepnessLowerBound , steepnessUpperBound]);
    end
end

