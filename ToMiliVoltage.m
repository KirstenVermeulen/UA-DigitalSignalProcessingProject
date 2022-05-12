function [EMG] = ToMiliVoltage(ADC, VCC, GEMG, n)
    EMG = ((((ADC/(2^n)) - 0.5)*VCC)/GEMG) * 1000;
end