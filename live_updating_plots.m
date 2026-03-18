%% Live Arduino Pressure Plot + Saving Files
clear; clc; close all;
% 
% Serial settings
% 
port = "/dev/cu.usbserial-110"; %change depend on computer
baudrate = 115200;
timeWindow = 10;   % seconds to display
s = serialport(port, baudrate);
configureTerminator(s,"LF");
s.Timeout = 2;          % reasonable timeout
pause(2);              % allow Arduino reset
flush(s);              % clear junk startup data
% 
% File logging
% 
folder = "C:\Users\ariyanarahman\Documents\Senior Design\Waveforms"; %change based on where you want to save the files
if ~isfolder(folder)
   mkdir(folder);
end
ts = string(datetime("now","Format","yyyyMMdd_HHmmss"));
filename = "waveform_" + ts + ".txt";
fullpath = fullfile(folder, filename);
fileID = fopen(fullpath,"w");
if fileID == -1
   error("Could not open file for writing.");
end
disp("Recording to: " + fullpath);
disp("Recording started. Press CTRL+C to stop.");
% 
% Data storage
% 
allData = [];          % [time_ms, p1, p2]
expectedCols = 3;
maxSamples = 1e5;      % prevent runaway memory
% 
% Single figure, single axes
% 
figure('Name','Live Arduino Pressures','NumberTitle','off');
ax = axes;
hold(ax,'on');
h1 = plot(ax,nan,nan,'r-','LineWidth',1.5); % P1
h2 = plot(ax,nan,nan,'b-','LineWidth',1.5); % P2
hd = plot(ax,nan,nan,'g-','LineWidth',1.5); % P1 - P2
xlabel(ax,'Time (s)');
ylabel(ax,'Pressure');
title(ax,'Live Pressure Signals & Difference');
legend(ax,{'P1','P2','P1-P2'},'Location','best');
grid(ax,'on');
% 
% Main loop
% 
try
   while true
       % Read serial line
       line = readline(s);
       % Log raw text
       fprintf(fileID,"%s\n",line);
       % Parse CSV
       nums = str2double(split(strtrim(line),","));
       % Validate numeric data
       if numel(nums) ~= expectedCols || any(isnan(nums))
           continue;
       end
       % Append data
       allData(end+1,:) = nums'; %#ok<SAGROW>
       % Trim old data to protect memory
       if size(allData,1) > maxSamples
           allData(1:1000,:) = [];
       end
       % Time vector (seconds)
       time_s = allData(:,1) / 1000;
       % Difference signal
       diffSignal = allData(:,2) - allData(:,3);
       % Sliding window indices
       if time_s(end) > timeWindow
           idx = time_s >= (time_s(end) - timeWindow);
       else
           idx = true(size(time_s));
       end
       % Windowed data
       tplot  = time_s(idx);
       p1plot = allData(idx,2);
       p2plot = allData(idx,3);
       dplot  = diffSignal(idx);
       % Update plots
       set(h1,'XData',tplot,'YData',p1plot);
       set(h2,'XData',tplot,'YData',p2plot);
       set(hd,'XData',tplot,'YData',dplot);
       % Safe x-limits
       xmin = max(0, tplot(end) - timeWindow);
       xlim(ax,[xmin tplot(end)]);
       drawnow limitrate
   end
catch ME
   disp("Recording stopped.");
   disp(ME.message);
end
% 
% Cleanup
% 
fclose(fileID);
clear s;
disp("File saved and serial port closed.");


