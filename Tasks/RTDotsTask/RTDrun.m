function RTDrun(location)
%% function RTDrun(location)
%
% RTD = Response-Time Dots
%
% This function configures, initializes, runs, and cleans up an RTD
% experiment.
%
% 11/17/18   jig wrote it

%% ---- Clear globals
% 
% umm, duh
clear globals

%% ---- Create a topsGroupedList
%
% This is a versatile data structure that will allow us to pass all 
%  relevant variables to the state machine as it advances
datatub = topsGroupedList();

%% ---- Set up the main tree node and save it
%
% We set this up here because we might have multiple task configuration
% files (see below) that each add chidren to it
maintask = topsTreeNode('dotsTask');
maintask.iterations = 1; % Go once through the set of tasks
%maintask.startFevalable = {@callObjectMethod, datatub{'Graphics'}{'screenEnsemble'}, @open};
%maintask.finishFevalable = {@callObjectMethod, datatub{'Graphics'}{'screenEnsemble'}, @close};
datatub{'Control'}{'mainTask'} = maintask;

%% ---- Set argument list based on location
%
%   locations are 'office' (default), 'OR', or 'debug'
if nargin < 1 || isempty(location)
    location = 'office';
end

switch location
    
    case {'OR'}        
        arguments = { ...
            'taskSpecs',            {'Quest' 60 'SN' 40 'AN' 40}, ...
            'sendTTLs',             true, ...
            'useEyeTracking',       true, ...
            'displayIndex',         1, ... % 0=small, 1=main
            'useRemote',            true, ...
            };

    case {'debug'}    
        arguments = { ...
            'taskSpecs',            {'Quest' 2 'SN' 2 'AN' 2}, ...%{'Quest' 50 'SN' 50 'AN' 50}, ...
            'sendTTLs',             false, ...
            'useEyeTracking',       false, ...
            'displayIndex',         0, ... % 0=small, 1=main
            'useRemote',            false, ...
            };
        
    otherwise        
        arguments = { ...
            'taskSpecs',            {'Quest' 40 'SN' 50 'AN' 50}, ...
            'sendTTLs',             false, ...
            'useEyeTracking',       true, ...
            'displayIndex',         1, ... % 0=small, 1=main
            'useRemote',            true, ...
            };
end

%% ---- Configure experiment
RTDconfigure(maintask, datatub, arguments{:});

%% ---- Initialize
%
% Start data logging
topsDataLog.flushAllData(); % Flush stale data, just in case
topsDataLog.logDataInGroup(struct(datatub), 'datatub');
topsDataLog.writeDataFile(fullfile(datatub{'Input'}{'filePath'}, datatub{'Input'}{'fileName'}));

% Get the screen ensemble
screenEnsemble = datatub{'Graphics'}{'screenEnsemble'};

% Open the screen
screenEnsemble.callObjectMethod(@open);

% Possibly calibrate the eye tracker
RTDcalibratePupilLabs(datatub);

%% ---- Run the task
maintask.run();

%% ---- Clean up
%
% Close the screen
screenEnsemble.callObjectMethod(@close);

% Close the uis
close(datatub{'Control'}{'ui'});
close(datatub{'Control'}{'keyboard'});

%save the data
topsDataLog.writeDataFile();
