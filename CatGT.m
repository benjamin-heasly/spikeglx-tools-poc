% Call CatGT with various arguments for file coordinates and operations.
% Handle shell / command line integration.
% Read results from the files produces.  These include:
%  - The log file in the worling directory, CatGT.log
%  - The "offsets" file that describes each input file's sample offset
%  - The "fyi" file that describes other files written
%
% /home/ninjaben/Desktop/codin/gold-lab/spikeglx-tools/CatGT-linux/ReadMe.html
%
% These parameters are "coordinates" specifying input files to process.
%  - dataPath -- Folder where SpikeGLX was set up to write data
%  - runName -- Name of a recording session in SpikeGLX, maybe 'rec'
%  - g -- One or more SpikeGLX "gate" indexes, maybe '0:1'
%  - t -- One or more SpikeGLX "trigger" indexes, maybe '0:7'
%  - whichStreams -- Types of acquisition stream/card, maybe '-ni -ap -lf'
%
% The "options" parameter is a combination of flags for secondary
% behaviors, and also a spec for various primary oprations to perform.
% I'll defer to the CatGT ReadMe for these.
%
% The "whichRunIt" parameter is the file path to where CatGT's "runit.sh"
% or "runit.bat" script is located on the current machine.  If omitted,
% makes a best effort attempt to locate a "runit.sh" inside a "CatGT"
% folder on the Matlab path.
function [status, logEntries, fyi, CtOffsets] = CatGT(dataPath, runName, g, t, whichStreams, options, whichRunIt)

if nargin < 6 || isempty(options)
    options = '';
end

if nargin < 7 || isempty(whichRunIt)
    if ispc()
        runits = which('runit.bat', '-all');
    else
        runits = which('runit.sh', '-all');
    end
    containsCatGT = cellfun(@(s) contains(s, 'CatGT'), runits);
    if any(containsCatGT)
        matchInds = find(containsCatGT);
        whichRunIt = runits{matchInds(1)};
    end
end

if ~isfile(whichRunIt)
    error('CatGT "runit" script not found or not a file (%s).', whichRunit);
end

% Read the existing log file, which CatGT will append to when we call it.
% From the CatGT ReadMe.html:
% Errors and run messages are appended to CatGT.log in the current working directory.
logFile = fullfile(pwd(), 'CatGT.log');
if isfile(logFile)
    oldLog = readmatrix(logFile, 'FileType', 'text', 'OutputType', 'char');
else
    oldLog = {};
end

% Build a command line for CatGT and call it.
command = sprintf('''%s'' ''-dir=%s -run=%s -g=%s -t=%s %s %s''', ...
    whichRunIt, ...
    dataPath, ...
    runName, ...
    g, ...
    t, ...
    whichStreams, ...
    options);

fprintf('Running CatGT command:\n  %s\n', command)
[status, result] = system(command);

% Look for new log entries appended.
newLog = readmatrix(logFile, 'FileType', 'text', 'OutputType', 'char');
logEntries = newLog((1 + numel(oldLog)):end);

if status ~= 0
    error('Error running CatGT (status %d): %s', status, result);
end

% Look for the "FYI" file that describes output files.
gName = sprintf('%s_g%s', runName, g);
gPath = fullfile(dataPath, gName);
fyiName = sprintf('%s_g%s_fyi.txt', runName, g);
fyi = ReadIni(gPath, fyiName);

% Look for the "offsets" file that describes each input file.
offsetsName = sprintf('%s_g%s_ct_offsets.txt', runName, g);
CtOffsets = ReadIni(gPath, offsetsName);

% TODO:
% There may be more output files created, not mentioned in fyi.
% For example, re-written bin and meta files for imec probes.
% Maybe find these by scanning output folders (which are mentioned in fyi)
% For files newer than the old log file?


% Read a file of key-value pairs into a struct.
% Could be in SpikeGLX "meta" format (ini file).
% Or lines with some other separator, like ":"
function info = ReadIni(path, name)
info = struct();

lines = readlines(fullfile(path, name), 'EmptyLineRule', 'skip');
for ii = 1:numel(lines)
    keyValuePair = split(lines{ii}, {':', '='});
    key = strip(keyValuePair{1});
    key = key(key ~= '~');
    info.(key) = strip(keyValuePair{2});
end
