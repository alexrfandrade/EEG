% File name
filename = 'processed_notch50Hz_fullsignal.set';
filepath = 'C:\Users\solen\Documents\Lisbonne\stage\3sept\withoutsound'; %Insert your filepath

% Load the dataset
EEG = pop_loadset('filename', filename, 'filepath', filepath);
disp(EEG);

% Show 1 channel
figure;
plot(EEG.times, squeeze(EEG.data(1,:,1))); %modify the first number to select the nth channel ,modify the last number to have the nth epochs
xlabel('Time (ms)');
ylabel('Amplitude (µV)');
title(['Channel : ' EEG.chanlocs(1).labels]);

% Show all channels
figure;
plot(EEG.times, squeeze(EEG.data(:,:,1))'); %modify the 3rd number to have the nth epochs
xlabel('Time (ms)');
ylabel('Amplitude (µV)');
title('All the channels - first epoch');