# $ conda create --name spikeglx_tools numpy matplotlib
# $ conda activate spikeglx_tools
# $ python --version
# Python 3.11.0

from pprint import pprint
from pathlib import Path

from spikeglx_tools.summary import plot_recording_summary
from spikeglx_tools.cli_wrappers import catgt


data_path = 'spikeglx_data';
run_name = 'rec'
g = '3';
t = '0';
which_streams = '-ni -ap -lf'
products_path = Path(data_path, 'products')
dry_run = True

options = '-xa=0,0,0,2.0,4.0,6,5';
options = options + ' -pass1_force_ni_ob_bin'
options = options + ' -prb=0:1 -prb_fld'
options = options + ' -out_prb_fld'
options = options + ' -loccar=2,8'
options = options + ' -apfilter=butter,12,300,10000'
options = options + ' -lffilter=butter,12,1,500'

info = catgt(data_path, run_name, g, t, which_streams, options=options, output_path=products_path, dry_run=dry_run)
pprint(info)

plot_recording_summary(info['fyi']['outpath_top'])
