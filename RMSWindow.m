function [output] = RMSWindow(data, windowSize)
    for i=1:length(data)-windowSize
        data(i) = sqrt(mean(data(i:windowSize))^2);
    end
    output = data(1:length(data)-windowSize);
end