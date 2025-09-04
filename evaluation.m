function [results] = evaluation(N2, P3, fs)
% EVALUATION - Single-trial P300 detection scoring
%
% INPUTS:
%   N2 : Index of N2 relative to stimulus onset (0 if not detected)
%   P3 : Index of P3 relative to stimulus onset (0 if not detected)
%   fs : Sampling frequency (Hz)
%
% OUTPUT:
%   results : Scoring for the trial
%             0 = no detection / incorrect
%             1 = correct detection
%             2 = semi-correct detection (latencies slightly off or too close)

    % Define expected latency windows (samples relative to onset)
    N2_min = round(0.18*fs);  % 180 ms
    N2_max = round(0.30*fs);  % 300 ms
    P3_min = round(0.30*fs);  % 300 ms
    P3_max = round(0.60*fs);  % 600 ms

    if N2 == 0 || P3 == 0
        % No peaks detected
        results = 0;
    elseif (N2 >= N2_min && N2 <= N2_max) && (P3 >= P3_min && P3 <= P3_max)
        % Both peaks in expected latency ranges
        if (P3 - N2 < round(0.10*fs))  % <100 ms → too close
            results = 2;  % semi-correct
        else
            results = 1;  % correct
        end
    else
        % Peaks detected but outside expected latency windows
        results = 2;  % semi-correct
    end
end
