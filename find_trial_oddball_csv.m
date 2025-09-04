function [onset_sample, trial_type] = find_trial_oddball_csv(csv_file, start_time, startSample, fs, events, include_standard)
% FIND_TRIAL_ODDBALL_CSV - Robust version returning EEG sample index
%
% INPUTS:
%   csv_file         - CSV file (behavioral results)
%   start_time       - starting time in seconds
%   startSample      - first sample of EEG recording
%   fs               - sampling frequency (Hz)
%   events           - struct array with fields: timestamp (s), value (0/1)
%   include_standard - true/false, if standard trials should be considered
%
% OUTPUTS:
%   onset_sample     - sample index in EEG (aligned with startSample)
%   trial_type       - 'oddball' or 'standard'

if nargin < 6
    include_standard = false; % default: only oddballs
end

% Small offset to avoid missing first event
search_time = start_time + 0.01;

onset_sample = NaN;
trial_type   = '';

for i = 1:length(events)
    if events(i).timestamp >= search_time
        if events(i).value == 1
            trial_type = 'oddball';
            onset_sample = round(events(i).timestamp*fs) + startSample;
            return;
        elseif events(i).value == 0 && include_standard
            trial_type = 'standard';
            onset_sample = round(events(i).timestamp*fs) + startSample;
            return;
        end
    end
end

warning('No event found after %.3f s (end of CSV)', search_time);
end
