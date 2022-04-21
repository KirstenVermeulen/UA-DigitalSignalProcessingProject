function [result] = outLierRemoval(input,afwijking)
  res = filloutliers(input,'center','mean','ThresholdFactor', afwijking);
  result = res;
end

