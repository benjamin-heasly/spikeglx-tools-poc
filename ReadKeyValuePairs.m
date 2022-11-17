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
