% Find SpikeGLX .bin files in a recording directory.
% Read each one and:
%   - print metadata to describe what's in the file
%   - plot the sync waveform
%   - plot any National Instruments analog data
%   - plot any Imec action potential data
%   - plot any Imec local field potential data
%
% This is a proof of concept based on the SpikeGLX DemoReadSGLXData.m.
% BSH added interpretation from the SpikeGLX docs:
%  - https://billkarsh.github.io/SpikeGLX/Sgl_help/UserManual.html
%  - https://billkarsh.github.io/SpikeGLX/Sgl_help/Metadata_30.html
function PlotSpikeGlxRecordingSummary(recDir, startTime, duration)

if nargin < 1 || isempty(recDir)
    recDir = pwd();
end

if nargin < 2 || isempty(startTime)
    startTime = 0;
end

if nargin < 3 || isempty(duration)
    duration = 30;
end

fprintf('Searching for .bin files in %s\n', recDir);

binFiles = dir(fullfile(recDir, '**/*.bin'));
nFiles = numel(binFiles);

fprintf('Found %d .bin files.\n', nFiles);
if nFiles < 1
    return;
end

fprintf('Plotting %.2f seconds of data starting at %.2f, for each file.\n', duration, startTime);

figure();
legendNames = cell(1, nFiles);
plotColors = lines(nFiles);
for ii = 1:nFiles
    binPath = binFiles(ii).folder;
    binName = binFiles(ii).name;
    fprintf('\nReading .meta and .bin for %s\n', binName);
    meta = ReadMeta(binName, binPath);

    markerSize = 3*(1 + nFiles - ii);
    markerColor = plotColors(ii, :);
    legendNames{ii} = binName;
    endTime = startTime;

    if strcmp(meta.typeThis, 'nidq')
        DescribeNI(meta, binName);
        [dataArray, sampleTimes] = ReadDataNI(meta, binName, binPath, startTime, duration);
        endTime = max(endTime, max(sampleTimes(:)));

        [syncWave, syncTimes] = ExtractSyncNI(meta, dataArray, sampleTimes);
        [analogWaves, analogTimes] = ExtractAnalogNI(meta, dataArray, sampleTimes);

        subplot(4, 1, 2);
        hold on
        plot(analogTimes', analogWaves', '.', 'MarkerSize', markerSize, 'Color', markerColor);
    else
        DescribeIM(meta, binName);
        [dataArray, sampleTimes] = ReadDataIM(meta, binName, binPath, startTime, duration);
        endTime = max(endTime, max(sampleTimes(:)));

        [syncWave, syncTimes] = ExtractSyncIM(meta, dataArray, sampleTimes);
        [apWaves, apTimes] = ExtractApIM(meta, dataArray, sampleTimes);
        [lfWaves, lfTimes] = ExtractLfIM(meta, dataArray, sampleTimes);

        subplot(4, 1, 3);
        hold on
        plot(apTimes', apWaves', '.', 'MarkerSize', markerSize, 'Color', markerColor);
        subplot(4, 1, 4);
        hold on
        plot(lfTimes', lfWaves', '.', 'MarkerSize', markerSize, 'Color', markerColor);
    end

    subplot(4, 1, 1);
    hold on
    plot(syncTimes', syncWave', '.', 'MarkerSize', markerSize, 'Color', markerColor);
end

subplot(4, 1, 1);
legend(legendNames, "Location", "best")
set(gca, 'XGrid', 'on')
xlim(gca, [startTime, endTime])
ylabel('sync V or bool')

subplot(4, 1, 2);
set(gca, 'XGrid', 'on')
xlim(gca, [startTime, endTime])
ylabel('ni analog V')

subplot(4, 1, 3);
set(gca, 'XGrid', 'on')
xlim(gca, [startTime, endTime])
ylabel('im ap V')

subplot(4, 1, 4);
set(gca, 'XGrid', 'on')
xlim(gca, [startTime, endTime])
ylabel('im lf V')

xlabel('sample time (s)')


% Print a summary of a National Instruments data file.
function DescribeNI(meta, binName)
fprintf('\n');
fprintf('%s %s: %s\n', meta.typeThis, meta.niDev1ProductName, binName);

[MN,MA,XA,DW] = ChannelCountsNI(meta);
fprintf('%d multiplexed neural signed 16-bit channels: %s\n', MN, meta.niMNChans1);
fprintf('%d multiplexed aux analog signed 16-bit channels: %s\n', MA, meta.niMAChans1);
fprintf('%d non-muxed aux analog signed 16-bit channels: %s\n', XA, meta.niXAChans1);
fprintf('%d non-muxed aux digital unsigned 16-bit words: %s\n', DW, meta.niXDChans1);

fileTimeSecs = str2double(meta.fileTimeSecs);
sampleRate = str2double(meta.niSampRate);
nSavedChans = str2double(meta.nSavedChans);
nSamplesExpected = nSavedChans * sampleRate * fileTimeSecs;
fprintf('%f seconds at %.2fHz over %d channels (%.0f samples)\n', ...
    fileTimeSecs, sampleRate, nSavedChans, nSamplesExpected);

fileSizeBytes = str2double(meta.fileSizeBytes);
fprintf('%d bytes at 2 bytes per sample (%.0f samples)\n', ...
    fileSizeBytes, fileSizeBytes / 2);

syncSourceIdx = str2double(meta.syncSourceIdx);
if syncSourceIdx == 0
    syncSourceName = 'none';
elseif syncSourceIdx == 1
    syncSourceName = 'external';
elseif syncSourceIdx == 2
    syncSourceName = 'NI';
else
    syncSourceName = 'IM';
end

syncNiChanType = str2double(meta.syncNiChanType);
if syncNiChanType == 0
    syncTypeName = 'digital';
else
    syncTypeName = 'analog';
end

syncNiChan = str2double(meta.syncNiChan) + 1;
fprintf('Sync signal (source %s) is on %s channel %d\n', ...
    syncSourceName, syncTypeName, syncNiChan);

% Refers to overall recording (samples since g0 t0)
fprintf('First sample: %d\n', str2double(meta.firstSample));

fprintf('User notes: %s\n', meta.userNotes);


% Print a summary of an Imec data file.
function DescribeIM(meta, binName)
fprintf('\n');
fprintf('%s probe %s (serial %s): %s\n', ...
    meta.typeThis, meta.imDatPrb_pn, meta.imDatPrb_sn, binName);

[AP,LF,SY] = ChannelCountsIM(meta);
fprintf('%d 16-bit action potential channels\n', AP);
fprintf('%d 16-bit local field potential channels\n', LF);
fprintf('%d single 16-bit sync input channel (bit 6)\n', SY);
fprintf('Saved channels (AP 0:383, LF 384:767, SY 768): %s\n', meta.snsSaveChanSubset);
fprintf('Full channel map: %s\n', meta.snsChanMap);

syncSourceIdx = str2double(meta.syncSourceIdx);
if syncSourceIdx == 0
    syncSourceName = 'none';
elseif syncSourceIdx == 1
    syncSourceName = 'external';
elseif syncSourceIdx == 2
    syncSourceName = 'NI';
else
    syncSourceName = 'IM';
end
fprintf('Sync source is %s\n', syncSourceName);

fileTimeSecs = str2double(meta.fileTimeSecs);
sampleRate = str2double(meta.imSampRate);
nSavedChans = str2double(meta.nSavedChans);
nSamplesExpected = nSavedChans * sampleRate * fileTimeSecs;
fprintf('%f seconds at %.2fHz over %d channels (%.0f samples)\n', ...
    fileTimeSecs, sampleRate, nSavedChans, nSamplesExpected);

fileSizeBytes = str2double(meta.fileSizeBytes);
fprintf('%d bytes at 2 bytes per sample (%.0f samples)\n', ...
    fileSizeBytes, fileSizeBytes / 2);

% Refers to overall recording (samples since g0 t0)
fprintf('First sample: %d\n', str2double(meta.firstSample));

fprintf('User notes: %s\n', meta.userNotes);


% Read raw data from all channels of a National Instruments data file.
function [dataArray, sampleTimes] = ReadDataNI(meta, binName, binPath, startTime, duration)
if nargin < 4 || isempty(startTime)
    startTime = 0;
end
if nargin < 5 || isempty(duration) || ~isfinite(duration)
    duration = str2double(meta.fileTimeSecs) - startTime;
end
sampleRate = str2double(meta.niSampRate);
samp0 = floor(startTime * sampleRate);
nSamp = ceil(duration * sampleRate);
[dataArray, dataIndices] = ReadBinBen(samp0, nSamp, meta, binName, binPath);
sampleTimes = startTime + (dataIndices / sampleRate);


% Parse out the sync wave from National Instruments data.
function [syncWave, syncTimes] = ExtractSyncNI(meta, dataArray, sampleTimes)
syncNiChan = str2double(meta.syncNiChan) + 1;
syncNiChanType = str2double(meta.syncNiChanType);
if syncNiChanType == 0
    digitalWord = 1;
    [syncWave, syncChannel] = ExtractDigital(dataArray, meta, digitalWord, syncNiChan);
    syncTimes = sampleTimes(syncChannel,:);
else
    dataArray = GainCorrectNI(dataArray, syncNiChan, meta);
    syncWave = dataArray(syncNiChan, :);
    syncTimes = sampleTimes(syncNiChan, :);
end


% Parse out gain-corrected voltages from National Instruments analog data.
function [analogWaves, analogTimes] = ExtractAnalogNI(meta, dataArray, sampleTimes)
[MN,MA,XA] = ChannelCountsNI(meta);
analogChannelOffset = MN + MA;
analogChannels = analogChannelOffset + (1:XA);
syncNiChanType = str2double(meta.syncNiChanType);
if syncNiChanType == 1
    % Exclude the analog sync channel, if any.
    syncNiChan = str2double(meta.syncNiChan) + 1;
    analogChannels = analogChannels(analogChannels ~= syncNiChan);
end
dataArray = GainCorrectNI(dataArray, analogChannels, meta);
analogWaves = dataArray(analogChannels, :);
analogTimes = sampleTimes(analogChannels, :);


% Read raw data from all channels of an Imec data file.
function [dataArray, sampleTimes] = ReadDataIM(meta, binName, binPath, startTime, duration)
if nargin < 4 || isempty(startTime)
    startTime = 0;
end
if nargin < 5 || isempty(duration) || ~isfinite(duration)
    duration = str2double(meta.fileTimeSecs) - startTime;
end
sampleRate = str2double(meta.imSampRate);
samp0 = floor(startTime * sampleRate);
nSamp = ceil(duration * sampleRate);
[dataArray, dataIndices] = ReadBinBen(samp0, nSamp, meta, binName, binPath);
sampleTimes = startTime + (dataIndices / sampleRate);


% Parse out the sync wave from Imec data.
function [syncWave, syncTimes] = ExtractSyncIM(meta, dataArray, sampleTimes)
digitalWord = 1;
syncChan = 6;
[syncWave, syncChannel] = ExtractDigital(dataArray, meta, digitalWord, syncChan);
syncTimes = sampleTimes(syncChannel, :);


% Parse out gain-corrected voltages from Imec action potential data.
function [apWaves, apTimes] = ExtractApIM(meta, dataArray, sampleTimes)
[AP] = ChannelCountsIM(meta);
apChannels = 1:AP;
dataArray = GainCorrectIM(dataArray, apChannels, meta);
apWaves = dataArray(apChannels, :);
apTimes = sampleTimes(apChannels, :);


% Parse out gain-corrected voltages from Imec local field data.
function [lfWaves, lfTimes] = ExtractLfIM(meta, dataArray, sampleTimes)
[AP, LF] = ChannelCountsIM(meta);
lfChannelOffset = AP;
lfChannels = lfChannelOffset + (1:LF);
dataArray = GainCorrectIM(dataArray, lfChannels, meta);
lfWaves = dataArray(lfChannels, :);
lfTimes = sampleTimes(lfChannels, :);
