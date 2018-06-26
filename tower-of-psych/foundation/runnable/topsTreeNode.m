classdef topsTreeNode < topsRunnableComposite
   % @class topsTreeNode
   % A tree-like way to organize an experiment.
   % @details
   % topsTreeNode gives you a uniform, tree-like framework for organizing
   % the different components of an experiment.  All levels of
   % organization--trials, sets of trials, tasks, paradigmns, whole
   % experiments--can be represented by interconnected topsTreeNode
   % objects, as one large tree.
   % @details
   % Every node may have other topsTreeNode objects as "children".  You
   % start an experiment by calling run() on the topmost node.  It invokes
   % a "start" function and then calls run() each of its child nodes.
   % Each child does the same, invoking its own "start" function and then
   % invoking run() on each of its children.
   % @details
   % This flow of "start" and run() continues until it reaches the bottom
   % of the tree where there is a node that has no children.  The
   % bottom nodes might be topsRunnable objects of any type, not just
   % topsTreeNode.
   % @details
   % Then it's back up the tree.  On the way up, each child may invoke its
   % "finish" function before passing control back to the node above it.
   % Once a higher node finishes calling run() all of its children, it may
   % invoke its own "finish" function, and so one, until the flow reaches
   % the topmost node again.  At that point the experiment is done.
   % @details
   % topsTreeNode only treats the structure of an experiment.  The details
   % have to be defined elsewhere, as in specific "start" and "finish"
   % functions, and with bottom nodes of various topsRunnable subclasses.
   % @details
   % Many psychophysics experiments use a tree structure implicitly, along
   % with a similar down-then-up flow of behavior.  topsTreeNode makes
   % the stucture and flow explicit, which offers some advantages:
   %   - You can extend your task structure arbitrarily, without running
   %   out of vocabulary words or hard-coded concepts like "task" "block",
   %   "subblock", "trial", "intertrial", etc.
   %   - You can visualize the structure of your experiment using the
   %   topsTreeNode.gui() method.
   
   properties (SetObservable)
      % number of times to run through this node's children
      iterations = 1;
      
      % count of iterations while running
      iterationCount = 0;
      
      % how to run through this node's children--'sequential' or
      % 'random' order
      iterationMethod = 'sequential';
      
      % For any data used for this node
      nodeData = [];
      
      % Abort experiment
      abortFlag=false;
      
      % Pause experiment
      pauseFlag=false;
      
      % Skip to next task
      skipFlag=false;
      
      % Recalibrate
      calibrateObject=[];
      
      % run GUI name or fevalable
      runGUIName = [];
      
      % args to the runGUI constructor
      runGUIArgs = {};      
   end
   
   properties (Hidden)
      
      % handle to taskGui interface
      runGUIHandle = [];
   end
   
   methods
      % Constuct with name optional.
      % @param name optional name for this object
      % @details
      % If @a name is provided, assigns @a name to this object.
      function self = topsTreeNode(varargin)
         self = self@topsRunnableComposite(varargin{:});
      end
      
      % Create a new topsTreeNode child and add it beneath this node.
      % @param name optional name for the new child node
      % @details
      % Returns a new topsTreeNode which is a child of this node.
      function child = newChildNode(self, varargin)
         child = topsTreeNode(varargin{:});
         self.addChild(child);
      end
      
      % Overloaded start function, to check for gui(s)
      function start(self)
         
         % check for databaseGUI
         
         % check for runGUI
         if ~isempty(self.runGUIName) && isempty(self.runGUIHandle)
            self.runGUIHandle = feval(self.runGUIName, self, self.runGUIArgs{:});          
         else
            self.start@topsRunnable();
         end
      end
      
      % Overloaded finish function, needed because we might have started
      %  GUI but did not run anything
      function finish(self)
         
         if self.isRunning
            self.finish@topsRunnable();
         end
      end
      
      function updateGUI(self, name, varargin)
         
         if ~isempty(self.runGUIHandle)
            
            feval(self.runGUIName, [self.runGUIName name], ...
               self.runGUIHandle, [], guidata(self.runGUIHandle), varargin{:});
         end
      end
      
      % Check status flags. Return ~0 if something happened
      function ret = checkFlags(self, child)
         
         % Default return value
         ret = 0;
         
         % Possibly check gui
         if ~isempty(self.runGUIHandle)
            drawnow;
         end         

         % Pause experiment, wait for ui
         while self.pauseFlag && ~self.abortFlag
            pause(0.01);            
         end
         
         % Recalibrate
         if ~isempty(self.calibrateObject)
             calibrate(self.calibrateObject);
             self.calibrateObject = [];
         end         
         
         % Abort experiment
         if self.abortFlag
            self.abortFlag=false;
            self.abort();
            ret = 1;
            return
         end
         
         % Skip to next task
         if self.skipFlag
            self.skipFlag=false;
            child.abort();
            ret = 1;
            return
         end
      end
      
      % Convenient routine to abort running self and children
      function abort(self)
         
         % Stop self from running
         self.isRunning = false;
         
         % Stop children from running any further
         for ii = 1:length(self.children)
            if isa(self.children{ii}, 'topsTreeNode')
               self.children{ii}.abort();
            else
               self.children{ii}.isRunning = false;
            end
         end
      end
      
      % Recursively run(), starting with this node.
      % @details
      % Begin traversing the tree with this node as the topmost node.
      % The sequence of events should go like this:
      %   - This node executes its startFevalable
      %   - This node does zero or more "iterations":
      %       - This node calls run() on each of its children,
      %       in an order determined by this node's iterationMethod.
      %       Each child then performs the same sequence of actions as
      %       this node.
      %   - This node executes its finishFevalable
      %   .
      % Note that the sequence of events is recursive.  Thus, the
      % behavior of run() depends on this node as well as its children,
      % their children, etc.
      % @details
      % Also note that the recursion happens in the middle of the
      % sequence of events.  Thus, startFevalables will tend
      % to happen first, with higher node starting before their children.
      % Then finishFevalables will tend to happen last, with children
      % finishing before higher nodes.
      function run(self)
         
         % Check for valid iterations -- we might set this to 0 to abort
         if self.iterations <= 0
            return
         end
         
         % Run the start fevalable
         self.start();
         
         % recursive
         try
            nChildren = length(self.children);
            ii = 0;
            while ii < self.iterations && self.isRunning
               ii = ii + 1;
               self.iterationCount = ii;
               
               switch self.iterationMethod
                  case 'random'
                     childSequence = randperm(nChildren);
                     
                  otherwise
                     childSequence = 1:nChildren;
               end
               
               % Loop through the children
               for jj = childSequence
                  
                  % jig added condition so abort happens gracefully
                  if self.isRunning
                     
                     % disp(sprintf('topsTreeNode: Running <%s> child <%s>, isRunning=%d, iterations=%d', ...
                     %   self.name, self.children{jj}.name, self.isRunning, self.iterations))
                     self.children{jj}.caller = self;
                     self.children{jj}.run();
                     self.children{jj}.caller = [];
                  end
               end               
            end
         
         catch recurErr
            
            % Give an error
            warning(recurErr.identifier, ...
               '%s named "%s" failed:\n\t%s', ...
               class(self), self.name, recurErr.message);
            
            % Attempt to clean up despite error
            try
               self.finish();
               
            catch finishErr
               
               % Didn't work
               warning(finishErr.identifier, ...
                  '%s named "%s" failed to finish:\n\t%s', ...
                  class(self), self.name, finishErr.message);
            end
            rethrow(recurErr);
         end
         
         self.finish();
      end
   end
   
   methods (Static)
      
      %% ---- Utility for getting standard top-level topsTreeNode
      %
      % Creates calls lists as start/finish fevalables, for convenience
      %
      % Arugments:
      %  name        ... string
      %  databaseGUI ... 
      %  runGUI
      function [node, startCallList, finishCallList] = createTopNode(name, ...
            databaseGUI, runGUIName)
         
         % ---- Create topsCallLists for start/finish fevalables
         %
         % These can be filled in by various configuration
         %  subroutines so we don't need to know where what has and has not been
         %  added/configured.
         startCallList = topsCallList();
         startCallList.alwaysRunning = false;
         
         % NOTE that the finishFevalables will run in reverse order!!!!!
         finishCallList = topsCallList();
         finishCallList.alwaysRunning = false;
         finishCallList.invertOrder = true;
         
         % ---- Set up the main tree node
         %
         % We set this up here because we might have multiple task configuration
         % files (see below) that each add chidren to it
         node = topsTreeNode(name);
         node.iterations = 1; % Go once through the set of tasks
         node.startFevalable = {@run, startCallList};
         node.finishFevalable = {@run, finishCallList};
         
         % ---- Possibly add the databaseGUI
         
         % ---- Possibly add the runGUI
         if nargin >= 3 && ~isempty(runGUIName)
            node.runGUIName = runGUIName;
         end
      end
   end
end