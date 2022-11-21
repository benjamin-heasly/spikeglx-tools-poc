% Use CatGT on some sample data from the Pesaran lab.
% This is intended to be like the first stage of a processing pipeline.
% 
% The data are from two SpikeGLX recordings: "rec" and "rec1".
% "rec" has one gate saved, "g3".
% "rec1" has two gates saved, "g0" and "g1".
%
% Here's how I get them from where I parked them in cloud storage:
% gsutil cp -r gs://tripledip-pesaran-lab-data/spikeglx_data/rec_g3 /home/ninjaben/Desktop/codin/gold-lab/spikeglx_data
% gsutil cp -r gs://tripledip-pesaran-lab-data/spikeglx_data/rec1_g0 /home/ninjaben/Desktop/codin/gold-lab/spikeglx_data
% gsutil cp -r gs://tripledip-pesaran-lab-data/spikeglx_data/rec1_g1 /home/ninjaben/Desktop/codin/gold-lab/spikeglx_data
%
% In total this is about 15GB + 15GB + 6GB = 36GB.
% This process will rewrite the data twice, tripling it 108GB -- ouch!
% On my old Thinkpat T450s, this will take about half an hour.
%
% So what are the steps?
%
% For each recoding "rec" and "rec1", use CatGT to preprocess the
% individual data files and concatenate the gates and trials into "cat"
% files -- in this case combine the "g0" and the "g1" from "rec1".
% This first pass over each gate is configurable.
% In this demo, it will do several things for each recording:
%  - Extract pulse times from the 1Hz sync signal present in all data
%  streams -- including NI cards and Imec NP probes.
%  - Extract pulse times from an auxiliary signal on the same NI card.
%  - Realign Imec channel data to account for ADC multiplexing.
%  - Run a bandpass butterworth filter over Imec AP and LF signals.
%  - Run a common averge reference filter to denoise Imec AP signals.
%
% The processing above is to clean up each recoding and consolidate data
% files into "cat" files that contain all the "gates" and "trials".  The
% next step is to "supercat" across the "cat" files, to consolidate further
% into files that represent multiple runs.  This uses the same CatGT util.
%
% CatGT does a lot, has some arcane-seeming conventions and a lot of
% parameters!  I'll try to comment what I've learned from the docs (CatGT
% ReadMe.html, which is thorough and good).

clear;
clc;

% Locate the recordings on the local machine.
dataPath = '/home/ninjaben/Desktop/codin/gold-lab/spikeglx_data';

% Personal preference: write derived data into a separate folder.
% CatGT can write into the original folder if desired.
productsPath = fullfile(dataPath, 'products');

% This "dryRun" flag is specific to our CatGT.m Matlab wrapper here.
% It's useful for testing argument and file parsing without having to run
% CatGT again -- it can take a while.
dryRun = false;

%% Process and "cat" the first recording, "rec".

% The first several parameters to CatGT are coordinates that tell it which
% data files to look for.  CatGT follows the same folder layout and naming
% convention as SpikeGLX -- so we don't have to chase files, we can just
% declare the coordinates we care about.
recRunName = 'rec';
recG = '3';
recT = '0';

% The next parameter tells CatGT which data "streams" we want to process.
% In this case we want to process a NI card, Neuropixels AP signals, and
% Neuropixels LF signals.
streams = '-ni -ap -lf';

% CatGT takes *many* options that specify primary behaviors like event
% extraction and signal filtering, as well as secondary behaviors like
% where to write files.  We'll build these up a few at a time.

% Starting with the NI data stream.

% Extract pulse event times (-xa) from NI (0,0) analog channel 0.
% Pulses start at 2V, must rise to 4V, and must last 6ms +/1 5ms.
options = '-xa=0,0,0,2.0,4.0,6,5';

% Copy the NI data file to the output folder, even if it's unchanged --
% even if there's only one file to "concatenate".
options = [options ' -pass1_force_ni_ob_bin'];

% Now for the Imec Neuropixels probes.

% These sample data files recorded from two imec probes: "0" and "1".
% In SpikeGLX the option was checked to save each in it's own subfolder.
options = [options ' -prb=0:1 -prb_fld'];

% Save outputs with each probe in its own subfolder, like the inputs.
options = [options ' -out_prb_fld'];

% Perform common-average referencing on the AP signals.
% Use a ring-shaped region around each recording site, 2-8 sites away.
options = [options ' -loccar=2,8'];

% Rewrite AP signals after a bandpass Butterworth filter 300Hz-10,000Hz.
options = [options ' -apfilter=butter,12,300,10000'];

% Rewrite LF signals after a bandpass Butterworth filter 1Hz-500Hz.
options = [options ' -lffilter=butter,12,1,500'];

% Process the "rec" data.
% Parse some metadata and output logging and file info into a struct.
recInfo = CatGT(dataPath, recRunName, recG, recT, streams, options, productsPath, dryRun);


%% Process and "cat" the other recording, "rec1".

% The file coordinates are different for this recording.
rec1RunName = 'rec1';
rec1G = '0:1';
rec1T = '0';

% But the stream selection and options are the same as before.
rec1Info = CatGT(dataPath, rec1RunName, rec1G, rec1T, streams, options, productsPath, dryRun);


%% "Supercat" the two recordings together.

% The "cat" results tell us useful things in a so-called "FYI" file.
% One of these is the "supercat element" that we can pass on to the next
% step, the "supercat".

% Supercat all the same data streams as above: '-ni -ap -lf'
supercatStreams = streams;

supercatOptions = sprintf('-supercat=%s%s', ...
    recInfo.fyi.supercat_element, rec1Info.fyi.supercat_element);

% Tell supercat to join the runs together along an exact 1Hz sync edge.
supercatOptions = [supercatOptions ' -supercat_trim_edges'];

% Supercat should join extracted NI analog events.
% Why do we need this?  ReadMe.html says
% "required if joining this extractor type"
% "Note that you need to provide the same extractor parameters that were
% used for the individual runs. Although supercat doesn't do extraction, it
% needs the parameters to create filenames."
% OK.
supercatOptions = [supercatOptions ' -xa=0,0,0,2.0,4.0,6,5'];

% Save outputs with each probe in its own subfolder, like the inputs.
supercatOptions = [supercatOptions ' -out_prb_fld'];

% Supercat the same two imec probes as above.
supercatOptions0 = [supercatOptions ' -prb=0:1 -prb_fld'];

% CatGT will ignore the file "coordinates" we used above
% in favor of the "-supercat=..." argument we constructed here.
% It's still useful to pass them, to help the script locate output files.
supercatInfo0 = CatGT(dataPath, recRunName, recG, recT, supercatStreams, supercatOptions0, productsPath, dryRun);

% A bug?
% CatGT was only supercat-ing one imec probe at a time, despite -prb=0:1.
supercatOptions1 = [supercatOptions ' -prb=1 -prb_fld'];
supercatInfo1 = CatGT(dataPath, recRunName, recG, recT, supercatStreams, supercatOptions1, productsPath, dryRun);

% There may be more bugs with supercat.
% It appears the LF data are being truncated to 1 sample!
% It seems like supercat just doesn't always finish.

%% Plot the filtered waveforms and extracted events.

% Read 1Hz sync pulse and NI analong event times for plotting.
% The "FYI" file produced by CatGT gives meaning to the output files!
niSync = readmatrix(supercatInfo0.fyi.sync_ni);
niOther = readmatrix(supercatInfo0.fyi.times_ni_0);
imec0Sync = readmatrix(supercatInfo0.fyi.sync_imec0);
imec1Sync = readmatrix(supercatInfo1.fyi.sync_imec1);

% Choose a plot time range that spans the "join" between "rec" and "rec1".
% The "offsets" file produced by CatGT accounts for the "join" times.
joinOffsets = supercatInfo0.offsets.sec_imap0;
joinTimes = str2double(split(joinOffsets));
plotDuration = 30;
plotStart = joinTimes(2) - plotDuration / 2;

% Plot a summary of all data in the supercat folder! 
PlotSpikeGlxRecordingSummary(supercatInfo0.fyi.outpath_top, plotStart, plotDuration);

% Overlay extracted event times on the same plots.
subplot(4,1,1);
hold on
plot(imec0Sync, ones(size(imec0Sync)), 'r*', 'DisplayName', 'sync_imec0');
plot(imec1Sync, ones(size(imec1Sync)), 'mo', 'DisplayName', 'sync_imec1');
plot(niSync, 4.5*ones(size(niSync)), 'g*', 'DisplayName', 'sync_ni');

subplot(4,1,2);
hold on
plot(niOther, 4.5*ones(size(niOther)), 'g*', 'DisplayName', 'times_ni_0');
