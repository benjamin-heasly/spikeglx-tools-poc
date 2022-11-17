% Use TPrime on some sample data from the Pesaran lab.
% This is intended to be like the second stage of a processing pipeline.
% 
% The data are from two SpikeGLX recordings: "rec" and "rec1".
% "rec" has one gate saved, "g3".
% "rec1" has two gates saved, "g0" and "g1".
%
% This assumes the recodings have already been processed by CatGT, as in
% TryCatGT.m.  This uses the "Process and cat" operations from TryCatGT,
% but doesn't care about the "supercat" stuff.

clear;
clc;

% Locate the recordings on the local machine.
dataPath = '/home/ninjaben/Desktop/codin/gold-lab/spikeglx_data';
productsPath = fullfile(dataPath, 'products');

% Read in "FYI" data about files produced by CatGT.
% Pipeline TODO: receive these file paths from the previous step, 
% instead of magically "just knowing" them.
fyiFile = fullfile(productsPath, 'catgt_rec_g3', 'rec_g3_fyi.txt');
fyi = ReadKeyValuePairs(fyiFile);

% This "dryRun" flag is specific to our TPrime.m Matlab wrapper here.
% It's useful for testing argument and file parsing without having to run
% TPrime.
dryRun = false;


%% Set the stage -- compare sync pulse edge times for ni, imec0, and imec1.
niEdges = readmatrix(fyi.sync_ni);
imec0Edges = readmatrix(fyi.sync_imec0);
imec1Edges = readmatrix(fyi.sync_imec1);

xRange = [0, imec0Edges(end) + 1];

clf();
subplot(2, 1, 1);
hold off
plot(imec0Edges, imec1Edges - imec0Edges, 'b.', 'DisplayName', 'imec 1');
hold on
plot(imec0Edges, imec0Edges - imec0Edges, 'r.', 'DisplayName', 'imec 0');
plot(imec0Edges, niEdges - imec0Edges, 'k.', 'DisplayName', 'ni');
set(gca, 'XGrid', 'on', 'YGrid', 'on');
xlabel('imec 0 time (s)');
xlim(xRange);
ylabel('drift (s)');
title('clock drift as seen by imec 0');
subtitle('sync edge time - imec 0 sync edge time');
legend('Location', 'east');

yRange = get(gca, 'YLim');


%% Align ni aux analog events with respect to imec probe 0.
fromStreams = {fyi.sync_ni, fyi.times_ni_0, ''};
info = TPrime(1.0, fyi.sync_imec0, fromStreams, dryRun);
niEvents = readmatrix(fyi.times_ni_0);
alignedEvents = readmatrix(info.fromStreams{1,3});

subplot(2, 1, 2);
plot(alignedEvents, alignedEvents - niEvents, 'k*');
set(gca, 'XGrid', 'on', 'YGrid', 'on');
xlabel('imec 0 time (s)');
xlim(xRange);
ylim(yRange);
ylabel('correction (s)');
title('ni aux event times corrected by TPrime');
subtitle('corrected time wrt imec 0 - raw time wrt ni');
