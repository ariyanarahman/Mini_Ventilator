% Interactive Area Between Curves — Click & Drag to Select Regions
% File: 2_18_calibration_2.txt
%
% HOW TO USE:
%   - Click and drag on the plot to select a time region
%   - Release to compute the area between P1 and P2 for that region
%   - Repeat for as many regions as you want
%   - Press ENTER or close the figure to finish and see the total
%   - Press Z to undo the last selection
%   - Press C to clear all selections
% ── Load data 
data   = readmatrix('retry 225.txt', 'NumHeaderLines', 2, 'Delimiter', ',');
time_s = data(:, 1) / 1000;
p1     = data(:, 2);
p2     = data(:, 3);
absDiff = abs(p2 - p1);
% ── State variables (shared via guidata) 
state.time_s   = time_s;
state.p1       = p1;
state.p2       = p2;
state.absDiff  = absDiff;
state.regions  = [];      % Nx2 array of [tStart, tEnd] for each selection
state.areas    = [];      % Nx1 area for each selection
state.patches  = [];      % handles to shaded patch objects
state.isDragging = false;
state.dragStart  = NaN;
state.dragPatch  = [];    % temporary patch while dragging
%  Build figure 
fig = figure('Name', 'Area Between Curves  |  Click & Drag to Select', ...
            'NumberTitle', 'off', ...
            'Position', [80 80 1150 650], ...
            'Color', [0.97 0.97 0.97]);
ax = axes('Parent', fig, 'Position', [0.08 0.18 0.88 0.74]);
hold(ax, 'on');
% Plot curves
plot(ax, time_s, p1, 'b-', 'LineWidth', 1.4, 'DisplayName', 'P1');
plot(ax, time_s, p2, 'r-', 'LineWidth', 1.4, 'DisplayName', 'P2');
% Fill between curves (subtle background)
fill([time_s; flipud(time_s)], [p1; flipud(p2)], ...
    [0.9 0.9 0.9], 'FaceAlpha', 0.25, 'EdgeColor', 'none', ...
    'HandleVisibility', 'off');
yline(ax, 0, 'k:', 'LineWidth', 0.8, 'HandleVisibility', 'off');
grid(ax, 'on');
xlabel(ax, 'Time (s)');
ylabel(ax, 'Pressure (cmH_2O)');
title(ax, 'Click and drag to select regions', 'FontSize', 13);
legend(ax, 'Location', 'best');
yPad = 0.15 * (max([p1; p2]) - min([p1; p2]));
state.yLims = [min([p1; p2]) - yPad,  max([p1; p2]) + yPad];
ylim(ax, state.yLims);
xlim(ax, [time_s(1), time_s(end)]);
%  Info panel at the bottom 
state.infoText = uicontrol('Style', 'text', ...
   'Units', 'normalized', ...
   'Position', [0.08 0.01 0.88 0.12], ...
   'HorizontalAlignment', 'left', ...
   'FontSize', 10.5, ...
   'FontName', 'Courier New', ...
   'BackgroundColor', [0.15 0.15 0.15], ...
   'ForegroundColor', [0.2 1 0.4], ...
   'String', '  No regions selected yet.   [ Drag to select | Z = undo | C = clear | Enter = finish ]');
%  Store state & attach callbacks 
guidata(fig, state);
set(fig, 'WindowButtonDownFcn',   @onMouseDown);
set(fig, 'WindowButtonMotionFcn', @onMouseMove);
set(fig, 'WindowButtonUpFcn',     @onMouseUp);
set(fig, 'KeyPressFcn',           @onKeyPress);
set(fig, 'DeleteFcn',             @onClose);
% 
%  CALLBACKS
% 
function onMouseDown(fig, ~)
   state = guidata(fig);
   ax    = findobj(fig, 'Type', 'axes');
   cp    = get(ax, 'CurrentPoint');
   xClick = cp(1,1);
   % Only start drag if click is inside axes x-range
   xl = xlim(ax);
   if xClick < xl(1) || xClick > xl(2)
       return;
   end
   state.isDragging = true;
   state.dragStart  = xClick;
   % Create a temporary drag patch (invisible until mouse moves)
   yl = state.yLims;
   state.dragPatch = patch(ax, ...
       [xClick xClick xClick xClick], ...
       [yl(1) yl(1) yl(2) yl(2)], ...
       [1 0.85 0.2], 'FaceAlpha', 0.25, 'EdgeColor', [0.9 0.6 0], ...
       'LineWidth', 1.5, 'HandleVisibility', 'off');
   guidata(fig, state);
end
function onMouseMove(fig, ~)
   state = guidata(fig);
   if ~state.isDragging; return; end
   ax = findobj(fig, 'Type', 'axes');
   cp = get(ax, 'CurrentPoint');
   xNow = cp(1,1);
   xStart = state.dragStart;
   xEnd   = xNow;
   yl     = state.yLims;
   % Update drag patch shape
   set(state.dragPatch, 'XData', [xStart xEnd xEnd xStart]);
   set(state.dragPatch, 'YData', [yl(1) yl(1) yl(2) yl(2)]);
   % Live area preview in info bar
   t  = state.time_s;
   d  = state.absDiff;
   x1 = min(xStart, xEnd);
   x2 = max(xStart, xEnd);
   mask = t >= x1 & t <= x2;
   if sum(mask) >= 2
       liveArea = trapz(t(mask), d(mask));
       set(state.infoText, 'String', ...
           sprintf('  Dragging: [%.2f s → %.2f s]   Live area = %.4f cmH₂O·s', x1, x2, liveArea));
   end
   guidata(fig, state);
end
function onMouseUp(fig, ~)
   state = guidata(fig);
   if ~state.isDragging; return; end
   ax = findobj(fig, 'Type', 'axes');
   cp = get(ax, 'CurrentPoint');
   xEnd = cp(1,1);
   xStart = state.dragStart;
   state.isDragging = false;
   x1 = min(xStart, xEnd);
   x2 = max(xStart, xEnd);
   % Delete temporary drag patch
   if ishandle(state.dragPatch)
       delete(state.dragPatch);
   end
   state.dragPatch = [];
   % Ignore tiny clicks (< 0.2 s wide)
   if (x2 - x1) < 0.2
       guidata(fig, state);
       updateInfoText(fig);
       return;
   end
   % Compute area for this region
   t    = state.time_s;
   d    = state.absDiff;
   mask = t >= x1 & t <= x2;
   if sum(mask) < 2
       guidata(fig, state);
       return;
   end
   area = trapz(t(mask), d(mask));
   % Store region
   state.regions(end+1, :) = [x1, x2];
   state.areas(end+1)       = area;
   % Draw permanent shaded patch
   yl    = state.yLims;
   nReg  = size(state.regions, 1);
   colors = [0.2 0.7 0.3;   % green
             0.2 0.4 0.9;   % blue
             0.8 0.3 0.8;   % purple
             0.9 0.5 0.1;   % orange
             0.1 0.8 0.8];  % teal
   c = colors(mod(nReg-1, size(colors,1))+1, :);
   h = patch(ax, [x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], ...
             c, 'FaceAlpha', 0.22, 'EdgeColor', c, 'LineWidth', 2, ...
             'HandleVisibility', 'off');
   % Label above the region
   yTop = yl(2) - 0.04*(yl(2)-yl(1));
   text(ax, (x1+x2)/2, yTop, ...
        sprintf('R%d\n%.3f', nReg, area), ...
        'HorizontalAlignment', 'center', 'FontSize', 9, ...
        'FontWeight', 'bold', 'Color', c*0.7, 'HandleVisibility', 'off');
   state.patches(end+1) = h;
   guidata(fig, state);
   updateInfoText(fig);
end
function onKeyPress(fig, evt)
   state = guidata(fig);
   switch upper(evt.Key)
       case 'Z'   % undo last region
           if isempty(state.regions); return; end
           if ishandle(state.patches(end)); delete(state.patches(end)); end
           state.patches(end) = [];
           state.regions(end,:) = [];
           state.areas(end)   = [];
           guidata(fig, state);
           updateInfoText(fig);
       case 'C'   % clear all
           for i = 1:numel(state.patches)
               if ishandle(state.patches(i)); delete(state.patches(i)); end
           end
           % Also delete region text labels
           txtObjs = findobj(fig, 'Type', 'text');
           delete(txtObjs);
           state.patches = [];
           state.regions = [];
           state.areas   = [];
           guidata(fig, state);
           updateInfoText(fig);
       case 'RETURN'   % finish
           onClose(fig, []);
   end
end
function onClose(fig, ~)
   state = guidata(fig);
   if isempty(state.areas)
       fprintf('\nNo regions selected.\n');
       return;
   end
   fprintf('\n════════════════════════════════════════════════\n');
   fprintf('  SELECTED REGIONS — Area Between P1 and P2\n');
   fprintf('════════════════════════════════════════════════\n');
   fprintf('  %-8s  %-12s  %-12s  %-12s  %s\n', ...
           'Region', 'Start (s)', 'End (s)', 'Dur (s)', 'Area (cmH2O·s)');
   for i = 1:size(state.regions, 1)
       t0 = state.regions(i,1);
       t1 = state.regions(i,2);
       fprintf('  %-8d  %-12.2f  %-12.2f  %-12.2f  %.4f\n', ...
               i, t0, t1, t1-t0, state.areas(i));
   end
   fprintf('  ─────────────────────────────────────────────\n');
   fprintf('  TOTAL:                                        %.4f cmH2O·s\n', sum(state.areas));
   fprintf('════════════════════════════════════════════════\n\n');
end
function updateInfoText(fig)
   state = guidata(fig);
   n = numel(state.areas);
   if n == 0
       str = '  No regions selected.   [ Drag to select | Z = undo | C = clear | Enter = print results ]';
   else
       parts = arrayfun(@(i) sprintf('R%d=%.3f', i, state.areas(i)), 1:n, 'UniformOutput', false);
       str = sprintf('  %s   |   TOTAL = %.4f cmH2O·s     [ Z=undo  C=clear  Enter=print ]', ...
                     strjoin(parts, '   '), sum(state.areas));
   end
   set(state.infoText, 'String', str);
end

