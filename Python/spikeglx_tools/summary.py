# Find SpikeGLX .bin files in a recording directory.
# Read each one and:
#   - print metadata to describe what's in the file
#   - plot the sync waveform
#   - plot any National Instruments analog data
#   - plot any Imec action potential data
#   - plot any Imec local field potential data
#
# This is a proof of concept based on SpikeGLX DemoReadSGLXData/readSGLX.py.
# BSH added interpretation from the SpikeGLX docs:
#  - https://billkarsh.github.io/SpikeGLX/Sgl_help/UserManual.html
#  - https://billkarsh.github.io/SpikeGLX/Sgl_help/Metadata_30.html

from pathlib import Path
import numpy as np
import matplotlib.pyplot as plt
from matplotlib import cm

from . import datafile
from . import datafile_ben

def plot_recording_summary(rec_dir, start_time=0, duration=30, bin_glob='**/*.bin'):

    print(f'Searching for .bin files matching "{bin_glob}" in {rec_dir}')

    rec_path = Path(rec_dir)
    bin_files = list(rec_path.rglob(bin_glob))
    bin_files.sort(key=lambda path: path.name)
    file_count = len(bin_files)

    print(f'Found {file_count} .bin files')

    if file_count < 1:
        return

    print(f'Plotting {duration} seconds of data starting at {start_time}, for each file.')

    fig, (ax1, ax2, ax3, ax4) = plt.subplots(4, 1)
    color_map = cm.get_cmap('plasma', file_count)
    plot_colors = dict(zip(bin_files, color_map.colors))
    event_line_styles = ['dotted', 'dashdot', 'dashed']

    end_time = start_time
    for bin_file in bin_files:

        event_glob = f'{bin_file.stem}*.txt'
        event_files = rec_path.rglob(event_glob)
        for index, event_file in enumerate(event_files):
            print(f'Found event file: {event_file}')
            with open(event_file) as f:
                event_times = [float(line.strip()) for line in f if not line.isspace()]
            line_style = event_line_styles[index % len(event_line_styles)]
            ax1.vlines(event_times, 0, 5, colors = [plot_colors[bin_file]], linestyles=[line_style])

        print(f'\nReading .meta and .bin for {bin_file.name}')

        meta = datafile.readMeta(bin_file)
        if (meta['typeThis'] == 'nidq'):
            describe_ni(meta, bin_file)
            [data_array, sample_times] = read_data_ni(meta, bin_file, start_time, duration)
            if sample_times.size:
                end_time = max(end_time, sample_times.max())
            
            (sync_wave, sync_times) = extract_sync_ni(meta, data_array, sample_times)
            ax1.plot(sync_times.transpose(), sync_wave.transpose(), '.', color=plot_colors[bin_file], label=bin_file.name)

            (analog_waves, analog_times) = extract_analog_ni(meta, data_array, sample_times)
            ax2.plot(analog_times.transpose(), analog_waves.transpose(), '.', color=plot_colors[bin_file])

        else:
            describe_im(meta, bin_file)
            [data_array, sample_times] = read_data_im(meta, bin_file, start_time, duration)
            if sample_times.size:
                end_time = max(end_time, sample_times.max())

            (sync_wave, sync_times) = extract_sync_im(meta, data_array, sample_times)
            ax1.plot(sync_times.transpose(), sync_wave.transpose(), '.', color=plot_colors[bin_file], label=bin_file.name)

            (ap_waves, ap_times) = extract_ap_im(meta, data_array, sample_times)
            ax3.plot(ap_times.transpose(), ap_waves.transpose(), '.', color=plot_colors[bin_file])

            (lf_waves, lf_times) = extract_lf_im(meta, data_array, sample_times)
            ax4.plot(lf_times.transpose(), lf_waves.transpose(), '.', color=plot_colors[bin_file])

    ax1.set_xlim(start_time, end_time)
    ax1.legend()
    ax1.grid(axis='x')
    ax1.set_ylabel('sync V or bool')

    ax2.set_xlim(start_time, end_time)
    ax2.grid(axis='x')
    ax2.set_ylabel('ni analog V')

    ax3.set_xlim(start_time, end_time)
    ax3.grid(axis='x')
    ax3.set_ylabel('im ap V')

    ax4.set_xlim(start_time, end_time)
    ax4.grid(axis='x')
    ax4.set_ylabel('im lf V')
    ax4.set_xlabel('sample time (s)')

    plt.show()


def describe_ni(meta, bin_file):
    print(f'\n{meta["typeThis"]} {meta["niDev1ProductName"]}: {bin_file.name}')

    [MN, MA, XA, DW] = datafile.ChannelCountsNI(meta)
    print(f'{MN} multiplexed neural signed 16-bit channels: {meta["niMNChans1"]}')
    print(f'{MA} multiplexed aux analog signed 16-bit channels: {meta["niMAChans1"]}')
    print(f'{XA} non-muxed aux analog signed 16-bit channels: {meta["niXAChans1"]}')
    print(f'{DW} non-muxed aux digital unsigned 16-bit words: {meta["niXDChans1"]}')

    sync_source_index = int(meta["syncSourceIdx"])
    if sync_source_index == 0:
        sync_source_name = 'none'
    elif sync_source_index == 1:
        sync_source_name = 'external'
    elif sync_source_index == 2:
        sync_source_name = 'NI'
    else:
        sync_source_name = 'IM'

    sync_ni_chan_type = int(meta["syncNiChanType"])
    if sync_ni_chan_type == 0:
        sync_type_name = 'digital'
    else:
        sync_type_name = 'analog'

    sync_ni_chan = int(meta["syncNiChan"])

    print(f'Sync signal (source {sync_source_name}) is on {sync_type_name} channel {sync_ni_chan}')

    file_time_secs = float(meta["fileTimeSecs"])
    sample_rate = float(meta["niSampRate"])
    n_saved_chans = int(meta["nSavedChans"])
    n_samples_expected = n_saved_chans * sample_rate * file_time_secs

    print(f'{file_time_secs:.2f} seconds at {sample_rate:.2f}Hz over {n_saved_chans} channels ({n_samples_expected:.0f} samples)')

    file_size_bytes = int(meta["fileSizeBytes"])
    print(f'{file_size_bytes} bytes at 2 bytes per sample ({file_size_bytes / 2:.0f} samples)')

    # Refers to overall recording(samples since g0 t0)
    print(f'First sample: {int(meta["firstSample"])}')

    print(f'User notes: {meta["userNotes"]}')


def describe_im(meta, bin_file):
    print(f'\n{meta["typeThis"]} probe {meta["imDatPrb_pn"]} (serial {meta["imDatPrb_sn"]}): {bin_file.name}')

    [AP, LF, SY] = datafile.ChannelCountsIM(meta)
    print(f'{AP} 16-bit action potential channels')
    print(f'{LF} 16-bit local field potential channels')
    print(f'{SY} single 16-bit sync input channel (bit 6)')
    print(f'Saved channels (AP 0:383, LF 384:767, SY 768): {meta["snsSaveChanSubset"]}')
    print(f'Full channel map: {meta["snsChanMap"]}')

    sync_source_index=int(meta["syncSourceIdx"])
    if sync_source_index == 0:
        sync_source_name='none'
    elif sync_source_index == 1:
        sync_source_name='external'
    elif sync_source_index == 2:
        sync_source_name='NI'
    else:
        sync_source_name='IM'

    print(f'Sync source is {sync_source_name}')

    file_time_secs=float(meta["fileTimeSecs"])
    sample_rate=float(meta["imSampRate"])
    n_saved_chans=int(meta["nSavedChans"])
    n_samples_expected=n_saved_chans * sample_rate * file_time_secs

    print(f'{file_time_secs:.2f} seconds at {sample_rate:.2f}Hz over {n_saved_chans} channels ({n_samples_expected:.0f} samples)')

    file_size_bytes=int(meta["fileSizeBytes"])
    print(f'{file_size_bytes} bytes at 2 bytes per sample ({file_size_bytes / 2:.0f} samples)')

    # Refers to overall recording(samples since g0 t0)
    print(f'First sample: {int(meta["firstSample"])}')

    print(f'User notes: {meta["userNotes"]}')


def read_data_ni(meta, bin_file, start_time = 0, duration = None):
    if duration == None or not np.isfinite(duration):
        duration = float(meta["fileTimeSecs"]) - start_time

    sample_rate = float(meta["niSampRate"])
    samp_0 = int(np.floor(start_time * sample_rate))
    n_samp = int(np.ceil(duration * sample_rate))
    [data_array, data_indices] = datafile_ben.read_bin_ben(samp_0, n_samp, meta, bin_file)
    sample_times = data_indices / sample_rate;
    return(data_array, sample_times)


def read_data_im(meta, bin_file, start_time = 0, duration = None):
    if duration == None or not np.isfinite(duration):
        duration = float(meta["fileTimeSecs"]) - start_time

    sample_rate = float(meta["imSampRate"])
    samp_0 = int(np.floor(start_time * sample_rate))
    n_samp = int(np.ceil(duration * sample_rate))
    [data_array, data_indices] = datafile_ben.read_bin_ben(samp_0, n_samp, meta, bin_file)
    sample_times = data_indices / sample_rate;
    return(data_array, sample_times)


def extract_sync_ni(meta, data_array, sample_times):
    sync_ni_chan = int(meta["syncNiChan"])
    sync_ni_chan_type = int(meta["syncNiChanType"])
    if sync_ni_chan_type == 0:
        digital_word = 0
        last_samp = data_array.shape[1] - 1
        [sync_wave, sync_channel] = datafile.ExtractDigital(data_array, 0, last_samp, digital_word, [sync_ni_chan], meta)
        sync_times = sample_times[[sync_channel], :]

    else:
        [MN, MA, _, _] = datafile.ChannelCountsNI(meta)
        sync_channel = MN + MA + sync_ni_chan
        sync_wave = datafile.GainCorrectNI(data_array[[sync_channel], :], [sync_channel], meta)
        sync_times = sample_times[[sync_channel], :]

    return (sync_wave, sync_times)


def extract_analog_ni(meta, data_array, sample_times):
    [MN, MA, XA, _] = datafile.ChannelCountsNI(meta)
    analog_channel_offset = MN + MA
    analog_channels = range(analog_channel_offset, analog_channel_offset + XA)
    sync_ni_chan_type = int(meta["syncNiChanType"])
    if sync_ni_chan_type == 1:
        # Exclude the analog sync channel, if any.
        sync_ni_chan = int(meta["syncNiChan"])
        analog_channels = [c for c in analog_channels if c != sync_ni_chan]

    voltage_array = datafile.GainCorrectNI(data_array, analog_channels, meta)
    analog_waves = voltage_array[analog_channels, :]
    analog_times = sample_times[analog_channels, :]
    return (analog_waves, analog_times)


def extract_sync_im(meta, data_array, sample_times):
    digital_word = 0
    sync_im_chan = 6
    last_samp = data_array.shape[1] - 1
    [sync_wave, sync_channel] = datafile.ExtractDigital(data_array, 0, last_samp, digital_word, [sync_im_chan], meta)
    sync_times = sample_times[[sync_channel], :]
    return (sync_wave, sync_times)


def extract_ap_im(meta, data_array, sample_times):
    [AP, _, _] = datafile.ChannelCountsIM(meta)
    ap_channels = range(0, AP)
    voltage_array = datafile.GainCorrectIM(data_array[ap_channels, :], ap_channels, meta)
    ap_waves = voltage_array[ap_channels, :]
    ap_times = sample_times[ap_channels, :]
    return (ap_waves, ap_times)


def extract_lf_im(meta, data_array, sample_times):
    [AP, LF, _] = datafile.ChannelCountsIM(meta)
    lf_channels = range(AP, AP + LF)
    voltage_array = datafile.GainCorrectIM(data_array[lf_channels, :], lf_channels, meta)
    lf_waves = voltage_array[range(LF), :]
    lf_times = sample_times[lf_channels, :]
    return (lf_waves, lf_times)
