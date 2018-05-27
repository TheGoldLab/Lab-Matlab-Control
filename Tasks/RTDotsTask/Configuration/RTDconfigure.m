function RTDconfigure(maintask, datatub, varargin)
% function RTDconfigure(maintask, datatub, varargin)
%
% RTD = Response-Time Dots
%
% Configure the RTD experiment, which consists of a combination of 
%  multiple different tasks:
%  1. Quest       - Adaptive procedure to determine psychophysical 
%                    threshold for coherence
%  2. MeanRT      - Determine mean RT for speed-accuracy trade-off 
%                    (SAT) feedback
%  3. test        - RT dots with SAT and bias manipulations. see
%                    blockSpects below for details
%  4. VGS/MGS     - Visually and memory-guided saccade tassk
%
% Inputs:
%   datatub       -  A topsGroupedList object containing experimental 
%                    parameters as well as data recorded during the 
%                    experiment.
%   maintask      - the topsTreeNode object to run
%
%  plus varargin, which are property/value pairs:
%  
%  'coherences'   - coherences to use in non-Quest blocks. If Quest
%                     is used, this is overridedn
%  'directions'   - dot directions 
%  'biasedPriors' - priors to use in BIAS blocks
%  'referenceRT'  - scalar value (in sec) to use as reference for feeback 
%                    on 'speed' trials. If none given, computed from 
%                    Quest or meanRT block
%  'taskSpecs'    - cell array that defines the tasks. Each pair is:
%                     1 : Task name, which can be 'Quest', 'meanRT', or
%                         a pair of keys: 
%                           <SAT instruction key, 'S'=Speed, 'A'=Accuracy,
%                                'N'=Neutral, 'X'=None>
%                           <BIAS stimulus key, 'L'=More left, 
%                                'R'=More right, 'N'=Neutral>
%                     2 : <number of trials>
%  'uiDevice',       - string name of dotsReadable* class to use for
%                       choice input
%  'gazeWindowSize', - standard size of gaze window, in degrees vis angle
%  'gazeWindowDur',  - standard duration for gaze window (gaze holding time)
%  'sendTTLs'     - flag, set to true to send TTL pulses via the PMD
%  'useRemote'    - true or false. If true, use RTDconfigureIPs to set
%                          communication parameters
%  'displayIndex' - see dotsTheScreen (0:small window; 1=main window;
%                          2:secondary window)
%  'filePath'     - <string> where to put the data files
%  'fileName'     - <string> name. Note that when pupil labs is used,
%                          a second file is created with name
%                          <filename>_pupil
%
% 5/11/18   updated by jig
% 10/2/17   xd wrote it

%% ---- Parse arguments
c = clock;
defaultArguments = { ...
   'taskSpecs',            {'Quest', 40, 'meanRT', 20, 'SN' 20 'AN' 20}; ...
   'coherences',           [0 3.2 6.4 12.8 25.6 51.2]; ...
   'directions',           [0 180]; ...
   'biasedPriors',         [20 80]; ...
   'referenceRT',          nan; ...
   'trialsPerCoherence',   40; ....
   'saccadeDirections',    0:90:270; ... %0:45:315; ...
   'trialsPerDirection',   4; ...
   'uiDevice',             'dotsReadableEyePupilLabs'; ...
   'gazeWindowSize',       3; ...
   'gazeWindowDur',        0.02; ...
   'sendTTLs',             false; ...
   'useRemote',            false; ...
   'displayIndex',         1; ...
   'filePath',             RTDfilepath(); ...
   'fileName',             sprintf('data_%.4d_%02d_%02d_%02d_%02d.mat', c(1), c(2), c(3), c(4), c(5)); ...
   };

% Arguments are property/value pairs
for ii = 1:2:nargin-2
   defaultArguments{strcmp(varargin{ii}, defaultArguments(:,1)),2} = varargin{ii+1};
end

% Save to state list
for ii = 1:size(defaultArguments, 1)
   datatub{'Input'}{defaultArguments{ii,1}} = defaultArguments{ii,2};
end

%% ---- Timing parameters
% These pararmeters determine how long different parts of the task
% presentation should take. These are kept the same across trials. All
% fields values are in seconds.

% GENERAL
datatub{'Timing'}{'showInstructions'} = 3.0;
datatub{'Timing'}{'waitAfterInstructions'} = 0.5;
datatub{'Timing'}{'fixationTimeout'} = 5;
datatub{'Timing'}{'holdFixation'} = 0.5;
datatub{'Timing'}{'showFeedback'} = 1;
datatub{'Timing'}{'InterTrialInterval'} = 1;

% DOTS TASK
datatub{'Timing'}{'showTargetForeperiodMin'} = 0.2;
datatub{'Timing'}{'showTargetForeperiodMax'} = 1.0;
datatub{'Timing'}{'showTargetForeperiodMean'} = 0.5;
datatub{'Timing'}{'dotsTimeout'} = 5;

% SACCADE TASK
datatub{'Timing'}{'VGSTargetDuration'} = 1;
datatub{'Timing'}{'MGSTargetDuration'} = 0.25;
datatub{'Timing'}{'MGSDelayDuration'} = 0.75;
datatub{'Timing'}{'saccadeTimeout'} = 5;

%% ---- General Stimulus Params
%
% These parameters are shared across the different types of stimulus. These
% essentially dictate things like size of stimulus and location on screen.

% Size of the fixation cue in dva. Additionally, we will want to store the
% pixel coordinates for the center of the screen to use in comparisons with
% Eyelink samples later.
datatub{'FixationCue'}{'size'} = 1;
datatub{'FixationCue'}{'xDVA'} = 0;
datatub{'FixationCue'}{'yDVA'} = 0;

% Position (horizontal distance from center of screen) and size of the
% saccade targets in dva. Similar to the fixation cue, we also want to
% store the pixel positions for these.
datatub{'SaccadeTarget'}{'offset'} = 10;
datatub{'SaccadeTarget'}{'size'}   = 1.5;
datatub{'SaccadeTarget'}{'sacOffset'} = 7;

% Parameters for the moving dots stimuli that will be shared across every
% trial. Also store the pixel position for the center of the stimuli.
datatub{'MovingDots'}{'stencilNumber'} = 1;
datatub{'MovingDots'}{'pixelSize'} = 6;
datatub{'MovingDots'}{'diameter'} = 8;
datatub{'MovingDots'}{'density'} = 150;
datatub{'MovingDots'}{'speed'} = 3;
datatub{'MovingDots'}{'xDVA'} = 0;
datatub{'MovingDots'}{'yDVA'} = 0;

% Vertical position of instructions/feedback text
datatub{'Text'}{'yPosition'} = 4;

%% ---- TTL Output (to sync with neural data acquisition system)
if datatub{'Input'}{'sendTTLs'}
   datatub{'dOut'}{'dOutObject'} = ...
      feval(dotsTheMachineConfiguration.getDefaultValue('dOutClassName'));
   datatub{'dOut'}{'timeBetweenTTLPulses'} = 0.01; % in sec
   datatub{'dOut'}{'TTLChannel'} = 0; % 0 (pin 13) or 1 (pin 14)
end

%% ---- Configure Graphics
RTDconfigureGraphics(datatub);

%% ---- Configure User input : pupil labs or keyboard
RTDconfigureUI(datatub);

%% ---- Configure Tasks + State Machines
%
% Only make these if necessary
datatub{'Control'}{'dotsStateMachine'} = [];
datatub{'Control'}{'saccadeStateMachine'} = [];

% Set up references that may or may not be overriden by Quest/MeanRT tasks
datatub{'Task'}{'referenceRT'} = datatub{'Input'}{'referenceRT'};
datatub{'Task'}{'referenceCoherence'} = datatub{'Input'}{'coherences'};

% Use a standard data struct to store trial data. We will later use
% topsDataLog.getEcodeData to automatically make an ecode matrix from these
% data
trialData = struct( ...
   'taskIndex', nan, ...
   'trialIndex', nan, ...
   'direction', nan, ...
   'coherence', nan, ...
   'choice', nan, ...
   'RT', nan, ...
   'correct', nan, ...
   'time_screen_roundTrip', 0, ...
   'time_local_trialStart', nan, ...
   'time_ui_trialStart', nan, ...
   'time_screen_trialStart', nan, ...
   'time_TTLFinish', nan, ...
   'time_fixOn', nan, ...
   'time_targsOn', nan, ...
   'time_dotsOn', nan, ...
   'time_targsOff', nan, ...
   'time_fixOff', nan, ...
   'time_choice', nan, ...
   'time_dotsOff', nan, ...
   'time_fdbkOn', nan, ...
   'time_local_trialFinish', nan, ...
   'time_ui_trialFinish', nan, ...
   'time_screen_trialFinish', nan);

% list of all possible task names, to get indices
taskNames = {'VGS' 'MGS' ...
   'Quest' 'meanRT' ...
   'NN' 'NL' 'NR' ...
   'SN' 'SL' 'SR' ...
   'AN' 'AL' 'AR'};   

% Loop through the taskSpecs array, making and adding tasks
taskSpecs = datatub{'Input'}{'taskSpecs'};
taskNumber = 1; % for feedback (see RTDstartTrial)
for tt = 1:2:length(taskSpecs)
      
   % Parse the name and trial numbers from sequential arguments
   name = taskSpecs{tt};
   trialsPerCondition = taskSpecs{tt+1};
   
   % Make the task with some defaults
   task = maintask.newChildNodeTask(name);
   task.finishChildren      = true;
   task.finishFevalable     = {@topsDataLog.writeDataFile};
   task.iterations          = inf;
   task.trialData           = trialData;
   
   % We use the taskIndex property of the task to keep track of the task
   % number (i.e., just the incremental order of the tasks used), but the
   % taskIndex property of the trial as the unique task-type identifier,
   % which we'll need to parse/analyze the data
   task.taskIndex           = taskNumber; 
   task.trialData.taskIndex = find(strcmp(name, taskNames));
   taskNumber               = taskNumber + 1;
   
   % Add task-specific information, depending on the named type
   switch (name)
      
      case {'MGS', 'VGS'}
         
         % Saccade task!
         %
         % Configure saccade state machine if it doesn't exist
         if isempty(datatub{'Control'}{'saccadeStateMachine'})
            RTDconfigureSaccadeStateMachine(datatub);
         end

         % Add task type and state machine information
         task.taskData.taskType = 'saccade';
         task.taskData.stateMachine = datatub{'Control'}{'saccadeStateMachine'};
         task.addChild(datatub{'Control'}{'saccadeStateMachineComposite'});
              
         % Configure saccade task
         RTDconfigureSaccadeTask(task, datatub, trialsPerCondition);
      
      otherwise
         
         % Dots task!
         %
         % Configure dots state machine if it doesn't exist
         if isempty(datatub{'Control'}{'dotsStateMachine'})
            RTDconfigureDotsStateMachine(datatub);
         end

         % Add task type and state machine information
         task.taskData.taskType = 'dots';
         task.taskData.stateMachine = datatub{'Control'}{'dotsStateMachine'};
         task.taskData.previousScore = nan; % for Quest
         task.taskData.previousCoherence = nan; % for Quest
         task.addChild(datatub{'Control'}{'dotsStateMachineComposite'});

         % Configure dots task
         RTDconfigureDotsTask(task, datatub, trialsPerCondition);         
   end
end