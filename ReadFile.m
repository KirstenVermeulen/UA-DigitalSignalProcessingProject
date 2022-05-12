function [header, X] = ReadFile(path)
    header = jsondecode(strrep(string(textscan(fopen(path, "r"),'%s',1,'delimiter','\n', 'headerlines',1)),"# ", ""));
    
    X = readmatrix(path, 'HeaderLines', 3, 'ExpectedNumVariables', 7);
    X(:,1) = [];
    X(:,2) = [];
end

