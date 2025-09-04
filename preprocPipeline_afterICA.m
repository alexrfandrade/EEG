function EEG = preprocPipeline_afterICA(data_raw, outBaseName, preferredOutDir)

    %% === EEGLAB ===
    addpath('/Users/iristhouard/Documents/MATLAB/eeglab2025.0.0');
    [~, ~, ~, ~] = eeglab; 

    %% === 1) Convert FieldTrip -> EEGLAB ===
    EEG = fieldtrip2eeglab(data_raw.hdr, data_raw.trial{1}, data_raw.cfg.event);
    EEG = eeg_checkset(EEG);

    %% === 1b) Robust channel locations + 10-20 lookup ===
    if ~isfield(EEG,'chanlocs') || isempty(EEG.chanlocs) || ...
       any(arrayfun(@(x) ~isfield(x,'labels') || isempty(x.labels), EEG.chanlocs))
        EEG.chanlocs = repmat(struct('labels',''), 1, EEG.nbchan);
        for c = 1:EEG.nbchan
            EEG.chanlocs(c).labels = data_raw.label{c};
        end
    end
    try
        EEG = pop_chanedit(EEG, 'lookup', fullfile(fileparts(which('eeglab')), ...
            'plugins','dipfit','standard_BEM','elec','standard_1020.elc'));
    catch
        warning('⚠️ Channel lookup failed. Keeping original labels.');
    end
    EEG = eeg_checkset(EEG);

    %% === 2) clean_rawdata (if available) ===
    if exist('clean_rawdata','file') == 2
        EEGc = clean_rawdata(EEG, ...
                [-1], ...   % flatlineCriterion disabled
                [-1], ...   % highpassCriterion disabled
                0.75, ...   % channelCriterion
                8,   ...    % lineNoiseCriterion
                15,  ...    % min valid samples
                -1);        % burstCriterion disabled
        if ~isempty(EEGc) && ~isempty(EEGc.data)
            EEG = EEGc;
        else
            warning('clean_rawdata returned empty; step skipped.');
        end
    else
        warning('clean_rawdata not found -> step skipped.');
    end
    EEG = eeg_checkset(EEG);

    %% === 3) Remove extremely noisy channels (p2p > 2200 µV) ===
    p2p_thresh = 2200;
    badchans = [];
    for ch = 1:EEG.nbchan
        p2p = max(EEG.data(ch,:)) - min(EEG.data(ch,:));
        if p2p > p2p_thresh
            badchans(end+1) = ch; %#ok<AGROW>
        end
    end
    if ~isempty(badchans)
        fprintf('Removing channels (p2p > %d µV): ', p2p_thresh);
        disp({EEG.chanlocs(badchans).labels});
        EEG = pop_select(EEG, 'nochannel', {EEG.chanlocs(badchans).labels});
    end
    EEG = eeg_checkset(EEG);

    %% === 4) Filtering & Notch (no re-reference) ===
    fprintf('Data assumed already referenced to Fz. No re-referencing applied.\n');
    EEG = pop_eegfiltnew(EEG, 0.1, 30);            % 0.1–30 Hz bandpass
    EEG = pop_eegfiltnew(EEG, 49, 51, [], 1);      % Notch 50 Hz
    EEG = eeg_checkset(EEG);

    %% === 5) ICA (runica) ===
    EEG = pop_runica(EEG, 'icatype','runica');
    EEG = eeg_checkset(EEG);

    %% === 6) Select writable output directory (robust fallback) ===
    candidates = {};
    if nargin >= 3 && ischar(preferredOutDir) && ~isempty(preferredOutDir)
        candidates{end+1} = preferredOutDir;
    end
    homeDir = getenv('HOME');
    candidates{end+1} = fullfile(homeDir,'Documents','MATLAB','EEG_afterICA');
    candidates{end+1} = fullfile(pwd,'EEG_afterICA');
    candidates{end+1} = fullfile(tempdir,'EEG_afterICA');

    outDir = first_writable_dir(candidates);
    fprintf('Selected output directory: %s\n', outDir);

    %% === 7) SINGLE save after ICA (before IC rejection) ===
    setPath = fullfile(outDir, [outBaseName '.set']);
    if exist(setPath,'file'), delete(setPath); end

    % Try 1: .set "onefile"
    try
        EEG = pop_saveset(EEG, 'filename', [outBaseName '.set'], ...
                                'filepath', outDir, ...
                                'savemode','onefile', ...
                                'version','7.3');
        fprintf('Saved after ICA (.set onefile): %s\n', setPath);
    catch ME1
        warning('pop_saveset onefile failed: %s', ME1.message);
        % Try 2: .set "twofiles"
        try
            EEG = pop_saveset(EEG, 'filename', [outBaseName '.set'], ...
                                    'filepath', outDir, ...
                                    'version','7.3'); % default twofiles
            fprintf('Saved after ICA (.set twofiles): %s\n', setPath);
        catch ME2
            warning('pop_saveset twofiles failed: %s', ME2.message);
            % Final fallback: .mat -v7.3
            matPath = fullfile(outDir, [outBaseName '.mat']);
            try
                save(matPath, 'EEG', '-v7.3');
                fprintf('Saved as MAT (fallback): %s\n', matPath);
            catch ME3
                error('Unable to write file in any candidate directory.\nLast error: %s', ME3.message);
            end
        end
    end

    %% === 8) Open IC inspection window (no rejection here) ===
    try
        nIC = size(EEG.icaweights,1);
        pop_selectcomps(EEG, 1:min(35,nIC));
    catch
        warning('Cannot open pop_selectcomps (ICA missing or GUI unavailable).');
    end
end

%% ===== Helper functions =====
function outDir = first_writable_dir(candidates)
    for i = 1:numel(candidates)
        d = candidates{i};
        if ~exist(d,'dir'), mkdir(d); end
        if can_write(d)
            outDir = d;
            return;
        end
    end
    outDir = pwd;
    if ~can_write(outDir)
        error('No writable candidate directories found (macOS permissions?).');
    end
end

function tf = can_write(d)
    tf = false;
    try
        testFile = fullfile(d, sprintf('.write_test_%s.tmp', char(java.util.UUID.randomUUID)));
        fid = fopen(testFile,'w');
        if fid ~= -1
            fwrite(fid, 'ok');
            fclose(fid);
            delete(testFile);
            tf = true;
        end
    catch
        tf = false;
    end
end
