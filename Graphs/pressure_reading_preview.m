data2 = readtable("/Users/ariyanarahman/Documents/MATLAB/C:\Users\ariyanarahman\Documents\Senior Design\Waveforms/waveform_20260317_143358.txt");

% Create the figure
figure; 
hold on; %

% Plot first set: Col 1 vs Col 2
plot(data2{100:500, 1}, data2{100:500, 2}, 'DisplayName', 'Sensor 1', 'LineWidth',2)

% Plot second set: Col 1 vs Col 3
plot(data2{100:500, 1}, data2{100:500, 3}, 'DisplayName', 'Sensor 2', 'LineWidth',2)

% Formatting
grid on;
xlabel(data.Properties.VariableNames{1}, "FontSize",20); 
ylabel('Pressure (hPa / cmH2O)', 'FontSize',20);    
title('Pressure Readings During Ventilation', 'FontSize',20);
lgd = legend('Show');
lgd.FontSize = 16;

hold off; % Release the plot
