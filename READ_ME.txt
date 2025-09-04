The analysis pipeline is organized around five main MATLAB files. 
The entry point is main_Uni.m, which loads both the EEG recording (from Unicorn) 
and the behavioral results (from the oddball task). These data are parsed using unicornrecorder_read_csv.m, 
a dedicated function that extracts EEG signals and triggers from the Unicorn .csv files, and read_csv.m, 
which imports and aligns the behavioral events. Once the data are loaded and synchronized, 
ERP_plot.m can be used to segment the EEG into epochs, apply baseline correction, and compute 
averaged ERPs separately for oddball and standard trials, displaying the classical P300 waveform. 
Finally, the extended script TF_analysis.m (the new function you added) provides time–frequency analyses, 
including Short-Time Fourier Transform (STFT) and wavelet decomposition, and computes group-level differences 
in oscillatory activity between conditions. Together, these five files allow the user to go from raw 
Unicorn recordings to both ERP and time–frequency characterizations of the P300 response.