% Trigger script for self-paced finger press
%% Clear variables
clear all; clc

%% Initialize parallel port for EEG trigger

s = serial('COM3'); %insert your COM
set(s, 'BaudRate', 115200, 'DataBits', 8, 'Parity', 'none','StopBits', 1, 'FlowControl', 'none', 'Terminator', '');%Standard set up
fopen(s);
fprintf(s,'RR');
pause(1);
a = 1
fprintf(s, '%02X', a);
%<My Stimulus Image Shown Here>
a = 0
fprintf(s, '%02X', a);
fclose(s)
delete(s)
clear s

% CONNECTION
% Create a serial port connection to the EEG device on COM3 with baud rate 115200
eegPort = serialport("COM3", 115200, 'DataBits', 8, 'Parity', 'none', ...
                     'StopBits', 1, 'FlowControl', 'none');
configureTerminator(eegPort, "CR/LF");

% Create a file to save the timestamps
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
filename = ['trigger_log_' timestamp '.txt'];
logFile = fopen(filename, 'w');
fprintf(logFile, 'Key/Click\tTrigger\tTime (s)\n'); % Header line in the log file
fprintf(eegPort, "TRIGGER00"); % Send an initial "reset" trigger to indicate resting state
startTime = tic; % start a timer

% Setup Psychtoolbox Keyboard
KbName('UnifyKeyNames');
escapeKey = KbName('ESCAPE');

% MAIN LOOP: Wait for key presses and send triggers
while true
    % Check keyboard press
    [keyIsDown, ~, keyCode] = KbCheck;
    tNow = toc(startTime); %get the timestamp

    if keyIsDown
        keysPressed = find(keyCode);
        keyCodeVal = keysPressed(1);  % Take first pressed key

        if keyCodeVal == escapeKey % ESC button for exit loop
            disp('End');
            break;
        end

        % Convert keyCodeVal to 2 digit hex string 
        triggerValue = mod(keyCodeVal, 256);
        triggerHex = sprintf('%02X', triggerValue);
        triggerStr = sprintf('TRIGGER%s', triggerHex);
        
        % Send trigger to EEG device
        fprintf(eegPort, triggerStr);
        pause(0.003); % Short pause (3 ms)
        fprintf(eegPort, 'TRIGGER00'); % reset

        keyName = KbName(keyCodeVal);
        if iscell(keyName)
            keyName = keyName{1};
        end
        
        % Show the events
        disp(['Key pressed : ', keyName, ...
              ' → Trigger : ', triggerStr, ...
              ' → Time : ', num2str(tNow, '%.3f'), ' s']);

        % Log the event to file
        fprintf(logFile, '%s\t%s\t%.6f\n', keyName, triggerStr, tNow);

        % Wait until key is released to avoid multiple triggers
        while KbCheck
            % Do nothing
        end
    else
        % Check mouse click
        % GetClicks returns [x y buttonNumber]
        [x, y, button] = GetClicks([], 0);
        if button > 0
            switch button
                case 1
                    clickLabel = 'LeftClick'; code = 1;
                case 2
                    clickLabel = 'RightClick'; code = 2;
                case 3
                    clickLabel = 'MiddleClick'; code = 3;
                otherwise
                    clickLabel = 'OtherClick'; code = 0;
            end
        
            % Convert keyCodeVal to 2 digit hex string
            triggerValue = mod(code, 256);
            triggerHex = sprintf('%02X', triggerValue);
            triggerStr = sprintf('TRIGGER%s', triggerHex);
        
            % Send trigger to EEG device
            fprintf(eegPort, triggerStr);
            pause(0.003);
            fprintf(eegPort, 'TRIGGER00');

            disp(['Clic : ', clickLabel, ...
                  ' → Trigger : ', triggerStr, ...
                  ' → Temps : ', num2str(tNow, '%.3f'), ' s']);
            fprintf(logFile, '%s\t%s\t%.6f\n', clickLabel, triggerStr, tNow);
        end
    end

    WaitSecs(0.01);  % Small delay to reduce CPU load
end

fclose(logFile);
clear eegPort;