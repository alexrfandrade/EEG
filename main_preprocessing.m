%% === MAIN: Preprocessing up to ICA (single .set save) ===
clear; clc;

%% === Required Paths ===
addpath('/Users/iristhouard/Documents/MATLAB/FieldTrip'); 
ft_defaults;

%% === USER PARAMETERS ===
dataFolder = '/Users/iristhouard/Documents/MATLAB/codes/P300/Preprocessing_Pipeline/results_cass1';
eegFile    = 'cass1_25jul.vhdr';
csvFile    = fullfile(dataFolder, 'results_oddball_block3_20250725_153112.csv');
fs         = 500;  % sampling frequency in Hz

%% === Output base name (without extension) ===
[~, baseName, ~] = fileparts(eegFile);
outBaseName = [baseName '_afterICA'];   % e.g., "cass1_25jul_afterICA"

%% === 1) Load EEG data (FieldTrip) ===
cfg = [];
cfg.dataset = fullfile(dataFolder, eegFile);
data_raw = ft_preprocessing(cfg);

%% === 2) Add events from .vmrk + CSV ===
vmrkFile = fullfile(dataFolder, strrep(eegFile, '.vhdr', '.vmrk'));

% Read "Start" marker from .vmrk
startSample = NaN;
fid = fopen(vmrkFile, 'r');
if fid == -1
    error('Cannot open .vmrk file');
end
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

% Read CSV to get oddball/standard trials
tbl = readtable(csvFile);
nTrials = height(tbl);

% Create events structure
emptyEvt = struct('type','', 'sample',0, 'value',0, ...
                  'timestamp',0, 'offset',0, 'duration',0);
events = repmat(emptyEvt, nTrials, 1);

for i = 1:nTrials
    t_sec = tbl.oddball_timing(i);                % stimulus time in seconds
    sample_idx = round(t_sec * fs) + startSample; % corresponding sample index
    isOddball = strcmpi(tbl.is_oddball{i}, 'True');

    events(i).type      = 'stimulus';
    events(i).sample    = sample_idx;
    events(i).value     = double(isOddball);      % 1=oddball, 0=standard
    events(i).timestamp = t_sec;
    events(i).offset    = 0;
    events(i).duration  = 0;
end

% Add events to FieldTrip structure
data_raw.cfg.event = events;

fprintf('Events added: %d trials (%d oddball, %d standard)\n', ...
    nTrials, sum([events.value]==1), sum([events.value]==0));

%% Minimal FieldTrip compatibility
if ~isfield(data_raw, 'hdr')
    data_raw.hdr.Fs     = fs;
    data_raw.hdr.label  = data_raw.label;
    data_raw.hdr.nChans = numel(data_raw.label);
end
if ~isfield(data_raw, 'trial')
    error('Missing .trial field in data_raw');
end

%% === 3) Preprocessing up to ICA (then stop & save single .set) ===
preferredOutDir = '/Users/iristhouard/Desktop/EEG_afterICA'; % try Desktop first
EEG = preprocPipeline_afterICA(data_raw, outBaseName, preferredOutDir);

disp('-----------------------------------------------------');
disp('Preprocessing complete. ICA computed, .set saved.');
disp('Inspect/reject ICs manually in EEGLAB if needed.');
disp('-----------------------------------------------------');
