%% === Load Unicorn EEG and behavioral events ===
filename = '/Users/iristhouard/Documents/MATLAB/codes/P300/resultats_uni/records/UnicornRecorder_26_08_2025_14_31_150.csv';
fs = 250;  % Unicorn sampling rate
filename_results = '/Users/iristhouard/Documents/MATLAB/codes/P300/resultats_uni/records/results_oddball_block1_20250826_143417.csv';

datastruct = unicornrecorder_read_csv(filename, fs);
time = (0:datastruct.numberOfSamples-1)/fs;

% Align to first trigger
t0_idx   = find(datastruct.trig, 1);
time_rel = time(t0_idx:end);
EEG_rel  = datastruct.data(t0_idx:end,:);

% Load behavioral events (times in seconds relative to t0)
[oddball_tbl, standard_tbl] = read_csv(filename_results, time_rel);

%% === Parameters ===
epoch_time = [-0.2 1];   % in seconds
baseline   = [-0.2 0];   % baseline window
electrodes = [3 7 9 11]; % channel indices (adapt Pz, P3, P4, Cz equivalent)
alpha      = 0.05;
save_figs  = true;
outdir = fullfile(pwd,'ERP_results');
if ~exist(outdir,'dir'), mkdir(outdir); end

%% === Epoch extraction (manual, since not EEGLAB .set) ===
nChan = size(EEG_rel,2);
epoch_len = round(diff(epoch_time)*fs);
tvec = (epoch_time(1):1/fs:epoch_time(2)) * 1000; % ms

% helper function to epoch around events
function epochs = make_epochs(EEG_rel, events, fs, epoch_time)
    nChan = size(EEG_rel,2);
    preSamp = round(abs(epoch_time(1))*fs);
    postSamp = round(epoch_time(2)*fs);
    nSamp = preSamp + postSamp + 1;
    epochs = [];
    for e = 1:length(events)
        center_idx = round(events(e)*fs);
        idx = (center_idx-preSamp):(center_idx+postSamp);
        if idx(1)>0 && idx(end)<=size(EEG_rel,1)
            epochs(:,:,end+1) = EEG_rel(idx,:); %#ok<AGROW>
        end
    end
end

% Epoch oddball & standard
epochs_odd = make_epochs(EEG_rel, oddball_tbl, fs, epoch_time);
epochs_std = make_epochs(EEG_rel, standard_tbl, fs, epoch_time);

% Baseline correction
function epochs_out = baseline_correct(epochs, fs, epoch_time, baseline)
    tvec = (epoch_time(1):1/fs:epoch_time(2));
    b_idx = tvec>=baseline(1) & tvec<=baseline(2);
    mean_base = mean(epochs(b_idx,:,:),1);
    epochs_out = epochs - mean_base;
end

epochs_odd = baseline_correct(epochs_odd, fs, epoch_time, baseline);
epochs_std = baseline_correct(epochs_std, fs, epoch_time, baseline);

%% === Compute ERPs ===
ERP_odd = mean(epochs_odd,3);
ERP_std = mean(epochs_std,3);

%% === ERP plotting + t-tests ===
for i = 1:length(electrodes)
    chanIdx = electrodes(i);
    data_odd = squeeze(epochs_odd(:,chanIdx,:))'; % trials x time
    data_std = squeeze(epochs_std(:,chanIdx,:))';
    
    nPoints = size(data_odd,2);
    pvals = zeros(1,nPoints);
    tvals = zeros(1,nPoints);
    for t = 1:nPoints
        [~, p, ~, stats] = ttest2(data_odd(:,t), data_std(:,t));
        pvals(t) = p; tvals(t) = stats.tstat;
    end
    p_corrected = pvals * nPoints;
    sig_mask = p_corrected < alpha;
    
    % Plot
    figure('Color','w'); hold on;
    plot(tvec, mean(data_std,1),'b','LineWidth',1.5);
    plot(tvec, mean(data_odd,1),'r','LineWidth',1.5);
    ylims = ylim;
    sig_y = ylims(1) - 0.1*(ylims(2)-ylims(1));
    plot(tvec(sig_mask), sig_y*ones(1,sum(sig_mask)),'k.','MarkerSize',10);
    
    xlabel('Time (ms)'); ylabel('Amplitude (µV)');
    title(sprintf('ERP + t-test - Ch%d (nOdd=%d, nStd=%d)', ...
        chanIdx, size(data_odd,1), size(data_std,1)));
    legend({'Standard','Oddball','Significant (p<0.05 corr.)'});
    grid on; xlim([tvec(1) tvec(end)]);
    
    if save_figs
        saveas(gcf, fullfile(outdir, sprintf('ERP_ttest_Ch%d.png', chanIdx)));
    end
end
