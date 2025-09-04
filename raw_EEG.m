%% === MAIN: Load and visualize raw EEG only ===
clear; clc;

%% === Required Paths ===
addpath('/Users/iristhouard/Documents/MATLAB/FieldTrip'); 
ft_defaults;

%% === USER PARAMETERS ===
dataFolder = '/Users/iristhouard/Documents/MATLAB/codes/P300/Preprocessing_Pipeline/results_cass1';
eegFile    = 'cass1_25jul.vhdr';
fs         = 500;  % sampling frequency in Hz

%% === 1) Load EEG (FieldTrip) ===
cfg = [];
cfg.dataset = fullfile(dataFolder, eegFile);
data_raw = ft_preprocessing(cfg);

%% === 2) Add events from .vmrk (if needed) ===
vmrkFile = fullfile(dataFolder, strrep(eegFile, '.vhdr', '.vmrk'));
startSample = NaN;
fid = fopen(vmrkFile, 'r');
if fid ~= -1
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
    if ~isnan(startSample)
        fprintf('Start marker found at sample %d\n', startSample);
    end
else
    warning('Could not open .vmrk file.');
end

%% === 3) Visualize raw EEG ===
cfg = [];
cfg.viewmode = 'vertical';  % use 'butterfly' for overlay
cfg.ylim     = [-100 100];  % adjust based on expected amplitude (µV)
ft_databrowser(cfg, data_raw);

disp('Raw EEG loaded and displayed. No ICA or saving performed.');
