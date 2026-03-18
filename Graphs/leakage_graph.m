data = readtable("/Users/ariyanarahman/Documents/MATLAB/C:\Users\ariyanarahman\Documents\Senior Design\Waveforms/waveform_20260317_134512.txt");


% Create the figure
figure; 
hold on; 

plot(data{:, 1}, data{:, 2}, 'DisplayName', 'Sensor 1', 'LineWidth',2)

% Formatting
grid on;
xlabel(data.Properties.VariableNames{1}, "FontSize",20); 
ylabel('Pressure (hPa / cmH2O)', 'FontSize',20);      
title('Pressure Readings', 'FontSize',20);
lgd = legend('Show');
lgd.FontSize = 16;

hold off; 
