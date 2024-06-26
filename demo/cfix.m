function [times] = cfix(cfg)
%afix Summary of this function goes here
%   Detailed explanation goes here

    % docs say this call with (2) arg does the following:
    % AssertOpenGL();
    % KbName('UnifyKeyNames');
    % It also says that any time Screen('OpenWindow'....) is called, that 
    % the following call is implied:
    % Screen('ColorRange', window, 1, [], 1);
    PsychDefaultSetup(2);

    % Init dio, no reward
    cclabInitDIO('AB');

    %  kb stuff
    ListenChar(2); % disable kb input at matlab command window
    KbName('UnifyKeyNames');

    % Open window
    Screen('Preference', 'SkipSyncTests', cfg.SkipSyncTests);

    if cfg.doBitsPlusPlus
        InitializeMatlabOpenGL(1,3,1);
        BitsPlusPlus('SetColorConversionMode', 2);
        [wp, wrect] = BitsPlusPlus('OpenWindowColor++', cfg.screen_number, cfg.background_color, cfg.screen_rect);
        BitsPlusPlus('DIOCommand', wp, -1, 0, 255, trigData, 0, 1, 2);
    else

        % Thank you for this section: https://www.jennyreadresearch.com/research/lab-set-up/datapixx/
        AssertOpenGL;
        % Configure PsychToolbox imaging pipeline to use 32-bit floating point numbers.
        % Our pipeline will also implement an inverse gamma mapping to correct for display gamma.
        PsychImaging('PrepareConfiguration');
        PsychImaging('AddTask', 'General', 'FloatingPoint32Bit');
        PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'SimpleGamma');
        %oldVerbosity = Screen('Preference', 'Verbosity', 1); % Don%t log the GL stuff
        [wp, wrect] = PsychImaging('OpenWindow', cfg.screen_number, 255 * cfg.background_color);
        %Screen('Preference', 'Verbosity', oldVerbosity);
    end


    % eyelink
    % Get EyeLink default settings, make some updates. Note call to EyelinkUpdateDefauilts()
    el = EyelinkInitDefaults(wp);
    el.calibrationtargetsize = 5;% Outer target size as percentage of the screen
    el.calibrationtargetwidth = 0;% Inner target size as percentage of the screen
    el.backgroundcolour = [128 128 128];% RGB grey
    el.calibrationtargetcolour = [0 0 1];% RGB black
    el.msgfontcolour = [0 0 1];% RGB black
    EyelinkUpdateDefaults(el);

    myEyelinkInit(cfg, wp, 'aaa010');








% 
%     % Eyelink message, start of trial
%     Eyelink( 'Message', 'Trialstart');
%     %Start recording
%     Eyelink('StartRecording');
%     % Eyelink message, record trial number
%     Eyelink('Command', 'record_status_message "TRIAL %d "', trial_success);
% 
%     %Clear screen on eyelink machine
%     Eyelink('command','clear_screen %d', 0);



    trigData = zeros(1, 248);
    trigData(1, 1:10) = 32768;
    cfg.window_rect = wrect;

    pauseSec = 0.1;
    pulseWidth = 0.1; % ms
    maxStimFrames = 1000;
    iToggle = 0;
    stimLoopFrames = 4;
    bQuit = 0;
    bGo = 0;
    state = "WAIT_GO";
    tStateStart = -1;

    times = zeros(maxStimFrames, 4);

    fprintf('Enter ''g'' to go, ''q'' to quit.');
    while ~bQuit && state ~= "DONE"
    
        % Check kb each time 
        [keyIsDown, ~, keyCode] = KbCheck();
        
        % TODO kb handling
        bQuit = keyIsDown && keyCode(KbName('q'));
        bGo = keyIsDown && keyCode(KbName('g'));
        if bQuit
            state = "DONE";
            fprintf('got Q\n');
        end

        switch(state)
            case "WAIT_GO"
                if bGo
                    mylogger(cfg, "WAIT_GO: got go signal\n");
                    Eyelink('StartRecording');
                    nFrames = 0;
                    nSamples = 0;
                    state = "STIM";
                end
            case "STIM"
                nFrames = nFrames + 1;
                cclabPulse('A', pulseWidth);
                drawScreenNoFlip(cfg, wp, 255*mod(nFrames, 2));                

                times(nFrames, 1) = GetSecs();
                times(nFrames, 2) = Screen('Flip', wp);
                times(nFrames, 3) = GetSecs();
                Eyelink('Message', 'frame %d', nFrames);
                times(nFrames, 4) = GetSecs();
                cclabPulse('B', pulseWidth);

                if nFrames == maxStimFrames
                    state = "DONE";
                else
                    state = "PAUSE";
                end
            case "PAUSE"
                WaitSecs(pauseSec);
                state = "STIM";
            case "DONE"
                drawScreenNoFlip(cfg, wp, 0);
                Screen('Flip', wp);
                Eyelink('StopRecording');
            otherwise
                error("Unhandled state %s\n", state);
        end                                 
    end
    if cfg.doBitsPlusPlus
        BitsPlusPlus('DIOCommandReset', wp);
        BitsPlusPlus('Close');
    end
    ListenChar(0);
    sca;
    cclabCloseDIO();

    Eyelink('CloseFile');
    Eyelink('ReceiveFile');
    Eyelink('Shutdown');

end


function [tflip] = drawScreenNoFlip(cfg, wp, x)
    Screen('FillRect', wp, 255*cfg.background_color);
    if ~isempty(x) && isscalar(x)
        % rect for drawing photodiode square
        % 'center', 'left', 'right', 'top', and 'bottom'. 
        r=AlignRect(cfg.marker_rect ,cfg.window_rect, cfg.marker_rect_side1, cfg.marker_rect_side2);
        Screen('FillRect', wp, [x, x, x], r);
    end
end
    
function [] = mylogger(cfg, str)
    if cfg.verbose
        fprintf(str);
    end
end

function [] = myEyelinkInit(cfg, wp, filename)
%   try all this eyelink stuff
    EyelinkInit(cfg.dummymode); % Initialize EyeLink connection
    status = Eyelink('IsConnected');
    [ver, versionstring] = Eyelink('GetTrackerVersion');
    if ~cfg.dummymode
        if ~status
            % asked for connection but didn't get it
            error('Eyelink connection failed.');
        else
            fprintf('Eyelink (%s) is connected.\n', versionstring);
        end
    else
        if status < 0
            fprintf('Eyelink (%s) is dummy-connected.\n', versionstring);
        else
            fprintf('Eyelink (%s) should be in dummy mode, status is %d\n', versionstring, status);
        end
    end

%   Open EDF file
%   TODO: What happens when in dummy mode? Make sure this doesn't crash. 
    failOpen = Eyelink('OpenFile', filename);
    if failOpen
        error('Cannot create EDF file %s', filename);
    end


    Eyelink('Command', 'add_file_preamble_text "RECORDED BY Matlab %s session name: %s"', mfilename, filename);

    % Events for file and online
    Eyelink('Command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
    Eyelink('Command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,BUTTON,FIXUPDATE,INPUT');
    % specify data contained in each recorded event
    Eyelink('Command', 'file_event_data = GAZE,GAZERES,HREF,AREA,VELOCITY');
    Eyelink('Command', 'link_event_data = GAZE,GAZERES,HREF,AREA,FIXAVG,NOSTART');
    % Within samples, these things are recorded for each sample (I think)
    Eyelink('Command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,RAW,AREA,HTARGET,GAZERES,BUTTON,STATUS,INPUT');
    Eyelink('Command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,HTARGET,STATUS,INPUT');


    % BOILERPLATE CONFIG - HIDE THIS IN FINAL.INI OR ELSEWHERE? 


    % SCREEN physical size of viewing area and dist to eye
    Eyelink('Command','screen_phys_coords = -240.0 132.5 240.0 -132.5 ');
    Eyelink('Command', 'screen_distance = 300');
    % Set gaze coordinate system. Set calibration_type after this call
    [width, height]=Screen('WindowSize', wp);
    Eyelink('Command','screen_pixel_coords = %ld %ld %ld %ld', 0, 0, width-1, height-1);
    Eyelink('Command', 'calibration_type = HV5');
    % Allow a supported EyeLink Host PC button box to accept calibration or drift-check/correction targets via button 5
    Eyelink('Command', 'button_function 5 "accept_target_fixation"');
    % How much of screen area to use for calibration points
    Eyelink('Command','calibration_area_proportion 0.5 0.5');

    % Write DISPLAY_COORDS message to EDF file: sets display coordinates in DataViewer
    % See DataViewer manual section: Protocol for EyeLink Data to Viewer Integration > Pre-trial Message Commands
    % The screen_pixel_coords are mapped onto this coord system for drawing
    % commands. Convenient to use screen_pixel_coords here.
    Eyelink('Message', 'DISPLAY_COORDS %ld %ld %ld %ld', 0, 0, width-1, height-1);

    % END BOILERPLATE CONFIG STUFF HERE
end