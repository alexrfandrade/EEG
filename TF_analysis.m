%% === Load the cleaned EEG dataset ===
EEG = pop_loadset('/Users/iristhouard/Documents/MATLAB/codes/P300/Preprocessing_Pipeline/EEG_afterICA/propre.set'); % load cleaned EEG

%% === Define parameters ===
epoch_time = [-0.2 1];           % epoch window in seconds
baseline    = [-200 0];          % baseline in ms
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
freqs   = 1:1:40;                % frequency range for STFT

% STFT parameters
win_len = round(0.2*fs);         % 200 ms window
overlap = round(0.9*win_len);    % 90% overlap

%% === Compute Time-Frequency using STFT ===
for i = 1:length(electrodes)
    chanIdx = find(strcmpi({EEG.chanlocs.labels}, electrodes{i}));
    if isempty(chanIdx), continue; end
    
    % Extract data (trials averaged)
    sig_odd = mean(squeeze(EEG_odd.data(chanIdx,:,:)),2); % average across trials
    sig_std = mean(squeeze(EEG_std.data(chanIdx,:,:)),2);
    
    % STFT (spectrogram)
    [~,F,T,Podd] = spectrogram(sig_odd,win_len,overlap,freqs,fs,'yaxis');
    [~,~,~,Pstd] = spectrogram(sig_std,win_len,overlap,freqs,fs,'yaxis');
    
    % Convert time axis T (s) into ms relative to epoch start
    Tms = (T + epoch_time(1)) * 1000;
    
    % Plot
    figure('Color','w','Name',['STFT - ' electrodes{i}]);
    subplot(1,2,1);
    imagesc(Tms,F,10*log10(Pstd)); axis xy;
    xlabel('Time (ms)'); ylabel('Freq (Hz)');
    title(['Standard - ' electrodes{i}]); colorbar;
    xlim([-200 1000]); ylim([0 40]);
    
    subplot(1,2,2);
    imagesc(Tms,F,10*log10(Podd)); axis xy;
    xlabel('Time (ms)'); ylabel('Freq (Hz)');
    title(['Oddball - ' electrodes{i}]); colorbar;
    xlim([-200 1000]); ylim([0 40]);
    
    if save_figs
        saveas(gcf, fullfile(outdir, sprintf('STFT_%s.png', electrodes{i})));
    end
end

%% === Compute Time-Frequency using Wavelet Transform (amor) ===
for i = 1:length(electrodes)
    chanIdx = find(strcmpi({EEG.chanlocs.labels}, electrodes{i}));
    if isempty(chanIdx), continue; end
    
    % Extract averaged signals
    sig_odd = mean(squeeze(EEG_odd.data(chanIdx,:,:)),2);
    sig_std = mean(squeeze(EEG_std.data(chanIdx,:,:)),2);
    
    % Continuous wavelet transform with Morlet
    [cfs_odd,Fodd] = cwt(sig_odd,fs,'amor');
    [cfs_std,Fstd] = cwt(sig_std,fs,'amor');
    
    % Plot
    figure('Color','w','Name',['Wavelet - ' electrodes{i}]);
    subplot(1,2,1);
    surface(times,Fstd,abs(cfs_std)); shading interp; axis tight; set(gca,'YScale','log');
    xlabel('Time (ms)'); ylabel('Freq (Hz)');
    title(['Standard - ' electrodes{i}]); colorbar;
    xlim([-200 700]); ylim([0 35]);
    
    subplot(1,2,2);
    surface(times,Fodd,abs(cfs_odd)); shading interp; axis tight; set(gca,'YScale','log');
    xlabel('Time (ms)'); ylabel('Freq (Hz)');
    title(['Oddball - ' electrodes{i}]); colorbar;
    xlim([-200 700]); ylim([0 35]);
    
    if save_figs
        saveas(gcf, fullfile(outdir, sprintf('Wavelet_%s.png', electrodes{i})));
    end
end

%% === Group-level Topography of TF differences ===
% Example: average Odd-Std power in theta (4-7 Hz) and P300 window (300–450 ms)

freq_band = [4 12]; time_win = [200 450];
[~,t1] = min(abs(times-time_win(1))); [~,t2] = min(abs(times-time_win(2)));

theta_diff = zeros(1,EEG.nbchan);
for ch=1:EEG.nbchan
    sig_odd = mean(squeeze(EEG_odd.data(ch,:,:)),2);
    sig_std = mean(squeeze(EEG_std.data(ch,:,:)),2);
    [cfs_odd,F] = cwt(sig_odd,fs,'amor');
    [cfs_std,~] = cwt(sig_std,fs,'amor');

    idxF = find(F>=freq_band(1) & F<=freq_band(2));
    pow_odd = mean(abs(cfs_odd(idxF,t1:t2)),[1 2]);
    pow_std = mean(abs(cfs_std(idxF,t1:t2)),[1 2]);
    theta_diff(ch) = pow_odd - pow_std;
end

figure('Color','w');
topoplot(theta_diff, EEG.chanlocs,'electrodes','labels','style','map','colormap',flipud(jet));
colorbar;
title(sprintf('Odd-Std TF diff [%d-%d ms, %d-%d Hz]',time_win(1),time_win(2),freq_band(1),freq_band(2)));
