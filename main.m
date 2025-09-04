s%% === MAIN: Single-trial P300 Detection Pipeline ===
clear; clc;

%% === USER PARAMETERS ===
dataFolder = '/Users/iristhouard/Documents/MATLAB/codes/P300/Preprocessing_Pipeline/results_cass1';
eegFile    = 'cass1_25jul.vhdr';
csvFile    = fullfile(dataFolder, 'results_oddball_block1_20250725_152445.csv');
fs         = 500;   % Sampling frequency (Hz)
channel    = 12;    % Channel index (e.g., 12=Pz, 16=Oz, 13=P3, 18=P4)

%% === Add Required Paths ===
addpath('/Users/iristhouard/Documents/MATLAB/FieldTrip'); 
ft_defaults;

%% === Load EEG Data with FieldTrip ===
cfg = [];
cfg.dataset = fullfile(dataFolder, eegFile);
data_raw = ft_preprocessing(cfg);

%% === Read "Start" Marker from .vmrk ===
vmrkFile = fullfile(dataFolder, strrep(eegFile, '.vhdr', '.vmrk'));

startSample = NaN;
fid = fopen(vmrkFile, 'r');
if fid == -1, error('Cannot open .vmrk file'); end
while ~feof(fid)
    line = fgetl(fid);
    if contains(line, 'Start')
        tok = strsplit(line, ',');
        if numel(tok) >= 3
            startSample = str2double(tok{3});
            break;
        end
    end
end
fclose(fid);

if isnan(startSample)
    error('"Start" marker not found in .vmrk file');
else
    fprintf('Start marker found at sample %d\n', startSample);
end

%% === Read CSV to Extract Oddball/Standard Trials ===
tbl = readtable(csvFile);
nTrials = height(tbl);

events = struct('type','stimulus','sample',[],'value',[],'timestamp',[],...
                'offset',0,'duration',0);

for i = 1:nTrials
    t_sec = tbl.oddball_timing(i);                % Stimulus onset in seconds
    isOddball = strcmpi(tbl.is_oddball{i}, 'True');
    
    events(i).sample    = round(t_sec*fs) + startSample; % Convert to EEG sample
    events(i).value     = double(isOddball);             % 1=oddball, 0=standard
    events(i).timestamp = t_sec;
end

fprintf('Events added: %d trials (%d oddball, %d standard)\n', ...
        nTrials, sum([events.value]==1), sum([events.value]==0));

%% === Run Single-Trial Detection for Each Trial ===
data = data_raw.trial{1}; % EEG data matrix (channels x samples)

res = struct('N2', {}, 'P3', {}, 'data_filt', {}, 't', {}, ...
             'coefs', {}, 'trial_type', {}, 'res_temp', {}, 'onset', {});
         
for i = 1:nTrials
    onset_sample = events(i).sample;   
    trial_type   = events(i).value;    % 1 = oddball, 0 = standard
    
    % --- Extract EEG Segment Around Stimulus Onset ---
    win_pre  = 0.2;  % 200 ms before onset
    win_post = 0.8;  % 800 ms after onset
    samples  = round((onset_sample - win_pre*fs) : (onset_sample + win_post*fs));
    
    % Ensure sample indices are within valid range
    samples(samples < 1) = [];
    samples(samples > size(data,2)) = [];
    
    % Select only the desired channel
    data_seg = data(channel, samples);
    
    % Initialize outputs
    N2 = 0; P3 = 0; N2_rel = 0; P3_rel = 0; res_temp = NaN;
    data_filt = data_seg; t = linspace(-win_pre, win_post, numel(data_seg));
    coefs = zeros(17, numel(data_seg)); % placeholder if no detection
    
    % --- Only run detection for oddball trials ---
    if trial_type == 1
        [N2, P3, data_filt, t, coefs] = point(data_seg, fs);

        % Onset index within the segment [-0.2, +0.8 s]
        onset_idx = round(win_pre * fs);

        % Indices relative to stimulus onset
        N2_rel = N2 - onset_idx;
        P3_rel = P3 - onset_idx;

        % Protect against no detection
        if N2 == 0 || P3 == 0
            N2_rel = 0; P3_rel = 0;
        end

        % --- Evaluate Detection ---
        res_temp = evaluation(N2_rel, P3_rel, fs);
    end
    
    % --- Store Results ---
    res(i).N2         = N2;
    res(i).P3         = P3;
    res(i).N2_rel     = N2_rel;
    res(i).P3_rel     = P3_rel;
    res(i).data_filt  = data_filt;
    res(i).t          = t;
    res(i).coefs      = coefs;
    res(i).trial_type = trial_type;
    res(i).res_temp   = res_temp;
    res(i).onset      = onset_sample;
end

%% === Example: Plot a Single Oddball Trial ===
trial_idx = 56; % Make sure this is an oddball trial

figure;
graphics(res(trial_idx).data_filt, res(trial_idx).coefs, ...
         res(trial_idx).t, res(trial_idx).onset, ...
         res(trial_idx).N2, res(trial_idx).P3, fs);

%% === Compute Accuracy for Oddball Trials Only ===
oddball_idx = [res.trial_type] == 1;

correct      = sum([res(oddball_idx).res_temp] == 1);
incorrect    = sum([res(oddball_idx).res_temp] == 0);
semi_correct = sum([res(oddball_idx).res_temp] == 2);

accuracy_oddball = (correct + semi_correct) / (correct + incorrect + semi_correct);

fprintf('Oddball trials accuracy: %.2f (correct + semi-correct / total)\n', accuracy_oddball);
fprintf('Correct: %d, Semi-correct: %d, Incorrect: %d\n', correct, semi_correct, incorrect);
