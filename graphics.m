function graphics(data_filt, coefs, t, onset_sample, N2, P3, fs)
% GRAPHICS - Plot EEG segment with N2/P3 markers and CWT envelope
%
% INPUTS:
%   data_filt    - Baseline-corrected EEG segment (µV)
%   coefs        - CWT coefficients (1–17 Hz)
%   t            - Time vector (s), relative to segment start
%   onset_sample - Stimulus onset in samples (relative to segment)
%   N2           - Detected N2 index in segment
%   P3           - Detected P3 index in segment
%   fs           - Sampling frequency (Hz)

% Time of stimulus onset in seconds (should be 0 in baseline-corrected)
onset_t = 0;

% Convert indices to latency relative to stimulus onset
N2_lat = (N2 - round(0.2*fs)) / fs; % relative to 0 s
P3_lat = (P3 - round(0.2*fs)) / fs;

% Display window: -200 ms to +800 ms around stimulus
t_start = -0.2; 
t_end   = 0.8;
plot_idx = t >= t_start & t <= t_end;

% --- Plot EEG segment ---
subplot(2,1,1)
plot(t(plot_idx), data_filt(plot_idx), 'k', 'LineWidth', 1.5)
hold on
y_limits = ylim;

% Add N2/P3 markers if detected
if N2 > 0
    line([N2_lat N2_lat], y_limits, 'Color','g','LineStyle','--','LineWidth',1.5)
    text(N2_lat, y_limits(2), sprintf('N2: %.3f s', N2_lat), ...
         'Color','g','VerticalAlignment','top','FontWeight','bold')
end
if P3 > 0
    line([P3_lat P3_lat], y_limits, 'Color','b','LineStyle','--','LineWidth',1.5)
    text(P3_lat, y_limits(2), sprintf('P3: %.3f s', P3_lat), ...
         'Color','b','VerticalAlignment','top','FontWeight','bold')
end
xlabel('Time (s)')
ylabel('EEG (µV)')
title('EEG segment (baseline-corrected)')
xlim([t_start t_end])
grid on
hold off

% --- Plot CWT envelope ---
subplot(2,1,2)
env = mean(abs(coefs),1);
plot(t(plot_idx), env(plot_idx), 'm', 'LineWidth', 1.5)
xlabel('Time (s)')
ylabel('CWT envelope')
title('CWT coefficients (1–17 Hz)')
xlim([t_start t_end])
grid on

end
