function [] = PlotData(X, Y, numberOfPlots)
    tiledlayout(numberOfPlots,1)

    for i=1:1:numberOfPlots
        ax = nexttile;
        % plot(nmbOfPlot, x-axis, y-axis)
        plot(ax, X(:,1), Y(:,(i+1)));
        title("Sensor " + i);
    end
    
    sgtitle('Signal in time domain')
end

