function [] = ExportData(data, sheet)
    filename = 'patientdata.xlsx';
    writematrix(data, filename, 'Sheet', sheet, 'Range', 'A1')
end

