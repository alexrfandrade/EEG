function datastruct = unicornrecorder_read_csv(filename, fs)
% UNICORNRECORDER_READ_CSV - Reads a Unicorn Recorder CSV file (8 EEG channels)
% without using the proprietary .p file.
%
%   datastruct = UNICORNRECORDER_READ_CSV(filename, fs)
%
%   INPUTS:
%       filename - full path to the CSV file
%       fs       - sampling rate in Hz
%
%   OUTPUT:
%       datastruct - structure with fields:
%           .samplingRate
%           .data
%           .channels
%           .numberOfChannels
%           .numberOfSamples
%           .trig

% === 1) Read CSV ===
data = readmatrix(filename);

EEG  = data(:,1:8);    % 8 EEG channels
TRIG = data(:,9);      % trigger channel

% Channel names (example – adapt if you have actual labels)
channels = {'Ch1','Ch2','Ch3','Ch4','Ch5','Ch6','Ch7','Ch8'};

% === 2) Band-pass filter (1–30 Hz) ===
bpFilt = designfilt('bandpassiir','FilterOrder',4, ...
    'HalfPowerFrequency1',1,'HalfPowerFrequency2',30,'SampleRate',fs);
EEG_bp = filtfilt(bpFilt, EEG);

% === 3) Notch filter (50 Hz) ===
notchFilt = designfilt('bandstopiir','FilterOrder',2, ...
    'HalfPowerFrequency1',49,'HalfPowerFrequency2',51,'SampleRate',fs);
EEG_filt = filtfilt(notchFilt, EEG_bp);

% === 4) (Optional) Re-referencing: Common Average Reference (CAR) ===
% Uncomment if needed:
%EEG_ref = EEG_filt - mean(EEG_filt,2); not adapted

% === 5) Create output structure ===
datastruct = struct();
datastruct.samplingRate     = fs;
datastruct.data             = EEG_filt;
datastruct.channels         = channels;
datastruct.numberOfChannels = size(EEG_filt,2);
datastruct.numberOfSamples  = size(EEG_filt,1);
datastruct.trig             = TRIG;

end
