# $ conda create --name spikeglx_tools numpy matplotlib
# $ conda activate spikeglx_tools
# $ python --version
# Python 3.11.0


from spikeglx_tools.summary import plot_recording_summary

data_dir = '/home/ninjaben/Desktop/codin/gold-lab/spikeglx_data/rec_g3';
plot_recording_summary(data_dir)
