EEG Analysis Pipeline README

This repository contains five MATLAB scripts for EEG preprocessing, visualization, and ERP analysis, based on data recorded with BrainVision.

1. raw_EEG.m
   This script loads the raw EEG data (.vhdr) and allows initial visualization using FieldTrip. It helps inspect the signals, check for noisy channels, and identify gross artifacts before any preprocessing. No ICA or saving is performed in this step.

2. main_preprocessing.m
   This script performs full preprocessing up to ICA. It converts FieldTrip data to EEGLAB format, cleans channels, filters the data, and computes ICA. After running this script, the user must manually inspect and reject bad independent components in EEGLAB, then save the cleaned dataset as 'cleaned.set'.

3. preprocPipeline_afterICA.m
   This function encapsulates the preprocessing pipeline in a reusable format. It performs the same steps as main_preprocessing.m and saves the ICA-processed dataset. Users still need to manually reject ICs and save the cleaned .set file for further analysis.

4. mean_ERP.m
   This script loads the cleaned EEG dataset (.set), epochs the data around oddball (1) and standard (0) events, computes average ERPs and SEM or 95% CI, and plots ERP waveforms per electrode and multi-electrode comparisons. It also plots topographies of the oddball-standard difference.

5. TF_analysis.m
    This script do the Time-Trequency analysis on both standard an oddball epochs from mean_ERP.m. Wavelet and STFT are done on the data.
Recommended workflow:
1. Use raw_EEG.m to inspect the raw EEG.
2. Run main_preprocessing.m or call preprocPipeline_afterICA.m to preprocess and compute ICA.
3. Manually reject bad ICs in EEGLAB and save as cleaned.set.
4. Use mean_ERP.m to compute and visualize trial-averaged ERPs .
5. Use TF_analysis.m to compute and visualize TF representations and topographic maps.