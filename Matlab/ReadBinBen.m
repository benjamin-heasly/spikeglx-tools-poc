% =========================================================
% Read from the binary file starting at sample number samp0
% up through nSamp samples (or as much as is available).
%
% To limit memory usage, read the data in chunks of fixed
% number of samples.  For each chunk, keep only the min and
% max.
%
% Min and max have property of being actual, raw sample
% values from the binary data.  This facilitates downstream
% processing that makes assumptions about possible values
% or their encodings (for example, digital words).  Other
% summary stats, like mean, lack this property.  Median
% would also have this property, but it's slower to compute.
%
% Return an array of mins and maxes from all chunks
% in the specified range.  Also return a corresponding
% array of sample numbers where the mins and maxs occured.
%
% Both retuned arrays have dimensions [nChan, 2 * nChunks],
% where nChunks = ceil(nSamp / sampPerChunk).
%
% IMPORTANT: samp0 and nSamp must be integers.
%
function [values, indices] = ReadBinBen(samp0, nSamp, meta, binName, path, sampPerChunk)

if nargin < 6 || isempty(sampPerChunk)
    sampPerChunk = 100;
end

nChan = str2double(meta.nSavedChans);
nFileSamp = str2double(meta.fileSizeBytes) / (2 * nChan);

samp0 = max(samp0, 0);
nSamp = min(nSamp, nFileSamp - samp0);
nChunks = ceil(nSamp / sampPerChunk);

outputSize = [nChan, 2 * nChunks];
values = zeros(outputSize);
indices = zeros(outputSize);

fid = fopen(fullfile(path, binName), 'rb');
for ii = 1:nChunks
    chunkSamp0 = (ii - 1) * sampPerChunk + samp0;
    chunkNSamp = min(sampPerChunk, nFileSamp - chunkSamp0);
    chunkSize = [nChan, chunkNSamp];

    chunkOffset = chunkSamp0 * 2 * nChan;
    fseek(fid, chunkOffset, 'bof');
    chunkData = fread(fid, chunkSize, 'int16=>double');

    [mins, minInds] = min(chunkData, [], 2);
    minSamps = minInds - 1 + chunkSamp0;

    [maxes, maxInds] = max(chunkData, [], 2);
    maxSamps = maxInds - 1 + chunkSamp0;

    resultStart = (ii - 1) * 2 + 1;
    resultIndices = resultStart:(resultStart + 1);
    values(:, resultIndices) = [mins, maxes];
    indices(:, resultIndices) = [minSamps, maxSamps];
end
fclose(fid);

end % ReadBinBen
