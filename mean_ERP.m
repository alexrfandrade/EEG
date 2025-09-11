%% === Load the cleaned EEG dataset ===
EEG = pop_loadset('/Users/iristhouard/Documents/MATLAB/codes/P300/EEG_afterICA/propre.set'); % load cleaned EEG after IC rejection

%% === Define parameters ===
epoch_time = [-0.2 1];                 % epoch window in seconds
baseline    = [-200 0];                % baseline window in ms
electrodes  = {'Pz','P3','P4','Cz'};   % electrodes of interest
alpha       = 0.05;                    % significance level
save_figs   = true;                    % whether to save figures
outdir = fullfile(pwd,'ERP_results');  % output folder
if ~exist(outdir,'dir'), mkdir(outdir); end % create folder if missing

%% === Epoch for Oddball (event type = '1') ===
EEG_odd = pop_epoch(EEG, {'1'}, epoch_time, 'epochinfo', 'yes'); % extract oddball epochs
EEG_odd = pop_rmbase(EEG_odd, baseline);                        % remove baseline

%% === Epoch for Standard (event type = '0') ===
EEG_std = pop_epoch(EEG, {'0'}, epoch_time, 'epochinfo', 'yes'); % extract standard epochs
EEG_std = pop_rmbase(EEG_std, baseline);                        % remove baseline

%% === Compute mean ERPs ===
ERP_odd = mean(EEG_odd.data, 3); % nChannels x nPoints
ERP_std = mean(EEG_std.data, 3);

%% === Prepare time axis ===
times = EEG_odd.times; % in ms

%% === ERP plotting with t-test (single electrodes) + display t-test differences and mean difference ===
for i = 1:length(electrodes)
    chanIdx = find(strcmpi({EEG.chanlocs.labels}, electrodes{i}));
    if isempty(chanIdx)
        warning(['Electrode ' electrodes{i} ' not found.']);
        continue
    end
    
    % Extract trial data for each condition
    data_odd = squeeze(EEG_odd.data(chanIdx,:,:))'; % trials x time
    data_std = squeeze(EEG_std.data(chanIdx,:,:))';
    
    % Compute t-test at each time point
    nPoints = size(data_odd,2);
    pvals = zeros(1,nPoints);
    tvals = zeros(1,nPoints);
    for t = 1:nPoints
        [~, p, ~, stats] = ttest2(data_odd(:,t), data_std(:,t));
        pvals(t) = p;
        tvals(t) = stats.tstat;
    end
    
    % Bonferroni correction for multiple comparisons
    p_corrected = pvals * nPoints;
    sig_mask = p_corrected < alpha;
    
    %% === Display significant time points, t-values, and mean difference ===
    sig_times = times(sig_mask);
    sig_tvals = tvals(sig_mask);
    
    if ~isempty(sig_times)
        fprintf('\nElectrode: %s\n', electrodes{i});
        fprintf('Significant differences (p<%.2f, Bonferroni corrected):\n', alpha);
        for k = 1:length(sig_times)
            % Compute mean amplitude difference at this time point
            idx_time = find(times == sig_times(k));
            mean_diff_k = mean(data_odd(:,idx_time)) - mean(data_std(:,idx_time));
            
            fprintf('Time: %.1f ms, t = %.3f, Mean difference = %.3f µV\n', ...
                sig_times(k), sig_tvals(k), mean_diff_k);
        end
    else
        fprintf('\nElectrode: %s - No significant differences detected (p<%.2f corrected)\n', electrodes{i}, alpha);
    end
    
    % Plot ERP for oddball vs standard
    figure('Color','w'); hold on;
    plot(times, mean(data_std,1),'b','LineWidth',1.5);
    plot(times, mean(data_odd,1),'r','LineWidth',1.5);
    
    % Mark significant time points
    ylims = ylim;
    sig_y = ylims(1) - 0.1*(ylims(2)-ylims(1)); % below the waveform
    plot(times(sig_mask), sig_y*ones(1,sum(sig_mask)),'k.','MarkerSize',10);
    
    xlabel('Time (ms)'); ylabel('Amplitude (µV)');
    title(sprintf('ERP + t-test - %s (nOdd=%d, nStd=%d)', electrodes{i}, size(data_odd,1), size(data_std,1)));
    legend({'Standard','Oddball','Significant (p<0.05 corr.)'});
    grid on; xlim([times(1) times(end)]);
    
    if save_figs
        saveas(gcf, fullfile(outdir, sprintf('ERP_ttest_%s.png', electrodes{i})));
    end
end
