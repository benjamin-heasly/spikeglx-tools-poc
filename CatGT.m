% Try calling CatGT and grabbing the output of CatGT.log.
% file:///home/ninjaben/Desktop/codin/gold-lab/spikeglx-tools/CatGT-linux/ReadMe.html
%
% So how do I read a file path and pick the parameters for GatGT?
% https://billkarsh.github.io/SpikeGLX/Sgl_help/UserManual.html#output-file-format-and-tools
% data-path/run-name_g0/run-name_g0_t0.nidq.bin
%
% I have
% /home/ninjaben/Desktop/codin/gold-lab/spikeglx_data/rec_g3/rec_g3_t0.nidq.bin
% dataPath = '/home/ninjaben/Desktop/codin/gold-lab/spikeglx_data'
% runName = 'rec'
% g = '3'
% t = '0'
% whichStreams = '-ni'
%
% I tried CatGT('/home/ninjaben/Desktop/codin/gold-lab/spikeglx_data', 'rec', '3', '0', '-ni')
%
% This was pretty quiet in the log
%     {'[Thd 140553659418432 CPU 0 11/10/22 14:22:48.704'}    {'Cmdline: CatGT -dir=/home/ninjaben/Desktop/codin/gold-lab/spikeglx_data -run=rec -g…'}
%     {'[Thd 140553659418432 CPU 0 11/10/22 14:22:48.735'}    {0×0 char                                                                              }
%
% It created a few new files in the data folder.  What are these?
%  - rec_g3_tcat.nidq.xa_1_500.txt -- looks like sync pulse edge times.
%  - rec_g3_tcat.nidq.meta -- subset of input metadata, plus CatGT notes
%  - rec_g3_fyi.txt -- info like location of "sync_ni" file, above.
%  - rec_g3_ct_offsets.txt -- not sure, got zeros
%
% I think I'll want this wrapper to account for new log messages and files.
% Maybe take the modification timestamp of CatGT.log as a reference.
%
% I think my sample data will need "-prb_fld", an option in SpikeGLX UI.
% Might also want -prb=0:1
%
function log = CatGT(dataPath, runName, g, t, whichStreams, options, whichRunIt)

if nargin < 6 || isempty(options)
    options = '';
end

if nargin < 7 || isempty(whichRunIt)
    whichRunIt = '/home/ninjaben/Desktop/codin/gold-lab/spikeglx-tools/CatGT-linux/runit.sh';
end

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
if status ~= 0
    error('Error running CatGT (status %d): %s', status, result);
end

% From the CatGt ReadMe.html:
% Results are placed next to source, named like this, with t-index = 'cat': path/run_name_g5_tcat.imec1.ap.bin.
% Errors and run messages are appended to CatGT.log in the current working directory.
log = readmatrix('CatGT.log', 'FileType', 'text', 'OutputType', 'char');
