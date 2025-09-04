function [oddball_tbl, standard_tbl] = read_csv(filename,t)
% Read oddball/standard event timings from results CSV

% === 1) Read CSV ===
results = readtable(filename); % contains columns: oddball_timing and is_oddball

stim_times = results.oddball_timing;   % stimulus onset times
is_oddball = results.is_oddball;       % oddball/standard indicator

% Assume 'is_oddball' is a cell array of strings {'True', 'False', ...}
is_oddball_num = strcmp(is_oddball, 'True'); % convert to logical: 1 if 'True', 0 if 'False'

% Build event table: row 1 = times, row 2 = oddball flag
event_table = [stim_times'; double(is_oddball_num')];

% Oddball events (add offset if needed, here +time_rel(1))
oddball_tbl = event_table(1, event_table(2,:) == 1) + t(1);

% Standard events
standard_tbl = event_table(1, event_table(2,:) == 0) + t(1);

end
