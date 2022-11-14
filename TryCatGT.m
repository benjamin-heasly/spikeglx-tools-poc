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

dataPath = '/home/ninjaben/Desktop/codin/gold-lab/spikeglx_data';
runName = 'rec';
g = '3';
t = '0';
whichStreams = '-ni -ap -lf';
options = '-prb_fld -prb=0:1';
dryRun = false;
info = CatGT(dataPath, runName, g, t, whichStreams, options, dryRun)
