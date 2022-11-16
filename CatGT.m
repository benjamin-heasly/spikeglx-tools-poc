% Call CatGT with its various arguments for file coordinates and operators.
% Handle shell / command line integration.
% Parse and return results from the shell and files produced by CatGT.
%
% Returns a struct with info about the CatGT run, including:
%  - shell command and execution status and result
%  - datetimes and duration around the CatGT call
%  - CatGT log file in the working directory, 'CatGT.log'
%  - CatGT "offsets" file that has sample offsets for each file in a run
%  - CatGT "fyi" file that describes other output files and folders
%  - any files found in the output folders
%
% This util is intended to instantiate documention from the CatGT
% ReadMe.html, for convenience and integration into pipelines.
% The ReadMe.html comes with the CatGT download, eg CatGT-linux/ReadMe.html
%
% The first five parameters give "coordinates" that CatGT uses to locate
% input files to be processed:
%  - dataPath -- folder where SpikeGLX is configured to write data
%  - runName -- name of a recording session in SpikeGLX, maybe 'rec'
%  - g -- one or more SpikeGLX "gate" indexes, maybe '0:1'
%  - t -- one or more SpikeGLX "trigger" indexes, maybe '0:7'
%  - whichStreams -- types of acquisition stream/card, maybe '-ni -ap -lf'
%
% The "options" can contain operator specifications for primary processing
% tasks like event detection, band pass filtering, etc.  The same parameter
% can also take flags etc. for secondary behaviors, like where to write
% output files and what to do if files or samples are missing. I'll defer
% to the CatGT ReadMe.html to describe these.  All the options can be
% passed to this util as one string, for example '-prb_fld -prb=0:1'.
%
% "outputPath" can be supplied to specify where new files should be
% written.  When present, it gets added to the options with as
% "-dest=[outputPath]".
%
% The "dryRun" parameter is false by default.  If set to true, this util
% will skip invoking CatGT but still try to print and parse everything
% else like normal.
%
% The "whichRunIt" parameter is the file path to CatGT's "runit" shell
% script on the current machine.  If omitted, makes a best-effort attempt
% to locate a "runit" sh or bat inside a "CatGT" folder on the Matlab path.
function info = CatGT(dataPath, runName, g, t, whichStreams, options, outputPath, dryRun, whichRunIt)

fprintf('CatGT VVVVV\n');

info = struct();

if nargin < 6 || isempty(options)
    options = '';
end

gParts = split(g, {':', ','});
firstG = gParts{1};
if nargin < 7 || isempty(outputPath)
    % Look here for the fyi and offsets files, below.
    gFolder = sprintf('%s_g%s', runName, firstG);
    fyiPath = fullfile(dataPath, gFolder);
else
    % Write results here.
    [~, ~] = mkdir(outputPath);
    options = [options ' -dest=' outputPath];

    % Look here for the fyi and offsets files, below.
    if contains(options, '-supercat')
        gFolder = sprintf('supercat_%s_g%s', runName, firstG);
    else
        gFolder = sprintf('catgt_%s_g%s', runName, firstG);
    end
    fyiPath = fullfile(outputPath, gFolder);
end

if nargin < 8 || isempty(dryRun)
    dryRun = false;
end

if nargin < 9 || isempty(whichRunIt)
    % The CatGT executable is a shell script named "runit".
    if ispc()
        runits = which('runit.bat', '-all');
    else
        runits = which('runit.sh', '-all');
    end

    % But TPrime uses the same schell script name.
    % Disambiguate these by looking at names of parent folders.
    containsCatGT = cellfun(@(s) contains(s, 'CatGT'), runits);
    if any(containsCatGT)
        matchInds = find(containsCatGT);
        whichRunIt = runits{matchInds(1)};
    end
end

info.runit = whichRunIt;
if isfile(whichRunIt)
    fprintf('CatGT runit script found: %s\n', whichRunIt);
else
    error('CatGT runit script not found or not a file (%s).', whichRunit);
end

% Read the existing log file, which CatGT will append to when we call it.
% From the CatGT ReadMe.html:
% Errors and run messages are appended to CatGT.log in the current working directory.
info.logFile = fullfile(pwd(), 'CatGT.log');
if isfile(info.logFile)
    fprintf('CatGT existing log file found: %s\n', info.logFile);
    oldLog = readlines(info.logFile, 'EmptyLineRule', 'skip');
else
    fprintf('CatGT log file does not exist yet at: %s\n', info.logFile);
    oldLog = {};
end

% Call CatGT with a big command line.
info.command = sprintf('''%s'' ''-dir=%s -run=%s -g=%s -t=%s %s %s''', ...
    whichRunIt, ...
    dataPath, ...
    runName, ...
    g, ...
    t, ...
    whichStreams, ...
    options);

info.pwd = pwd();
fprintf('CatGT working dir: %s\n', info.pwd);

info.start = datetime('now', 'Format', 'uuuuMMdd''T''HHmmss');
fprintf('CatGT start datetime: %s\n', char(info.start));

fprintf('CatGT command: %s\n', info.command)
if dryRun
    fprintf('CatGT dry run: skipping actual CatGT call.\n');
    info.status = 0;
    info.result = 'test';
else
    fprintf('CatGT starting...\n');
    [info.status, info.result] = system(info.command);
    fprintf('CatGT exit status %d with result: %s\n', info.status, info.result);
end

info.finish = datetime('now', 'Format', 'uuuuMMdd''T''HHmmss');
info.duration = info.finish - info.start;
fprintf('CatGT end datetime: %s (%s elapsed)\n', char(info.finish), char(info.duration));

% Look for new log entries appended.
info.logEntries = readlines(info.logFile, 'EmptyLineRule', 'skip');
oldLogCount = numel(oldLog);
newLogCount = numel(info.logEntries);
info.newLogEntries = info.logEntries((oldLogCount + 1):newLogCount);
diffLogCount = newLogCount - oldLogCount;
fprintf('CatGT wrote %d new log entries (%d total).\n', diffLogCount, newLogCount);
for ii = 1:diffLogCount
    fprintf('CatGT log entry: %s\n', info.newLogEntries{ii});
end

if info.status ~= 0
    error('CatGT nonzero exit status %d with result: %s', info.status, info.result);
end

% Look for the "FYI" file that describes output files.
info.fyiFile = fullfile(fyiPath, sprintf('%s_g%s_fyi.txt', runName, firstG));
if isfile(info.fyiFile)
    fprintf('CatGT fyi file found: %s\n', info.fyiFile);
    info.fyi = ReadKeyValuePairs(info.fyiFile);

    % The fyi file also mentions output dirs, in addition to individual files.
    % Look for files written in these dirs.
    % Note: these dirs might be under the given dataPath,
    % or some other path if the "-dest=path" option was provided.
    fyiFields = fieldnames(info.fyi);
    info.outFiles = {};
    for ii = 1:numel(fyiFields)
        fieldName = fyiFields{ii};
        outPath = info.fyi.(fieldName);
        if startsWith(fieldName, 'outpath') && isfolder(outPath)
            dirInfo = dir(outPath);
            isNewFile = arrayfun(@(d)~d.isdir, dirInfo);
            outFilePaths = cellfun(@(name)fullfile(outPath, name), {dirInfo(isNewFile).name}, 'UniformOutput', false);
            info.outFiles = cat(1, info.outFiles, outFilePaths(:));
        end
    end

    outFileCount = numel(info.outFiles);
    fprintf('CatGT %d output files found.\n', outFileCount);
    for ii = 1:outFileCount
        fprintf('CatGT output file: %s\n', info.outFiles{ii});
    end
else
    fprintf('CatGT fyi file not found at: %s\n', info.fyiFile);
end


% Look for the "offsets" file that has sample offsets for input file.
if contains(options, '-supercat')
    info.offsetsFile = fullfile(fyiPath, sprintf('%s_g%s_sc_offsets.txt', runName, firstG));
else
    info.offsetsFile = fullfile(fyiPath, sprintf('%s_g%s_ct_offsets.txt', runName, firstG));
end
if isfile(info.offsetsFile)
    fprintf('CatGT offsets file found: %s\n', info.offsetsFile);
    info.offsets = ReadKeyValuePairs(info.offsetsFile);
else
    fprintf('CatGT offsets file not found at: %s\n', info.offsetsFile);
end

fprintf('CatGT ^^^^^\n');


% Read a file of key-value pairs into a struct.
% Could be SpikeGLX "meta" ini file: lines with with "=" separators,
% or any file with lines and separators, like "=" or ":".
function info = ReadKeyValuePairs(filePath, separators)
if nargin < 3 || isempty(separators)
    separators = {':', '='};
end
info = struct();
lines = readlines(filePath, 'EmptyLineRule', 'skip');
for ii = 1:numel(lines)
    keyValuePair = split(lines{ii}, separators);
    key = strip(keyValuePair{1});
    key = key(key ~= '~');
    info.(key) = strip(keyValuePair{2});
end
