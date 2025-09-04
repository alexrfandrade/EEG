%This main calls two differents fonctions. First, the function unicornrecorder_read_csv.m loads 
% and filters the EEG data recorded with the Unicorn device (band-pass 1–30 Hz and 50 Hz notch), 
% returning a structured dataset with the signals, trigger channel, and metadata. 
% Second, the function read_csv.m imports the experimental events from the behavioral 
% results file and separates stimulus timings into oddball and standard trials. 
% Finally, the main script combines the EEG signals with the event markers, allowing you 
% to visualize the filtered data, align it to triggers, and overlay event markers for further analysis and interpretation.

%% Participant Choice
% Cassandre
% filename = '/Users/iristhouard/Documents/MATLAB/codes/P300/resultats_uni/records/results_unicornrecorder/results_uni_cass/UnicornRawDataRecorder_25_08_2025_15_16_060.csv';
% filename_results = '/Users/iristhouard/Documents/MATLAB/codes/P300/resultats_uni/records/results_oddball_csv/results_cass/results_oddball_block1_20250825_151838.csv';

% Beatriz
filename = '/Users/iristhouard/Documents/MATLAB/codes/P300/resultats_uni/records/results_unicornrecorder/results_uni_Beatriz/UnicornRecorder_02_09_2025_14_26_170.csv';
filename_results = '/Users/iristhouard/Documents/MATLAB/codes/P300/resultats_uni/records/results_oddball_csv/results_Beatriz/results_oddball_block1_20250902_142845.csv';

% Solenne
% filename = '/Users/iristhouard/Documents/MATLAB/codes/P300/resultats_uni/records/results_unicornrecorder/results_uni_solenne/UnicornRecorder_26_08_2025_14_31_150.csv';
% filename_results = '/Users/iristhouard/Documents/MATLAB/codes/P300/resultats_uni/records/results_oddball_csv/results_solenne/results_oddball_block1_20250826_143417.csv';

% Paul
% filename = '/Users/iristhouard/Documents/MATLAB/codes/P300/resultats_uni/records/results_unicornrecorder/results_uni_paul/UnicornRecorder_paul.csv';
% filename_results = '/Users/iristhouard/Documents/MATLAB/codes/P300/resultats_uni/records/results_oddball_csv/results_paul/results_oddball_block1_20250825_145249.csv';


fs = 250;  % sampling frequency (Hz)

% Load EEG data from Unicorn recorder CSV
datastruct = unicornrecorder_read_csv(filename, fs);

% Time vector
time = (0:datastruct.numberOfSamples-1)/fs;

% Find first trigger index
t0_idx = find(datastruct.trig, 1);  % index of trigger
time_rel = time(t0_idx:end);        % time vector from t0 to end
EEG_rel = datastruct.data(t0_idx:end, :); % EEG data corresponding to this time subset

% Quick check
disp(datastruct);

% If behavioral results are needed:
[oddball_tbl, standard_tbl] = read_csv(filename_results, time_rel);



% Plot all channels with vertical offset
figure;
plot(time_rel, EEG_rel + (0:datastruct.numberOfChannels-1)*100);
xlabel('Time (s)');
ylabel('EEG channels (µV, offset)');
title('Filtered EEG (1–30 Hz + Notch)');

% Plot a single channel (channel 3) with event markers (if available)
figure;
plot(time_rel, EEG_rel(:,3)); % EEG channel 3
hold on;

% Standards (green, thin dashed lines)
std_times = standard_tbl;
for i = 1:length(std_times)
    xline(std_times(i), 'g--', 'LineWidth', 0.5); % 0.5 = very thin
end

% Oddballs (red, thin solid lines)
odd_times = oddball_tbl;
for i = 1:length(odd_times)
    xline(odd_times(i), 'r-', 'LineWidth', 0.5);
end

xlabel('Time (s)');
ylabel('EEG amplitude (µV)');
title('EEG with standard events (green dashed) and oddball (red)');
legend('EEG channel 3');
grid on;
