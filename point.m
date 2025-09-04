function [N2, P3, data_filt, t, coefs] = point(data_segment, fs)
% POINT - Single-trial N2/P3 detection with threshold at 0 µV
%
% INPUTS:
%   data_segment : 1 x N vector (single channel segment, [-0.2; +0.8] s)
%   fs           : Sampling frequency (Hz)
%
% OUTPUTS:
%   N2       : Index of detected N2 within the segment (0 if none)
%   P3       : Index of detected P3 within the segment (0 if none)
%   data_filt: Filtered EEG segment (µV)
%   t        : Time vector (s)
%   coefs    : CWT coefficients (1–17 Hz)

    % Ensure row vector
    x_segment = data_segment(:).';  
    N = numel(x_segment);
    t = linspace(-0.2, 0.8, N);  % Time vector

    % ---- Gentle low-pass filter ~30 Hz ----
    d = designfilt('lowpassiir','FilterOrder',4, ...
                   'HalfPowerFrequency',30,'SampleRate',fs);
    data_filt = filtfilt(d, x_segment);

    % ---- Baseline correction ----
    baseline_idx = t >= -0.2 & t <= 0;
    baseline = mean(data_filt(baseline_idx));
    data_filt = data_filt - baseline;

    % ---- CWT for low-frequency envelope (1–17 Hz) ----
    [c, frq] = cwt(data_filt, fs);
    keep = frq >= 1 & frq <= 17;
    coefs = c(keep, :);

    % ---- Time windows (s) ----
    winN2 = [0.15 0.30];   % expected N2
    winP3 = [0.30 0.60];   % expected P3
    N2_range = find(t >= winN2(1) & t <= winN2(2));
    P3_range = find(t >= winP3(1) & t <= winP3(2));

    % ---- Candidate N2 (local minima, < 0 µV) ----
    sig_n = -data_filt;  % invert for minima
    [~, indN] = findpeaks(sig_n);
    indN = indN(indN >= min(N2_range) & indN <= max(N2_range));
    indN = indN(data_filt(indN) < 0);  % threshold = 0 µV

    % ---- Candidate P3 (local maxima, > 0 µV) ----
    [~, indP] = findpeaks(data_filt);
    indP = indP(indP >= min(P3_range) & indP <= max(P3_range));
    indP = indP(data_filt(indP) > 0);   % threshold = 0 µV

    % ---- Check if candidates exist ----
    if isempty(indN) || isempty(indP)
        N2 = 0; P3 = 0;
        return;
    end

    % ---- Pairing N2-P3 ----
    sep_min = round(0.10 * fs);   % 100 ms
    sep_max = round(0.45 * fs);   % 450 ms

    bestScore = -Inf;
    N2 = 0; P3 = 0;

    for jn = 1:numel(indN)
        n = indN(jn);
        for jp = 1:numel(indP)
            p = indP(jp);
            if p <= n, continue; end
            sep = p - n;
            if sep < sep_min || sep > sep_max, continue; end

            % Score = amplitude P3 + |N2| + Gaussian weighting on latency
            lat_ms = (sep*1000)/fs;
            w = exp(-0.5*((lat_ms-200)/40).^2); % target delay ~200 ms
            score = data_filt(p) + abs(data_filt(n)) + 5*w;

            if score > bestScore
                bestScore = score;
                N2 = n;
                P3 = p;
            end
        end
    end

    % ---- Fallback if nothing valid ----
    if bestScore == -Inf
        N2 = 0;
        P3 = 0;
    end
end
