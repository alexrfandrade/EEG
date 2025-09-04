%% === Load Unicorn EEG and behavioral events ===

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

%% === Parameters ===
fs         = 250;               % Unicorn sampling rate
epoch_time = [-0.2 1];          % seconds
baseline   = [-0.2 0];          % seconds
electrodes = 1:8;               % 8 electrodes Unicorn
save_figs  = true;
alpha      = 0.05;

outdir = fullfile(pwd,'TF_results_Beatriz_1_block'); %name to adapt
if ~exist(outdir,'dir'), mkdir(outdir); end

%% === Load EEG ===
datastruct = unicornrecorder_read_csv(filename, fs);
time = (0:datastruct.numberOfSamples-1)/fs;

% align to first trigger
t0_idx   = find(datastruct.trig, 1);
time_rel = time(t0_idx:end);
EEG_rel  = datastruct.data(t0_idx:end,:);

% load behavioral results
[oddball_tbl, standard_tbl] = read_csv(filename_results, time_rel);

%% === Epoch extraction ===
nChan = size(EEG_rel,2);
preSamp  = round(abs(epoch_time(1))*fs);
postSamp = round(epoch_time(2)*fs);
nSamp    = preSamp + postSamp + 1;
tvec     = (epoch_time(1):1/fs:epoch_time(2))*1000; % ms

make_epochs = @(EEG,events) cell2mat(arrayfun(@(e) ...
    reshape(EEG((round(e*fs)-preSamp):(round(e*fs)+postSamp),:),[nSamp,nChan,1]), ...
    events(events*fs>preSamp & events*fs<(size(EEG,1)-postSamp)),'UniformOutput',false));

epochs_odd = make_epochs(EEG_rel, oddball_tbl);
epochs_std = make_epochs(EEG_rel, standard_tbl);

% baseline correction
baseline_idx = tvec>=baseline(1)*1000 & tvec<=baseline(2)*1000;
baseline_correct = @(epochs) epochs - mean(epochs(baseline_idx,:,:),1);

epochs_odd = baseline_correct(epochs_odd);
epochs_std = baseline_correct(epochs_std);

%% === Compute ERPs ===
ERP_odd = mean(epochs_odd,3);
ERP_std = mean(epochs_std,3);

%% === Time-Frequency analysis (STFT) ===
freqs   = 1:1:40;
win_len = round(0.2*fs); 
overlap = round(0.9*win_len);

for i = electrodes
    % averaged signals
    sig_odd = mean(squeeze(epochs_odd(:,i,:)),2);
    sig_std = mean(squeeze(epochs_std(:,i,:)),2);

    % --- STFT ---
    [~,F,T,Podd] = spectrogram(sig_odd,win_len,overlap,freqs,fs,'yaxis');
    [~,~,~,Pstd] = spectrogram(sig_std,win_len,overlap,freqs,fs,'yaxis');
    Tms = (T+epoch_time(1))*1000;

    figure('Color','w','Name',['STFT - Ch' num2str(i)]);
    subplot(1,2,1);
    imagesc(Tms,F,10*log10(Pstd)); axis xy;
    xlabel('Time (ms)'); ylabel('Frequency (Hz)'); 
    title(['Standard - Ch' num2str(i)]); 
    colorbar;
    xlim([-200 1000]); ylim([0 40]);

    subplot(1,2,2);
    imagesc(Tms,F,10*log10(Podd)); axis xy;
    xlabel('Time (ms)'); ylabel('Frequency (Hz)'); 
    title(['Oddball - Ch' num2str(i)]); 
    colorbar;
    xlim([-200 1000]); ylim([0 40]);

    if save_figs
        saveas(gcf, fullfile(outdir, sprintf('STFT_Ch%d.png',i)));
    end
end

%% === Wavelet (simpler version) ===
for i = electrodes
    sig_odd = mean(squeeze(epochs_odd(:,i,:)),2);
    sig_std = mean(squeeze(epochs_std(:,i,:)),2);

    % CWT Morlet
    [cfs_odd,Fodd] = cwt(sig_odd,fs,'amor');
    [cfs_std,Fstd] = cwt(sig_std,fs,'amor');

    figure('Color','w','Name',['Wavelet - Ch' num2str(i)]);

    subplot(1,2,1);
    surface(tvec,Fstd,abs(cfs_std)); 
    shading interp; axis tight; set(gca,'YScale','log');
    xlabel('Time (ms)'); ylabel('Frequency (Hz)');
    title(['Standard - Ch' num2str(i)]);
    colorbar; 
    xlim([-200 1000]); ylim([0 40]);

    subplot(1,2,2);
    surface(tvec,Fodd,abs(cfs_odd)); 
    shading interp; axis tight; set(gca,'YScale','log');
    xlabel('Time (ms)'); ylabel('Frequency (Hz)');
    title(['Oddball - Ch' num2str(i)]);
    colorbar;
    xlim([-200 1000]); ylim([0 40]);



    if save_figs
        saveas(gcf, fullfile(outdir, sprintf('Wavelet_Ch%d.png',i)));
    end
end

%% === Group-level TF difference (theta band in P300 window) ===
freq_band = [4 12]; time_win = [200 450];
[~,t1] = min(abs(tvec-time_win(1))); [~,t2] = min(abs(tvec-time_win(2)));

theta_diff = zeros(1,nChan);
for ch=1:nChan
    sig_odd = mean(squeeze(epochs_odd(:,ch,:)),2);
    sig_std = mean(squeeze(epochs_std(:,ch,:)),2);

    [cfs_odd,F] = cwt(sig_odd,fs,'amor');
    [cfs_std,~] = cwt(sig_std,fs,'amor');

    idxF = find(F>=freq_band(1) & F<=freq_band(2));
    pow_odd = mean(abs(cfs_odd(idxF,t1:t2)),[1 2]);
    pow_std = mean(abs(cfs_std(idxF,t1:t2)),[1 2]);
    theta_diff(ch) = pow_odd - pow_std;
end

figure('Color','w');
bar(theta_diff);
xlabel('Channel'); ylabel('Odd-Std Power diff');
title(sprintf('TF diff [%d-%d ms, %d-%d Hz]',time_win(1),time_win(2),freq_band(1),freq_band(2)));
