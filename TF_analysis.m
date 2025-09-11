%% === Load the cleaned EEG dataset ===
EEG = pop_loadset('/Users/iristhouard/Documents/MATLAB/codes/P300/EEG_afterICA/propre.set');

%% === Define parameters ===
epoch_time = [-0.2 1];               % epoch window in seconds
baseline    = [-200 0];              % baseline in ms (only for pop_rmbase)
electrodes  = {'Pz','P3','P4','Cz'}; % electrodes of interest
save_figs   = true;
outdir = fullfile(pwd,'TF_results');
if ~exist(outdir,'dir'), mkdir(outdir); end

%% === Epoch Oddball & Standard ===
EEG_odd = pop_epoch(EEG, {'1'}, epoch_time, 'epochinfo', 'yes');
EEG_odd = pop_rmbase(EEG_odd, baseline);

EEG_std = pop_epoch(EEG, {'0'}, epoch_time, 'epochinfo', 'yes');
EEG_std = pop_rmbase(EEG_std, baseline);

%% === Parameters for TF analysis ===
fs      = EEG.srate;             % sampling rate
times   = EEG_odd.times;         % ms
freqs   = 1:1:40;                % frequency range for STFTfi([], 1, 16)

% STFT parameters
win_len = round(0.2*fs);         % 200 ms window
overlap = round(0.9*win_len);    % 90% overlap

%% === Time-Frequency analysis with STFT (linear scale, no baseline normalization) ===
for i = 1:length(electrodes)
    chanIdx = find(strcmpi({EEG.chanlocs.labels}, electrodes{i}));
    if isempty(chanIdx), continue; end

    % Extract data (average across trials)
    sig_odd = mean(squeeze(EEG_odd.data(chanIdx,:,:)),2);
    sig_std = mean(squeeze(EEG_std.data(chanIdx,:,:)),2);

    % Compute spectrogram (STFT)
    [~,F,T,Podd] = spectrogram(sig_odd,win_len,overlap,freqs,fs,'yaxis');
    [~,~,~,Pstd] = spectrogram(sig_std,win_len,overlap,freqs,fs,'yaxis');

    % Convert time axis T (s) into ms relative to epoch start
    Tms = (T + epoch_time(1)) * 1000;

    % Plot raw power spectrograms
    figure('Color','w','Name',['STFT - ' electrodes{i}]);
    subplot(1,2,1);
    imagesc(Tms,F,Pstd); axis xy;
    xlabel('Time (ms)'); ylabel('Frequency (Hz)');
    title(['Standard - ' electrodes{i}]); colorbar;
    xlim([-200 1000]); ylim([0 40]);

    subplot(1,2,2);
    imagesc(Tms,F,Podd); axis xy;
    xlabel('Time (ms)'); ylabel('Frequency (Hz)');
    title(['Oddball - ' electrodes{i}]); colorbar;
    xlim([-200 1000]); ylim([0 40]);

    if save_figs
        saveas(gcf, fullfile(outdir, sprintf('STFT_%s_raw.png', electrodes{i})));
    end
end


%% === Time-Frequency analysis with Wavelet Transform (linear scale + cone of influence, raw power) ===
for i = 1:length(electrodes)
    chanIdx = find(strcmpi({EEG.chanlocs.labels}, electrodes{i}));
    if isempty(chanIdx), continue; end

    % Extract averaged signals
    sig_odd = mean(squeeze(EEG_odd.data(chanIdx,:,:)),2);
    sig_std = mean(squeeze(EEG_std.data(chanIdx,:,:)),2);

    % Compute Continuous Wavelet Transform (CWT) with Morlet
    [cfs_odd,Fodd,coi_odd] = cwt(sig_odd,fs,'amor'); % Oddball
    [cfs_std,Fstd,coi_std] = cwt(sig_std,fs,'amor'); % Standard

    % Convert to power
    pow_odd = abs(cfs_odd).^2;
    pow_std = abs(cfs_std).^2;

    % Convert COI to ms relative to epoch start
    coi_odd_ms = (coi_odd - 1)/fs*1000 + epoch_time(1)*1000;
    coi_std_ms = (coi_std - 1)/fs*1000 + epoch_time(1)*1000;

    % Plot Standard condition
    figure('Color','w','Name',['Wavelet - ' electrodes{i}]);
    subplot(1,2,1);
    surface(times,Fstd,pow_std); shading interp; axis tight;
    set(gca,'YScale','linear'); % linear frequency scale
    xlabel('Time (ms)'); ylabel('Frequency (Hz)');
    title(['Standard - ' electrodes{i}]); colorbar;
    xlim([-200 700]); ylim([0 35]);
    hold on;
    % Plot COI as a white dashed line at max frequency
    plot(coi_std_ms, Fstd(end)*ones(size(coi_std_ms)),'w--','LineWidth',2);

    % Plot Oddball condition
    subplot(1,2,2);
    surface(times,Fodd,pow_odd); shading interp; axis tight;
    set(gca,'YScale','linear'); % linear frequency scale
    xlabel('Time (ms)'); ylabel('Frequency (Hz)');
    title(['Oddball - ' electrodes{i}]); colorbar;
    xlim([-200 700]); ylim([0 35]);
    hold on;
    % Plot COI as a white dashed line at max frequency
    plot(coi_odd_ms, Fodd(end)*ones(size(coi_odd_ms)),'w--','LineWidth',2);

    if save_figs
        saveas(gcf, fullfile(outdir, sprintf('Wavelet_%s_raw_coi.png', electrodes{i})));
    end
end


%% === Group-level Topography of TF differences (theta/alpha band in P300 window, raw power) ===
freq_band = [4 12]; time_win = [200 450];
[~,t1] = min(abs(times-time_win(1))); [~,t2] = min(abs(times-time_win(2)));

theta_diff = zeros(1,EEG.nbchan);
for ch=1:EEG.nbchan
    sig_odd = mean(squeeze(EEG_odd.data(ch,:,:)),2);
    sig_std = mean(squeeze(EEG_std.data(ch,:,:)),2);
    [cfs_odd,F] = cwt(sig_odd,fs,'amor');
    [cfs_std,~] = cwt(sig_std,fs,'amor');

    pow_odd = abs(cfs_odd).^2;
    pow_std = abs(cfs_std).^2;

    % Extract power in freq/time band of interest
    idxF = find(F>=freq_band(1) & F<=freq_band(2));
    pow_band_odd = mean(pow_odd(idxF,t1:t2),[1 2]);
    pow_band_std = mean(pow_std(idxF,t1:t2),[1 2]);
    theta_diff(ch) = pow_band_odd - pow_band_std;
end

figure('Color','w');
topoplot(theta_diff, EEG.chanlocs,'electrodes','labels','style','map','colormap',flipud(jet));
colorbar;
title(sprintf('Odd-Std TF diff [%d-%d ms, %d-%d Hz]',time_win(1),time_win(2),freq_band(1),freq_band(2)));
