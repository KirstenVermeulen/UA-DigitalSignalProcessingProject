function [result] = outLierRemoval(input)
  [res,faul] = rmoutliers(input);
  result = res;
end

