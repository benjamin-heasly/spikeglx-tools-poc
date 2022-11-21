% Call TPrime to align event times with sync times.
% Handle shell / command line integration.
% Parse and return results from the shell and files produced by TPrime.
%
% Returns a struct with info about the TPrime run, including:
%  - shell command and execution status and result
%  - datetimes and duration around the TPrime call
%  - TPrime log file in the working directory, 'TPrime.log'
%  - output files produced
%
% This util is intended to instantiate documention from the TPrime
% ReadMe.txt, for convenience and integration into pipelines.
% The Readme.txt comes with the TPrime download, eg TPrime-linux/ReadMe.txt
%
% The "syncPeriod" parameter is the period of the sync pulse recoded by
% each data stream -- usually 1.0 (Hz).
%
% The "toStream" parameter is the path to a file containing sync pulse edge
% event times, for example one of the sync_ni or sync_imec files produced
% by CatGT.  This declares the canonical stream to which other event
% streams will be aligned.
%
% The "fromStreams" parameter is an nx3 cell array describing event streams
% that should be aligned to the canonical stream.  Each row of fromStreams
% should have three file names, like this:
%
%   { ... edgeFile, eventsFile, outFile; ... }
%
% On each row:
%  - "edgeFile" contains sync pulse edge event times from any event stream,
%    especially a stream other than "toStream".
%  - "eventsFile" contains other event times from the same event stream as
%    edgeFile, to be realigned with respect to "toStream".
%  - "outFile" is the name of the output file where realigned event times
%    should be written.  If outFile is empty, a unique path will be
%    automatically chosen, in the same dir as eventsFile.
%
% The "dryRun" parameter is false by default.  If set to true, this util
% will skip invoking TPrime but still try to print and parse everything
% else like normal.
%
% The "whichRunIt" parameter is the file path to TPrime's "runit" shell
% script on the current machine.  If omitted, makes a best-effort attempt
% to locate a "runit" sh or bat inside a "TPrime" folder on the Matlab path.
function info = TPrime(syncPeriod, toStream, fromStreams, dryRun, whichRunIt)

fprintf('TPrime VVVVV\n');

info = struct();

if nargin < 4 || isempty(dryRun)
    dryRun = false;
end

if nargin < 5 || isempty(whichRunIt)
    % The TPrime executable is a shell script named "runit".
    if ispc()
        runits = which('runit.bat', '-all');
    else
        runits = which('runit.sh', '-all');
    end

    % But TPrime uses the same schell script name.
    % Disambiguate these by looking at names of parent folders.
    containsCatGT = cellfun(@(s) contains(s, 'TPrime'), runits);
    if any(containsCatGT)
        matchInds = find(containsCatGT);
        whichRunIt = runits{matchInds(1)};
    end
end

info.runit = whichRunIt;
if isfile(whichRunIt)
    fprintf('TPrime runit script found: %s\n', whichRunIt);
else
    error('TPrime runit script not found or not a file (%s).', whichRunit);
end

% Read the existing log file, which TPrime will append to when we call it.
% From the TPrime ReadMe.txt:
% Run messages are appended to TPrime.log in the current working directory.
info.logFile = fullfile(pwd(), 'TPrime.log');
if isfile(info.logFile)
    fprintf('TPrime existing log file found: %s\n', info.logFile);
    oldLog = readlines(info.logFile, 'EmptyLineRule', 'skip');
else
    fprintf('TPrime log file does not exist yet at: %s\n', info.logFile);
    oldLog = {};
end

% Auto-construct fromStream outFiles as needed.
nFrom = size(fromStreams, 1);
for ii = 1:nFrom
    outFile = fromStreams{ii,3};
    if isempty(outFile)
        eventsFile = fromStreams{ii,2};
        [eventsPath, eventsName, eventsExt] = fileparts(eventsFile);

        [~, toName] = fileparts(toStream);
        outName = [eventsName '_WRT_' toName];
        outFile2 = fullfile(eventsPath, [outName, eventsExt]);
        fromStreams{ii,3} = outFile2;
    end
end
info.fromStreams = fromStreams;

% runit.sh -syncperiod=1.0 -tostream=path/edgefile.txt -fromstream=5,path/edgefile.txt -events=5,path/in_eventfile.txt,path/out_eventfile.txt
fromCell = cell(nFrom, 1);
for ii = 1:nFrom
    edgesFile = fromStreams{ii,1};
    eventsFile = fromStreams{ii,2};
    outFile = fromStreams{ii,3};
    fromCell{ii} = sprintf('-fromstream=%d,%s -events=%d,%s,%s', ...
        ii, ...
        edgesFile, ...
        ii, ...
        eventsFile, ...
        outFile);
end
fromArgs = sprintf(' %s', fromCell{:});

% Call TPrime with a big command line.
info.command = sprintf('''%s'' ''-syncperiod=%f -tostream=%s %s''', ...
    whichRunIt, ...
    syncPeriod, ...
    toStream, ...
    fromArgs);

info.pwd = pwd();
fprintf('TPrime working dir: %s\n', info.pwd);

info.start = datetime('now', 'Format', 'uuuuMMdd''T''HHmmss');
fprintf('TPrime start datetime: %s\n', char(info.start));

fprintf('TPrime command: %s\n', info.command)
if dryRun
    fprintf('TPrime dry run: skipping actual TPrime call.\n');
    info.status = 0;
    info.result = 'test';
else
    fprintf('TPrime starting...\n');
    [info.status, info.result] = system(info.command);
    fprintf('TPrime exit status %d with result: %s\n', info.status, info.result);
end

info.finish = datetime('now', 'Format', 'uuuuMMdd''T''HHmmss');
info.duration = info.finish - info.start;
fprintf('TPrime end datetime: %s (%s elapsed)\n', char(info.finish), char(info.duration));

% Look for new log entries appended.
info.logEntries = readlines(info.logFile, 'EmptyLineRule', 'skip');
oldLogCount = numel(oldLog);
newLogCount = numel(info.logEntries);
info.newLogEntries = info.logEntries((oldLogCount + 1):newLogCount);
diffLogCount = newLogCount - oldLogCount;
fprintf('TPrime wrote %d new log entries (%d total).\n', diffLogCount, newLogCount);
for ii = 1:diffLogCount
    fprintf('TPrime log entry: %s\n', info.newLogEntries{ii});
end

if info.status ~= 0
    error('TPrime nonzero exit status %d with result: %s', info.status, info.result);
end

fprintf('TPrime ^^^^^\n');
