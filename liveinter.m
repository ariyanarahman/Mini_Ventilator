%% Live Ventilator Data: Full Breath Integration (Insp + Exp)
clear; clc; close all;

% --- Configuration & Parameters ---
port = "/dev/cu.usbserial-110";     
baudrate = 250000;
timeWindow = 2.5;  
alphaConstant = 0.2; 

% Thresholds for "Quiet" detection (optional noise floor)
noiseFloor = 0.02; 
movingAvgWindow = 5; 

% --- State Variables ---
allData = [];         
breathHistory = [];   
currentBreathVolume = 0;
lastTime = 0;
lastDiff = 0;
lastVolResult = 0;   

% --- Figure Setup ---
fig = figure('Name','Full Breath Analytics','Color','w','Position',[100 100 1000 800]);
ax1 = subplot(3,1,1); hold on; grid on;
h1 = plot(ax1,0,0,'b-','LineWidth',3,'DisplayName','P1');
h2 = plot(ax1,0,0,'r-','LineWidth',3,'DisplayName','P2');
ylabel('Pressure (cmH2O)', FontSize=20); title('Real-Time Pressures', FontSize=20); legend;

ax2 = subplot(3,1,2); hold on; grid on;
hFlow = plot(ax2,0,0,'g-','LineWidth',3);
ylabel('Pressure Difference (cmH2O)', FontSize=20); title('Pressure Difference (p2 - p1)', FontSize=20);

ax3 = subplot(3,1,3); hold on; grid on;
hVol = plot(ax3,0,0,'m-','LineWidth',3);
ylabel('Volume (mL)', FontSize=20); xlabel('Time (s)', FontSize=20); title('Volume', FontSize=20);

linkaxes([ax1, ax2, ax3], 'x');

statsText = annotation('textbox', [0.1, 0.01, 0.8, 0.05], ...
   'String', 'Waiting for breath...', 'EdgeColor', 'k', 'BackgroundColor', 'w', 'FontSize', 11);

s = serialport(port, baudrate);
configureTerminator(s,"LF");
pause(2); flush(s);

try
  while ishandle(fig)
      line = readline(s);
      if isempty(line), continue; end
      nums = str2double(split(strtrim(line),","));
      if numel(nums) ~= 4 || any(isnan(nums)), continue; end
     
      currTime = nums(1) / 1000; 
      p1 = nums(2); p2 = nums(3);
      
      % --- Calibration Offset ---
      offset = -0; 
      
      % ACTUAL difference from sensors
      rawDiff = p2 - p1;
      
      % Adjusted difference (Shifted so -0.2 becomes 0)
      adjDiff = rawDiff - offset; 
      
      % Apply small deadzone to the ADJUSTED signal to ignore jitter
      if abs(adjDiff) < noiseFloor, adjDiff = 0; end
     
      % ─── Logic: Full Breath Integration (Zero-Crossing at Offset) ───
      if lastTime > 0
          dt = currTime - lastTime;
         
          % Start of a NEW breath: crossing the -0.2 baseline from below to above
          if rawDiff > offset && lastDiff <= offset
              % Log the finished breath before resetting
              if abs(currentBreathVolume) > 0.1
                  lastVolResult = currentBreathVolume;
                  breathHistory(end+1) = lastVolResult;
              end
              currentBreathVolume = 0; 
          end
          
          % 1. Trapezoidal Integration using the ADJUSTED difference
          % This ensures flow is 0 when rawDiff is -0.2
          sliceVolume = ((adjDiff + (lastDiff - offset)) / 2) * dt * alphaConstant;
          
          % 2. Apply the floor: Current Volume cannot go below 0
          currentBreathVolume = max(0, currentBreathVolume + sliceVolume);
      end
     
      % Store for plotting (Plotting adjDiff shows the flow centered at 0)
      allData(end+1,:) = [currTime, p1, p2, adjDiff, currentBreathVolume];
      lastTime = currTime; lastDiff = rawDiff;
      %allData(end+1,:) = [currTime, p1, p2, adjDiff, abs(adjDiff)*5];
     
      % ─── Update Visuals (Every 10 samples for speed) ───
      if mod(size(allData,1), 10) == 0
          tplot = allData(:,1);
          idx = tplot >= (tplot(end) - timeWindow);
          tVis = tplot(idx);
         
          set(h1, 'XData', tVis, 'YData', allData(idx,2));
          set(h2, 'XData', tVis, 'YData', allData(idx,3));
          set(hFlow, 'XData', tVis, 'YData', allData(idx,4));
          set(hVol, 'XData', tVis, 'YData', allData(idx,5));
         
          xlim(ax1, [max(0, tplot(end)-timeWindow), tplot(end)]);
         
          if ~isempty(breathHistory)
              set(statsText, 'String', sprintf(...
                  'Total Breaths: %d | Last Full Breath Net: %.3f mL | Moving Avg: %.3f mL', ...
                  length(breathHistory), lastVolResult, mean(breathHistory(max(1, end-4):end))));
          end
      end
      drawnow limitrate
  end
catch ME
  disp("Stopped: " + ME.message);
end
clear s;