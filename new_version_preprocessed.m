% Start EEGLAB
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

%% 1. Load dataset
[filename, filepath] = uigetfile('*.vhdr', 'Select a .vhdr file BrainVision .vhdr');
if isequal(filename,0)
    error('No file selected.');
end
EEG = pop_loadbv(filepath, filename);
[ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, 0);

%% 2. Read the logfile
[logfile_name, log_path] = uigetfile({'*.txt;*.csv'}, 'Select the logfile');
if isequal(logfile_name, 0)
    error('No logfile file selected');
end
logfile_fullpath = fullfile(log_path, logfile_name);

log_table = readtable(logfile_fullpath, 'Delimiter', {'\t',' ',','}, 'MultipleDelimsAsOne', true);
if size(log_table,2) < 3
    error('The logfile needs 3 columns: Action, Trigger, Time(s)');
end

event_names = log_table{:,2};   % Get trigger
event_times = log_table{:,3};   % Get time
fs = EEG.srate; % frequency rate

% Read associated .vmrk
[~, name, ~] = fileparts(filename);
vmrk_file = fullfile(filepath, [name '.vmrk']);
fid = fopen(vmrk_file, 'r');
vmrk_lines = textscan(fid, '%s', 'Delimiter', '\n');
fclose(fid);
vmrk_lines = vmrk_lines{1};

first_start_sample = [];
for i = 1:length(vmrk_lines)
    line = strtrim(vmrk_lines{i});
    if startsWith(line, 'Mk') && contains(line, 'New Segment')
        tokens = strsplit(line, ',');
        if numel(tokens) >= 4
            first_start_sample = str2double(tokens{4});
            break;
        end
    end
end
if isempty(first_start_sample)
    error('No "Start" found in the .vmrk');
end

% Add events from logfile
for i = 1:length(event_times)
    latency_sample = first_start_sample + round(event_times(i) * fs); %convert the time event to frequency
    EEG.event(end+1).type = strtrim(event_names{i});  
    EEG.event(end).latency = latency_sample;
    EEG.event(end).urevent = length(EEG.event);
end
EEG = eeg_checkset(EEG, 'eventconsistency');

%% 3. Ask user what to analyse
analysisChoice = questdlg('What do you want to analyse ?', ...
    'Type of analyse', ...
    'All the signal', 'Among the triggers', 'All the signal');
if isempty(analysisChoice) %verify is a choice was made
    error('No selection choose.');
end

%% 4. Preprocessing on continuous data
% Notch filter
notchFreq = 50;  
EEG = pop_eegfiltnew(EEG, notchFreq-1, notchFreq+1, [], 1);
[ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);

% Re-reference
EEG = pop_reref(EEG, []);
[ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);

% Clean Rawdata (continuous)
EEG = pop_clean_rawdata(EEG);
[ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);

%% 5. Epoching if user chose triggers
if strcmp(analysisChoice, 'Among the triggers')
    allTriggers = unique(event_names);
    [selectedTriggerIdx, ok] = listdlg('PromptString', 'Select the triggers to analyse :', ...
                                       'ListString', allTriggers, ...
                                       'SelectionMode', 'multiple');
    if ~ok
        error('No triggers selected');
    end
    triggersToAnalyze = allTriggers(selectedTriggerIdx);

    prompt = {'Start (s) refered to trigger :', 'End (s) refered to trigger :'};
    dlgtitle = 'Time window';
    dims = [1 50];
    definput = {'-0.2', '0.8'};
    answer = inputdlg(prompt, dlgtitle, dims, definput);
    if isempty(answer)
        error('No window selected');
    end
    tmin = str2double(answer{1});
    tmax = str2double(answer{2});

    EEG = pop_epoch(EEG, triggersToAnalyze, [tmin tmax]);
    [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
end

%% VISUALISATION EEG BEFORE ICA
pop_eegplot(EEG, 1, 1, 1);
%% 6. Run ICA
EEG = pop_runica(EEG, 'extended', 1, 'interupt', 'on');
[ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

%% 7. ICA component rejection
EEG = pop_chanedit(EEG, 'lookup','standard-10-5-cap385.elp');
EEG = pop_selectcomps(EEG, 1:62); % change the 2nd number by the number of channels that you have
EEG = pop_subcomp(EEG);
[ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);

%% 8. Calculate and show Theta/Alpha ratio for channel 2 (example)
x  = EEG.data(2, :);    %change the "2" to choose another channel
Fs = EEG.srate;             
L  = EEG.pnts;              
NFFT = 2^nextpow2(L);        
NOVERLAP = 0;
WINDOW = 512;
[spectra,freqs] = pwelch(x,WINDOW,NOVERLAP,NFFT,EEG.srate);

freqMask = freqs <= 50;
spectra = spectra(freqMask);
freqs = freqs(freqMask);

thetaIdx   = find(freqs>=4 & freqs<=8);            
thetaPower = mean(spectra(thetaIdx));              
alphaIdx   = find(freqs>=8 & freqs<=12);           
alphaPower = mean(spectra(alphaIdx));              
matlabThetaAlphaRatio = thetaPower/alphaPower;

figure;
plot(freqs,spectra)
xlabel('Frequency (Hz)')
ylabel('Power (uV^2/Hz)')
title('Power Spectrum with Theta/Alpha Ratio')

%% 9. Save spectra for all channels
WINDOW = 512;
NOVERLAP = 0;
maxFreq = 50;
Fs = EEG.srate;
L = EEG.pnts;
NFFT = 2^nextpow2(L);
channelsToAnalyze = 1:EEG.nbchan;  

summaryData = [];

for ch = channelsToAnalyze
    x = EEG.data(ch, :);
    [spectra, freqs] = pwelch(x, WINDOW, NOVERLAP, NFFT, Fs);

    mask = freqs <= maxFreq;
    freqsMasked = freqs(mask);
    spectraMasked = spectra(mask);

    thetaIdx = freqsMasked >= 4 & freqsMasked <= 8;
    alphaIdx = freqsMasked >= 8 & freqsMasked <= 13;
    betaIdx  = freqsMasked >= 13 & freqsMasked <= 30;

    thetaPower = mean(spectraMasked(thetaIdx));
    alphaPower = mean(spectraMasked(alphaIdx));
    betaPower  = mean(spectraMasked(betaIdx));

    thetaAlphaRatio = thetaPower / alphaPower;

    T = table(freqsMasked, spectraMasked, ...
        'VariableNames', {'Frequency_Hz', 'Power_uV2_Hz'});

    chanLabel = EEG.chanlocs(ch).labels;
    spectrumFile = fullfile(filepath, ['Spectrum_' chanLabel '.csv']);
    writetable(T, spectrumFile);

    summaryData = [summaryData; 
        {chanLabel, thetaPower, alphaPower, betaPower, thetaAlphaRatio}];
end

summaryTable = cell2table(summaryData, ...
    'VariableNames', {'Channel', 'ThetaPower', 'AlphaPower', 'BetaPower', 'ThetaAlphaRatio'});

summaryFile = fullfile(filepath, 'EEG_BandPower_Summary.csv');
writetable(summaryTable, summaryFile);

%% 10. Save processed dataset
if strcmp(analysisChoice, 'All the signal')
    saveName = 'processed_notch50Hz_fullsignal.set';
else
    saveName = 'processed_notch50Hz_epochs.set';
end
EEG = pop_saveset(EEG, 'filename', saveName, ...
    'filepath', filepath);