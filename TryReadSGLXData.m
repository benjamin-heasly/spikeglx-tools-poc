% Let's see if I can make sense of a data dir from SpikeGLX.
% I created other functions in this folder based on DemoReadSGLXData.m
% I added some interpretation from the SpikeGLX docs.
% https://billkarsh.github.io/SpikeGLX/Sgl_help/UserManual.html
% https://billkarsh.github.io/SpikeGLX/Sgl_help/Metadata_30.html
function TryReadSGLXData()

recDir = '/home/ninjaben/Desktop/codin/gold-lab/spikeglx_data/rec_g3';
binNames = { ...
    fullfile(recDir, 'rec_g3_t0.nidq.bin'), ...
    fullfile(recDir, 'rec_g3_imec0', 'rec_g3_t0.imec0.ap.bin'), ...
    fullfile(recDir, 'rec_g3_imec0', 'rec_g3_t0.imec0.lf.bin'), ...
    fullfile(recDir, 'rec_g3_imec1', 'rec_g3_t0.imec1.ap.bin'), ...
    fullfile(recDir, 'rec_g3_imec1', 'rec_g3_t0.imec1.lf.bin'), ...
    };
nFiles =   numel(binNames);

clf();
legendNames = cell(1, nFiles);
plotColors = lines(nFiles);

startTime = 100;
duration = 5;
for ii = 1:nFiles
    markerSize = 3*(1 + nFiles - ii);
    markerColor = plotColors(ii, :);

    [binPath, name, ext] = fileparts(binNames{ii});
    binName = [name ext];
    meta = ReadMeta(binName, binPath);
    if strcmp(meta.typeThis, 'nidq')
        describeNI(meta, binName);
        [dataArray, sampleTimes] = readDataNI(meta, binName, binPath, startTime, duration);
        [syncWave, syncTimes] = extractSyncNI(meta, dataArray, sampleTimes);

        [analogWaves, analogTimes] = extractAnalogNI(meta, dataArray, sampleTimes);
        subplot(4, 1, 2);
        hold on
        plot(analogTimes', analogWaves', ...
            '.', 'MarkerSize', markerSize, ...
            'Color', markerColor);

    else
        describeIM(meta, binName);
        [dataArray, sampleTimes] = readDataIM(meta, binName, binPath, startTime, duration);
        [syncWave, syncTimes] = extractSyncIM(meta, dataArray, sampleTimes);

        [apWaves, apTimes] = extractApIM(meta, dataArray, sampleTimes);
        subplot(4, 1, 3);
        hold on
        plot(apTimes', apWaves', ...
            '.', 'MarkerSize', markerSize, ...
            'Color', markerColor);

        [lfWaves, lfTimes] = extractLfIM(meta, dataArray, sampleTimes);
        subplot(4, 1, 4);
        hold on
        plot(lfTimes', lfWaves', ...
            '.', 'MarkerSize', markerSize, ...
            'Color', markerColor);
    end

    subplot(4, 1, 1);
    hold on
    plot(syncTimes', syncWave', ...
        '.', 'MarkerSize', markerSize, ...
        'Color', markerColor);
    legendNames{ii} = binName;
end

subplot(4, 1, 1);
legend(legendNames, "Location", "best")
set(gca, 'XGrid', 'on')
xlim(gca, [startTime, startTime + duration])
ylabel('sync V or bool')

subplot(4, 1, 2);
set(gca, 'XGrid', 'on')
xlim(gca, [startTime, startTime + duration])
ylabel('NI analog V')

subplot(4, 1, 3);
set(gca, 'XGrid', 'on')
xlim(gca, [startTime, startTime + duration])
ylabel('IM ap V')

subplot(4, 1, 4);
set(gca, 'XGrid', 'on')
xlim(gca, [startTime, startTime + duration])
ylabel('IM lf V')

xlabel('sample time (s)')


function describeNI(meta, binName)
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


function describeIM(meta, binName)
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


function [dataArray, sampleTimes] = readDataNI(meta, binName, binPath, startTime, duration)
if nargin < 4 || isempty(startTime)
    startTime = 0;
end
if nargin < 5 || isempty(duration)
    duration = str2double(meta.fileTimeSecs) - startTime;
end

sampleRate = str2double(meta.niSampRate);
samp0 = floor(startTime * sampleRate);
nSamp = ceil(duration * sampleRate);
[dataArray, dataIndices] = ReadBinBen(samp0, nSamp, meta, binName, binPath);
sampleTimes = startTime + (dataIndices / sampleRate);


function [syncWave, syncTimes] = extractSyncNI(meta, dataArray, sampleTimes)
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


function [analogWaves, analogTimes] = extractAnalogNI(meta, dataArray, sampleTimes)
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


function [dataArray, sampleTimes] = readDataIM(meta, binName, binPath, startTime, duration)
if nargin < 4 || isempty(startTime)
    startTime = 0;
end
if nargin < 5 || isempty(duration)
    duration = str2double(meta.fileTimeSecs) - startTime;
end

sampleRate = str2double(meta.imSampRate);
samp0 = floor(startTime * sampleRate);
nSamp = ceil(duration * sampleRate);
[dataArray, dataIndices] = ReadBinBen(samp0, nSamp, meta, binName, binPath);
sampleTimes = startTime + (dataIndices / sampleRate);


function [syncWave, syncTimes] = extractSyncIM(meta, dataArray, sampleTimes)
digitalWord = 1;
syncChan = 6;
[syncWave, syncChannel] = ExtractDigital(dataArray, meta, digitalWord, syncChan);
syncTimes = sampleTimes(syncChannel, :);


function [apWaves, apTimes] = extractApIM(meta, dataArray, sampleTimes)
[AP] = ChannelCountsIM(meta);
apChannels = 1:AP;
dataArray = GainCorrectIM(dataArray, apChannels, meta);
apWaves = dataArray(apChannels, :);
apTimes = sampleTimes(apChannels, :);


function [lfWaves, lfTimes] = extractLfIM(meta, dataArray, sampleTimes)
[AP, LF] = ChannelCountsIM(meta);
lfChannelOffset = AP;
lfChannels = lfChannelOffset + (1:LF);
dataArray = GainCorrectIM(dataArray, lfChannels, meta);
lfWaves = dataArray(lfChannels, :);
lfTimes = sampleTimes(lfChannels, :);

