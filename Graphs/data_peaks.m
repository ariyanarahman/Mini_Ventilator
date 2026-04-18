%% Ventilator Peak Verification Tool + Statistical Analysis
clear; clc; close all;

% 1. Load Data
[file, path] = uigetfile('*.txt', 'Select the recorded waveform file');
if isequal(file,0), return; end
data = readmatrix(fullfile(path, file));

% Column Mapping: [Time(ms), P1, P2, DeltaP, InVol, OutVol]
time_s = data(:, 1) / 1000;
p1 = data(:, 2);
p2 = data(:, 3);
dp = data(:, 4);

% 2. Peak Detection Logic
minDistSamples = 0.3 / mean(diff(time_s)); 
minH = 0.5; % Minimum pressure (cmH2O)

[p1_pks, p1_locs] = findpeaks(p1, 'MinPeakDistance', minDistSamples, 'MinPeakHeight', minH);
[p2_pks, p2_locs] = findpeaks(p2, 'MinPeakDistance', minDistSamples, 'MinPeakHeight', minH);
[dp_pks, dp_locs] = findpeaks(dp, 'MinPeakDistance', minDistSamples, 'MinPeakHeight', minH);

% Ensure equal length for paired testing
n_breaths = min([length(p1_pks), length(p2_pks), length(dp_pks)]);
p1_v = p1_pks(1:n_breaths);
p2_v = p2_pks(1:n_breaths);
dp_v = dp_pks(1:n_breaths);

% 3. Statistical Testing (Paired T-Test)
% H0: There is no difference between sensors. alpha = 0.05
[h12, p12] = ttest(p1_v, p2_v);
[h1d, p1d] = ttest(p1_v, dp_v);

% Calculate Coefficient of Variation (Consistency metric)
cv1 = (std(p1_v) / mean(p1_v)) * 100;

% 4. Print Statistical Report
fprintf('\n================================================\n');
fprintf('   STATISTICAL ANALYSIS REPORT (%d Breaths)\n', n_breaths);
fprintf('================================================\n');

% Display Summary Stats
StatsTable = table(["Mean"; "Std_Dev"], [mean(p1_v); std(p1_v)], [mean(p2_v); std(p2_v)], [mean(dp_v); std(dp_v)], ...
    'VariableNames', {'Metric', 'P1_cmH2O', 'P2_cmH2O', 'DeltaP_cmH2O'});
disp(StatsTable);

fprintf('------------------------------------------------\n');
fprintf('1. SENSOR COMPARISON (P1 vs P2):\n');
fprintf('   p-value: %.4e\n', p12);
if h12 == 1
    fprintf('   RESULT: Statistically Significant Difference.\n');
    fprintf('   (Sensors are measuring distinct pressure zones)\n');
else
    fprintf('   RESULT: NOT Statistically Significant.\n');
    fprintf('   (Sensors are tracking each other perfectly)\n');
end

fprintf('\n2. BREATH CONSISTENCY:\n');
fprintf('   Coefficient of Variation (P1): %.2f%%\n', cv1);
if cv1 < 10
    fprintf('   RESULT: Highly Consistent (Stable Ventilation)\n');
else
    fprintf('   RESULT: High Variation (Check for leaks or motor lag)\n');
end
fprintf('================================================\n');

% 5. Create UI Figure for Verification
fig = uifigure('Name', 'Breath Peak Verification Tool', 'Position', [100 100 1000 600]);
ax = uiaxes(fig, 'Position', [50 120 900 450], FontSize= 20);
hold(ax, 'on');

plot(ax, time_s, p1, 'r', 'DisplayName', 'P1', 'LineWidth', 2);
plot(ax, time_s, p2, 'b', 'DisplayName', 'P2', 'LineWidth', 2);
plot(ax, time_s, dp, 'g', 'DisplayName', 'DeltaP', 'LineWidth',2);

scatter(ax, time_s(p1_locs(1:n_breaths)), p1_v, 60, 'r', 'x', 'LineWidth', 3, 'HandleVisibility', 'off');
scatter(ax, time_s(p2_locs(1:n_breaths)), p2_v, 60, 'b', 'x', 'LineWidth', 3, 'HandleVisibility', 'off');
scatter(ax, time_s(dp_locs(1:n_breaths)), dp_v, 60, 'g', 'x', 'LineWidth', 3, 'HandleVisibility', 'off');

ylabel(ax, 'Pressure (cmH2O)', 'FontSize', 20); xlabel(ax, 'Time (seconds)', FontSize=20);
legend(ax, 'Location', 'northeastoutside'); grid(ax, 'on');

sld = uislider(fig, 'Position', [100 60 800 3], 'Limits', [0, max(0.1, max(time_s) - 5)], ...
    'ValueChangedFcn', @(sld, event) xlim(ax, [sld.Value, sld.Value + 1]));
xlim(ax, [0, 1]);