function [output] = RMSWindow(data, windowSize)
    output = zeros(size(data, 1), size(data, 2));
    for i=1:size(data, 1)-windowSize
        output(i) = sqrt(mean(data(i:i+windowSize))^2);
    end
    output(size(data, 1)-windowSize:size(data, 1)) = data(size(data, 1)-windowSize:size(data, 1));
end