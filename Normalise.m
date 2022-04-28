function [norm_data] = Normalise(data)
     norm_data = (data- min(data)) / ( max(data) - min(data) );
end