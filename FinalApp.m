classdef FinalApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        GridLayout                  matlab.ui.container.GridLayout
        LeftPanel                   matlab.ui.container.Panel
        FrequencydomainSwitch       matlab.ui.control.Switch
        FrequencydomainSwitchLabel  matlab.ui.control.Label
        TabGroup                    matlab.ui.container.TabGroup
        BandpassTab                 matlab.ui.container.Tab
        GridLayout2_2               matlab.ui.container.GridLayout
        EditField_7                 matlab.ui.control.NumericEditField
        EditField_5                 matlab.ui.control.NumericEditField
        EditField_4                 matlab.ui.control.NumericEditField
        OrderLabel                  matlab.ui.control.Label
        UpperboundLabel_2           matlab.ui.control.Label
        LowerboundLabel_2           matlab.ui.control.Label
        RMSwindowTab                matlab.ui.container.Tab
        GridLayout3_5               matlab.ui.container.GridLayout
        EditField_6                 matlab.ui.control.NumericEditField
        WindowsizeLabel_2           matlab.ui.control.Label
        ExportPanel_2               matlab.ui.container.Panel
        GridLayout3_4               matlab.ui.container.GridLayout
        ExportsettingsButton_2      matlab.ui.control.Button
        ExportdataButton_2          matlab.ui.control.Button
        OutlierremovalPanel         matlab.ui.container.Panel
        GridLayout3_2               matlab.ui.container.GridLayout
        DropDown_2                  matlab.ui.control.DropDown
        StandarddeviationsLabel     matlab.ui.control.Label
        FileinputPanel              matlab.ui.container.Panel
        GridLayout3                 matlab.ui.container.GridLayout
        selectfileButton            matlab.ui.control.Button
        MCVfileLabel                matlab.ui.control.Label
        RightPanel                  matlab.ui.container.Panel
        TabGroup2                   matlab.ui.container.TabGroup
        Channel1Tab                 matlab.ui.container.Tab
        UIAxes                      matlab.ui.control.UIAxes
        Channel2Tab                 matlab.ui.container.Tab
        UIAxes_2                    matlab.ui.control.UIAxes
        Channel3Tab                 matlab.ui.container.Tab
        UIAxes_3                    matlab.ui.control.UIAxes
        Channel4Tab                 matlab.ui.container.Tab
        UIAxes_4                    matlab.ui.control.UIAxes
        Channel5Tab                 matlab.ui.container.Tab
        UIAxes_5                    matlab.ui.control.UIAxes
    end

    % Properties that correspond to apps with auto-reflow
    properties (Access = private)
        onePanelWidth = 576;
    end

    
    properties (Access = private)
        processing_track = "bandpass selected";
        filepath = "";
        data;
        number_of_channels = 0;
        header;
        time;
        rec_signal;
        raw_data;
        L;
        fs;
        f;
        MVC_normalised;
    end
    
    methods (Access = private)
        
        function ProcessEverything(app)
            if app.filepath ~= ""
                % start processing if file is selected
                importdata(app);
            end
        end
        
        function importdata(app)
            disp("Importing data");
            app.header = jsondecode(strrep(string(textscan(fopen(app.filepath, "r"),'%s',1,'delimiter','\n', 'headerlines',1)),"# ", ""));
            app.raw_data = readmatrix(app.filepath, 'HeaderLines', 3, 'ExpectedNumVariables', 7);
            
            app.number_of_channels = 5;
            
            % Preallocation of resources
            
            app.data = zeros(length(app.raw_data), app.number_of_channels);       % 5 channels
            app.time = zeros(length(app.raw_data), 1);       % 1 time axis
            app.time = app.raw_data(:,1)./1000;

            app.L = length(app.data);

            app.fs = app.header.x00_07_80_3B_46_63.samplingRate;        % Sampling frequency
            app.f = app.fs * (0:(app.L/2)) / app.L;                             % Frequency range (axis)

            
            MVConvert(app);
        end

        function MVConvert(app)
            disp("Converting to mV");
            % Sensor transfer function: EMG = ((((ADC/(2^n)) - 0.5)*VCC)/Gain) * 1000;        
            gain = 1000;        % Gain - 1000
            vcc = 3;            % VCC - 3V
            
            for row = 1:app.L
                for channel = 1:app.number_of_channels
                    % ADC - Value sampled from the channel
                    % n - Number of bits of the channel
                    n = app.header.x00_07_80_3B_46_63.resolution(channel);
                    app.data(row, channel) = ((((app.raw_data(row, channel + 2) / (2^n)) - 0.5) * vcc) / gain) * 1000;
                end
            end

            OutLierRemovalTrack(app);
        end

        function OutLierRemovalTrack(app)
            disp("Removing outliers");
            std = str2num(app.DropDown_2.Value);
            for channel = 1:app.number_of_channels
                app.data(:,channel) = filloutliers(app.data(:,channel),'linear','mean','ThresholdFactor', std);
            end
           
            ABTrack(app);
        end

        % select processingtrack
        function ABTrack(app)
            disp("Selecting Processing Track");
            if app.processing_track == "bandpass selected"
                BandpassTrack(app);
                RectifySignal(app);
            else
                RMSTrack(app);
            end
            MVCNormaliseTrack(app)
        end

        function RectifySignal(app)           
            for channel = 1:app.number_of_channels
                app.data(:,channel) = abs(app.data(:,channel));
            end
        end
        
        function BandpassTrack(app)
            disp("Applying bandpass filter on signal");
            % Filter options
            order = app.EditField_7.Value;
            fnyq = app.fs/2;
            fcutlow = app.EditField_4.Value;
            fcuthigh = app.EditField_5.Value;
            
            
            % Butterworth bandpass filter
            [b,a] = butter(order, [fcutlow, fcuthigh] / fnyq, "bandpass");
            
            for channel = 1:app.number_of_channels
                app.data(:,channel) = filtfilt(b, a, app.data(:,channel));       % Zero-phase digital filtering
            end
        end

        
        function RMSTrack(app)
            disp("Applying RMS window on signal");
            % Windo size in ms
            window = app.EditField_6.Value;
            
            for channel = 1:app.number_of_channels
                app.data(:, channel) = sqrt(movmean((app.data(:, channel).^2), window));      % RMS
            end
        end

        function MVCNormaliseTrack(app)
            disp("Normalising the MVC app.data");
            % Preallocate resources
            % Maximum Voluntary Contraction (MVC)
            MVC = [0 0 0 0 0];
            app.MVC_normalised = zeros(app.L, app.number_of_channels);
            
            % Find the MVC value for each channel (max value in raw app.data)
            for channel = 1:app.number_of_channels
                MVC(:,channel) = max(app.data(:, channel));
            end
            
            % Divide signal by MVC and convert to percentage
            for channel = 1:app.number_of_channels
                app.MVC_normalised(:,channel) = (app.data(:, channel) ./ MVC(1,channel)) .* 100;
            end
            % enable export
            app.ExportPanel_2.Enable;
            PlotData(app)
        end
        

        function p1 = FFTTransform(app, data)
            disp("Applying FFT");
            % Two sided spectrum (-Fmax:Fmax)
            p1 = fft(data);
        
            % Normalisation of the power of the output ( divistion by L)
            p1 = abs(p1/app.L);
        
            % Single sided spectrum (positive part of two sided spectrum * 2)
            p1 = p1(1:app.L/2+1);
            p1(2:end-1) = 2 * p1(2:end-1);
        end

        function PlotData(app)
            axes = [app.UIAxes app.UIAxes_2 app.UIAxes_3 app.UIAxes_4 app.UIAxes_5];
            if strcmp(app.FrequencydomainSwitch.Value, 'Off')
                for channel = 1:app.number_of_channels
                    plot(axes(channel), app.time, app.data(:,channel), 'r', 'LineWidth', 2);
                    
                    xlabel(axes(channel), "Time (s)");
                    ylabel(axes(channel), "Voltage (mV)");
                    title(axes(channel), "Time domain");
                end
            else
                for channel = 1:app.number_of_channels
                    plot(axes(channel), app.f, FFTTransform(app, app.data(:, channel)));
                    xlabel(axes(channel), "Frequency (Hz)");
                    ylabel(axes(channel), "Intensity");
                    title(axes(channel), "Frequency domain");
                end
            end

        end

        function ExportData(app)
            filename = append('Processed_Data_',datestr(now,'HH-MM-SS'),'.xlsx');
            writematrix(app.data, filename, 'Sheet', "Processed_data", 'Range', 'A1');
            writematrix(app.MVC_normalised, filename, 'Sheet', "Normalised_data", 'Range', 'A1');
        end

        function ExportSettings(app)
            json = struct('Standard_deviations', app.DropDown_2.Value, 'Window_size', app.EditField_6.Value);
            if app.processing_track == "bandpass selected"
                json = struct('Standard_deviations', app.DropDown_2.Value, 'Lower_bound', app.EditField_4.Value, 'Upper_bound', app.EditField_5.Value, "Order", app.EditField_7.Value);
            end
            filename = append('Parameters_',datestr(now,'HH-MM-SS'),'.json');
            fid=fopen(filename, 'w') ;
            encodedJSON = jsonencode(json); 
            fprintf(fid, encodedJSON); 
            fclose(fid); 
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: selectfileButton
        function FileSelect(app, event)

            try
                [file,path] = uigetfile('*.txt');  %open a file
                app.filepath = string(path)+string(file);
            catch error
                disp(error)
            end

            % after file was succesfully selected enable all the parameters
            app.EditField_4.Editable = 1;
            app.EditField_4.Enable = 1;

            app.EditField_5.Editable = 1;
            app.EditField_5.Enable= 1;
            app.EditField_6.Editable = 1;
            app.EditField_6.Enable = 1;

            app.DropDown_2.Editable = 1;
            app.DropDown_2.Enable = 1;

            app.EditField_7.Editable = 1;
            app.EditField_7.Enable = 1;

            app.ExportPanel_2.Enable = 'on';
            
            ProcessEverything(app);
        end

        % Value changed function: EditField_4
        function EditField_4ValueChanged(app, event)
            BandpassTrack(app);
        end

        % Value changed function: EditField_5
        function EditField_5ValueChanged(app, event)
            BandpassTrack(app);
        end

        % Value changed function: EditField_6
        function EditField_6ValueChanged(app, event)
            ProcessEverything(app);
        end

        % Value changed function: DropDown_2
        function DropDown_2ValueChanged(app, event)
            OutLierRemovalTrack(app);
        end

        % Callback function
        function Slider_3ValueChanged(app, event)
            ProcessEverything(app);
        end

        % Callback function
        function Slider_4ValueChanged(app, event)
            ProcessEverything(app);
        end

        % Callback function
        function DropDown_3ValueChanged(app, event)
            ProcessEverything(app);
        end

        % Selection change function: TabGroup
        function TabGroupSelectionChanged(app, event)
            if app.TabGroup.SelectedTab == app.BandpassTab
                app.processing_track = "bandpass selected";
            else
                app.processing_track = "rms selected";
            end
            ProcessEverything(app);
        end

        % Value changed function: EditField_7
        function EditField_7ValueChanged(app, event)
            ProcessEverything(app);            
        end

        % Value changed function: FrequencydomainSwitch
        function FrequencydomainSwitchValueChanged(app, event)
            ProcessEverything(app);            
        end

        % Button pushed function: ExportdataButton_2
        function ExportdataButton_2Pushed(app, event)
            ExportData(app);
        end

        % Button pushed function: ExportsettingsButton_2
        function ExportsettingsButton_2Pushed(app, event)
            ExportSettings(app);
        end

        % Changes arrangement of the app based on UIFigure width
        function updateAppLayout(app, event)
            currentFigureWidth = app.UIFigure.Position(3);
            if(currentFigureWidth <= app.onePanelWidth)
                % Change to a 2x1 grid
                app.GridLayout.RowHeight = {600, 600};
                app.GridLayout.ColumnWidth = {'1x'};
                app.RightPanel.Layout.Row = 2;
                app.RightPanel.Layout.Column = 1;
            else
                % Change to a 1x2 grid
                app.GridLayout.RowHeight = {'1x'};
                app.GridLayout.ColumnWidth = {256, '1x'};
                app.RightPanel.Layout.Row = 1;
                app.RightPanel.Layout.Column = 2;
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Position = [100 100 927 600];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.SizeChangedFcn = createCallbackFcn(app, @updateAppLayout, true);

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {256, '1x'};
            app.GridLayout.RowHeight = {'1x'};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.Scrollable = 'on';

            % Create LeftPanel
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;

            % Create FileinputPanel
            app.FileinputPanel = uipanel(app.LeftPanel);
            app.FileinputPanel.Title = 'File input';
            app.FileinputPanel.Position = [1 533 250 66];

            % Create GridLayout3
            app.GridLayout3 = uigridlayout(app.FileinputPanel);
            app.GridLayout3.RowHeight = {'fit'};

            % Create MCVfileLabel
            app.MCVfileLabel = uilabel(app.GridLayout3);
            app.MCVfileLabel.Layout.Row = 1;
            app.MCVfileLabel.Layout.Column = 1;
            app.MCVfileLabel.Text = 'MCV file:';

            % Create selectfileButton
            app.selectfileButton = uibutton(app.GridLayout3, 'push');
            app.selectfileButton.ButtonPushedFcn = createCallbackFcn(app, @FileSelect, true);
            app.selectfileButton.Layout.Row = 1;
            app.selectfileButton.Layout.Column = 2;
            app.selectfileButton.Text = 'select file';

            % Create OutlierremovalPanel
            app.OutlierremovalPanel = uipanel(app.LeftPanel);
            app.OutlierremovalPanel.Title = 'Outlier removal';
            app.OutlierremovalPanel.Position = [1 470 250 65];

            % Create GridLayout3_2
            app.GridLayout3_2 = uigridlayout(app.OutlierremovalPanel);
            app.GridLayout3_2.RowHeight = {'fit'};

            % Create StandarddeviationsLabel
            app.StandarddeviationsLabel = uilabel(app.GridLayout3_2);
            app.StandarddeviationsLabel.Layout.Row = 1;
            app.StandarddeviationsLabel.Layout.Column = 1;
            app.StandarddeviationsLabel.Text = 'Standard deviations';

            % Create DropDown_2
            app.DropDown_2 = uidropdown(app.GridLayout3_2);
            app.DropDown_2.Items = {'1', '2', '3'};
            app.DropDown_2.ValueChangedFcn = createCallbackFcn(app, @DropDown_2ValueChanged, true);
            app.DropDown_2.Tag = 'std';
            app.DropDown_2.Enable = 'off';
            app.DropDown_2.Layout.Row = 1;
            app.DropDown_2.Layout.Column = 2;
            app.DropDown_2.Value = '1';

            % Create ExportPanel_2
            app.ExportPanel_2 = uipanel(app.LeftPanel);
            app.ExportPanel_2.Enable = 'off';
            app.ExportPanel_2.Title = 'Export';
            app.ExportPanel_2.Position = [1 278 250 65];

            % Create GridLayout3_4
            app.GridLayout3_4 = uigridlayout(app.ExportPanel_2);
            app.GridLayout3_4.RowHeight = {'fit'};

            % Create ExportdataButton_2
            app.ExportdataButton_2 = uibutton(app.GridLayout3_4, 'push');
            app.ExportdataButton_2.ButtonPushedFcn = createCallbackFcn(app, @ExportdataButton_2Pushed, true);
            app.ExportdataButton_2.Layout.Row = 1;
            app.ExportdataButton_2.Layout.Column = 1;
            app.ExportdataButton_2.Text = 'Export data';

            % Create ExportsettingsButton_2
            app.ExportsettingsButton_2 = uibutton(app.GridLayout3_4, 'push');
            app.ExportsettingsButton_2.ButtonPushedFcn = createCallbackFcn(app, @ExportsettingsButton_2Pushed, true);
            app.ExportsettingsButton_2.Layout.Row = 1;
            app.ExportsettingsButton_2.Layout.Column = 2;
            app.ExportsettingsButton_2.Text = 'Export settings';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.LeftPanel);
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @TabGroupSelectionChanged, true);
            app.TabGroup.Position = [-1 342 251 129];

            % Create BandpassTab
            app.BandpassTab = uitab(app.TabGroup);
            app.BandpassTab.Title = 'Bandpass';

            % Create GridLayout2_2
            app.GridLayout2_2 = uigridlayout(app.BandpassTab);
            app.GridLayout2_2.ColumnWidth = {'1x', 110};
            app.GridLayout2_2.RowHeight = {'fit', 'fit', 'fit'};

            % Create LowerboundLabel_2
            app.LowerboundLabel_2 = uilabel(app.GridLayout2_2);
            app.LowerboundLabel_2.Layout.Row = 1;
            app.LowerboundLabel_2.Layout.Column = 1;
            app.LowerboundLabel_2.Text = 'Lowerbound';

            % Create UpperboundLabel_2
            app.UpperboundLabel_2 = uilabel(app.GridLayout2_2);
            app.UpperboundLabel_2.Layout.Row = 2;
            app.UpperboundLabel_2.Layout.Column = 1;
            app.UpperboundLabel_2.Text = 'Upperbound';

            % Create OrderLabel
            app.OrderLabel = uilabel(app.GridLayout2_2);
            app.OrderLabel.Layout.Row = 3;
            app.OrderLabel.Layout.Column = 1;
            app.OrderLabel.Text = 'Order';

            % Create EditField_4
            app.EditField_4 = uieditfield(app.GridLayout2_2, 'numeric');
            app.EditField_4.Limits = [0 Inf];
            app.EditField_4.ValueChangedFcn = createCallbackFcn(app, @EditField_4ValueChanged, true);
            app.EditField_4.Tag = 'lowerbound';
            app.EditField_4.Enable = 'off';
            app.EditField_4.Layout.Row = 1;
            app.EditField_4.Layout.Column = 2;
            app.EditField_4.Value = 20;

            % Create EditField_5
            app.EditField_5 = uieditfield(app.GridLayout2_2, 'numeric');
            app.EditField_5.Limits = [0 Inf];
            app.EditField_5.ValueChangedFcn = createCallbackFcn(app, @EditField_5ValueChanged, true);
            app.EditField_5.Tag = 'upperbound';
            app.EditField_5.Enable = 'off';
            app.EditField_5.Layout.Row = 2;
            app.EditField_5.Layout.Column = 2;
            app.EditField_5.Value = 50;

            % Create EditField_7
            app.EditField_7 = uieditfield(app.GridLayout2_2, 'numeric');
            app.EditField_7.Limits = [0 Inf];
            app.EditField_7.ValueChangedFcn = createCallbackFcn(app, @EditField_7ValueChanged, true);
            app.EditField_7.Enable = 'off';
            app.EditField_7.Layout.Row = 3;
            app.EditField_7.Layout.Column = 2;
            app.EditField_7.Value = 4;

            % Create RMSwindowTab
            app.RMSwindowTab = uitab(app.TabGroup);
            app.RMSwindowTab.Title = 'RMS window';

            % Create GridLayout3_5
            app.GridLayout3_5 = uigridlayout(app.RMSwindowTab);
            app.GridLayout3_5.RowHeight = {'fit'};

            % Create WindowsizeLabel_2
            app.WindowsizeLabel_2 = uilabel(app.GridLayout3_5);
            app.WindowsizeLabel_2.Layout.Row = 1;
            app.WindowsizeLabel_2.Layout.Column = 1;
            app.WindowsizeLabel_2.Text = 'Window size';

            % Create EditField_6
            app.EditField_6 = uieditfield(app.GridLayout3_5, 'numeric');
            app.EditField_6.Limits = [0 Inf];
            app.EditField_6.ValueChangedFcn = createCallbackFcn(app, @EditField_6ValueChanged, true);
            app.EditField_6.Tag = 'rmswindow';
            app.EditField_6.Enable = 'off';
            app.EditField_6.Layout.Row = 1;
            app.EditField_6.Layout.Column = 2;
            app.EditField_6.Value = 5;

            % Create FrequencydomainSwitchLabel
            app.FrequencydomainSwitchLabel = uilabel(app.LeftPanel);
            app.FrequencydomainSwitchLabel.HorizontalAlignment = 'center';
            app.FrequencydomainSwitchLabel.Position = [72 185 105 22];
            app.FrequencydomainSwitchLabel.Text = 'Frequency domain';

            % Create FrequencydomainSwitch
            app.FrequencydomainSwitch = uiswitch(app.LeftPanel, 'slider');
            app.FrequencydomainSwitch.ValueChangedFcn = createCallbackFcn(app, @FrequencydomainSwitchValueChanged, true);
            app.FrequencydomainSwitch.Position = [101 222 45 20];

            % Create RightPanel
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 2;

            % Create TabGroup2
            app.TabGroup2 = uitabgroup(app.RightPanel);
            app.TabGroup2.Position = [0 0 671 600];

            % Create Channel1Tab
            app.Channel1Tab = uitab(app.TabGroup2);
            app.Channel1Tab.Title = 'Channel 1';

            % Create UIAxes
            app.UIAxes = uiaxes(app.Channel1Tab);
            xlabel(app.UIAxes, 'X')
            ylabel(app.UIAxes, 'Y')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.Position = [1 1 665 575];

            % Create Channel2Tab
            app.Channel2Tab = uitab(app.TabGroup2);
            app.Channel2Tab.Title = 'Channel 2';

            % Create UIAxes_2
            app.UIAxes_2 = uiaxes(app.Channel2Tab);
            xlabel(app.UIAxes_2, 'X')
            ylabel(app.UIAxes_2, 'Y')
            zlabel(app.UIAxes_2, 'Z')
            app.UIAxes_2.Position = [1 1 665 575];

            % Create Channel3Tab
            app.Channel3Tab = uitab(app.TabGroup2);
            app.Channel3Tab.Title = 'Channel 3';

            % Create UIAxes_3
            app.UIAxes_3 = uiaxes(app.Channel3Tab);
            xlabel(app.UIAxes_3, 'X')
            ylabel(app.UIAxes_3, 'Y')
            zlabel(app.UIAxes_3, 'Z')
            app.UIAxes_3.Position = [1 1 665 575];

            % Create Channel4Tab
            app.Channel4Tab = uitab(app.TabGroup2);
            app.Channel4Tab.Title = 'Channel 4';

            % Create UIAxes_4
            app.UIAxes_4 = uiaxes(app.Channel4Tab);
            xlabel(app.UIAxes_4, 'X')
            ylabel(app.UIAxes_4, 'Y')
            zlabel(app.UIAxes_4, 'Z')
            app.UIAxes_4.Position = [1 1 665 575];

            % Create Channel5Tab
            app.Channel5Tab = uitab(app.TabGroup2);
            app.Channel5Tab.Title = 'Channel 5';

            % Create UIAxes_5
            app.UIAxes_5 = uiaxes(app.Channel5Tab);
            xlabel(app.UIAxes_5, 'X')
            ylabel(app.UIAxes_5, 'Y')
            zlabel(app.UIAxes_5, 'Z')
            app.UIAxes_5.Position = [1 1 665 575];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = FinalApp

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end