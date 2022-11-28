# $ conda create --name spikeglx_tools numpy matplotlib
# $ conda activate spikeglx_tools
# $ python --version
# Python 3.11.0

from pathlib import Path

from spikeglx_tools.summary import plot_recording_summary
from spikeglx_tools.cat_gt import cat_gt

data_dir = '/home/ninjaben/Desktop/codin/gold-lab/spikeglx_data/rec_g3';
#plot_recording_summary(data_dir)


data_path = '/home/ninjaben/Desktop/codin/gold-lab/spikeglx_data';
run_name = 'cheese' #'rec'
g = '3';
t = '0';
which_streams = '-ni -ap -lf'
products_path = Path(data_path, 'products')
dry_run = False
which_runit = '/home/ninjaben/Desktop/codin/gold-lab/spikeglx-tools/CatGT-linux/runit.sh'
info = cat_gt(data_path, run_name, g, t, which_streams, output_path=products_path, dry_run=dry_run, which_runit=which_runit)
print(info)
