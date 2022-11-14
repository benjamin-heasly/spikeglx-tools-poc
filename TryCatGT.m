% Try calling CatGT to do something on the sample data we have.
% Trying to keep this somewhat realistic usage separate from the CatGT
% util, which deals with fussy details of calling the tool and reading
% results.
%
% So how do I read a file path and pick the parameters for GatGT?
% I say for this data file:
%   data-path/run-name_g0/run-name_g0_t0.nidq.bin
%
% From these docs,
%   https://billkarsh.github.io/SpikeGLX/Sgl_help/UserManual.html#output-file-format-and-tools
% It seems like this gives
%   dataPath = '/home/ninjaben/Desktop/codin/gold-lab/spikeglx_data'
%   runName = 'rec'
%   g = '3'
%   t = '0'
%   whichStreams = '-ni'
%
% In addition, for the imec probe files, I think we'll want
%  -prb_fld
%  -prb=0:1
%
% FWIF, on about 15GB of data with one NI file and 2 imec files, on my 2015
% Thinkpad T450s, it took about 8 minutes for CatGT to process the sync
% pulses and rewrite the ap and lf data (I'm not sure how this was changed)
% with options '-ni -ap -lf -prb_fld -prb=0:1'

clear;
clc;

dryRun = false;

% Locate the recording data by coordinates.
dataPath = '/home/ninjaben/Desktop/codin/gold-lab/spikeglx_data';
runName = 'rec';
g = '3';
t = '0:0';

% Extract events from NI analog channels.
%   - The 1Hz sync pulse on channel 1, which is extracted by default.
%   - Some ther .25Hz blips on channel 0, using an '-xa' extractor.
whichStreams = '-ni';

% -xa=0,0,2,3.0,4.5,25     ;extract pulse signal from analog chan (js,ip,word,thresh1(V),thresh2(V),millisec)
% js is stream type, 0 = ni
% ip is stream index, which is 0 for ni -- "(there is only one NI stream)"
% word is which digital word to look at
% I think this means channel index, from subset of NI channels recorded
% I think the .25Hz signal is on channel 0.
% Then the next 2 are voltage thresholds
% and the last is a duration threshold -- for some reason 0 works best???
% oh, it's excluding pulses based on +/- 20% tolerance of duration
% I can choose my own tolerance as an extra param after the duration!
% This dataset must have some really short pulses in it.
options = '-xa=0,0,0,2.0,4.0,6,5';
niInfo = CatGT(dataPath, runName, g, t, whichStreams, options, dryRun);

% The fyi file gives meaning to the various output file names!
niSync = readmatrix(niInfo.fyi.sync_ni);
niOther = readmatrix(niInfo.fyi.times_ni_0);
plot(niSync, ones(size(niSync)), '.', niOther, ones(size(niOther)), '*');
