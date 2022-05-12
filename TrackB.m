function [out] = TrackB(windowSize, data)
    out = zeros(size(data,1), size(data,2));
    
    for k=1:size(data,2)
        out(:,k) = RMSWindow(data(:,k), windowSize );
    end
end

