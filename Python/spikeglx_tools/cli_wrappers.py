from pathlib import Path
from glob import glob
import os
import platform
import subprocess
from datetime import datetime, timezone


def read_floats(file_path):
    "Read floats from a text file with one float value per line."

    with open(file_path) as f:
        floats = [float(line.strip()) for line in f if not line.isspace()]
    return floats

def read_key_value_pairs(file_path, separator='='):
    """ Read a file of key-value pairs into a dict.

    Could be SpikeGLX "meta" ini file: lines with with separator="=",
    or any file with lines and separators, like "=" or ":".
    """
    info = {}
    with open(file_path) as f:
        for line in f:
            if not line.isspace():
                [key, value] = line.split(separator, maxsplit=1)
                info[key.strip()] = value.strip()
    return info


def catgt(data_path, run_name, g, t, which_streams, options='', output_path=None, dry_run=False, which_runit=None):
    """ Call CatGT with its various arguments for file coordinates and operators.
    Handle shell / command line integration.
    Parse and return results from the shell and files produced by CatGT.

    Returns a dict with info about the CatGT run, including:
    - shell command and execution status and result
    - datetimes and duration around the CatGT call
    - CatGT log file in the working directory, 'CatGT.log'
    - CatGT "offsets" file that has sample offsets for each file in a run
    - CatGT "fyi" file that describes other output files and folders
    - any files found in the output folders

    This util is intended to instantiate documention from the CatGT
    ReadMe.html, for convenience and integration into pipelines.
    The ReadMe.html comes with the CatGT download, eg CatGT-linux/ReadMe.html.

    The first five positional args give "coordinates" that CatGT uses to locate
    input files to be processed:
    data_path -- folder where SpikeGLX is configured to write data
    run_name -- name of a recording session in SpikeGLX, maybe 'rec'
    g -- one or more SpikeGLX "gate" indexes, maybe '0:1'
    t -- one or more SpikeGLX "trigger" indexes, maybe '0:7'
    which_streams -- types of acquisition stream/card, maybe '-ni -ap -lf'

    The "options" keyword arg specifies for primary processing tasks like event
    detection, band pass filtering, etc.  The same arg can also specify flags 
    etc. for secondary behaviors, like where to write output files and what to
    do if files or samples are missing. I'll defer to the CatGT ReadMe.html to
    describe these.  All the options can be passed to this util as one string,
    for example '-prb_fld -prb=0:1'.  The default is an empty string for default
    operations.

    The "output_path" keyword arg  be supplied to specify where new files should be
    written.  When supplied, it gets added to the options above as
    f"-dest={output_path}".

    The "dry_run" keyword arg is False by default.  If set to True this util will
    skip invoking CatGT but still try to print and parse everything else like
    normal.

    The "which_runit" keyword arg can be the file path to CatGT's "runit" shell
    script on the current machine.  If omitted, this util makes a best-effort
    attempt to locate a "runit.sh" or "runit.bat" in the same folder as a "CatGT"
    file, somewhere in or below the current directory.
    """

    print('CatGT VVVVV')

    info = {};

    working_dir = os.getcwd()
    info['pwd'] = working_dir
    print(f'CatGT working dir: {working_dir}')

    g_parts = g.replace(':', ',').split(',')
    first_g = g_parts[0]
    if not output_path:
        # Look here for the fyi file and offsets file, below.
        g_folder = f'{run_name}_g{first_g}'
        fyi_dir = Path(data_path, g_folder)
    else:
        # Write new data files here.
        Path.mkdir(output_path, parents=True, exist_ok=True)
        options = f'{options} -dest={output_path}'

        # Look here for the fyi file and offsets file, below.
        if '-supercat' in options:
            g_folder = f'supercat_{run_name}_g{first_g}'
        else:
            g_folder = f'catgt_{run_name}_g{first_g}'

        fyi_dir = Path(output_path, g_folder)

    if not which_runit:
        # Search the current folder and subfolders for the "CatGT" executable.
        catgt_matches = glob('**/CatGT', root_dir=working_dir, recursive=True)
        if not catgt_matches:
            raise Exception(f'CatGT executable not found within pwd: {working_dir}')

        catgt_dir = Path(catgt_matches[0]).parent
        if platform.system() == "Windows":
            which_runit = Path(catgt_dir, 'runit.bat')
        else:
            which_runit = Path(catgt_dir, 'runit.sh')

    runit_path = Path(which_runit).absolute()
    if runit_path.exists():
        print(f'CatGT runit script found: {runit_path}')
    else:
        raise Exception(f'CatGT runit script not found or not a file: {runit_path}')

    info['runit'] = str(runit_path)

    # Read the existing log file, which CatGT will append to when we call it.
    # From the CatGT ReadMe.html:
    # "Errors and run messages are appended to CatGT.log in the current working directory."
    log_file = Path(working_dir, 'CatGT.log')
    info['log_file'] = str(log_file)
    if log_file.exists():
        print(f'CatGT existing log file found: {log_file}')
        with open(info['log_file']) as f:
            old_log = [line.rstrip() for line in f if not line.isspace()]
    else:
        print(f'CatGT log file does not exist yet at: {log_file}')
        old_log = []

    #Call CatGT with a big command line.
    command_args = f"-dir={data_path} -run={run_name} -g={g} -t={t} {which_streams} {options}"
    command_line = f"'{runit_path}' '{command_args}'"
    info['command'] = command_line

    start = datetime.now(timezone.utc)
    info['start'] = str(start)
    print(f'CatGT start datetime: {start}')

    print(f'CatGT command: {command_line}')
    if dry_run:
        print(f'CatGT dry run: skipping actual CatGT call.')
        info['status'] = 0
        info['result'] = 'test'
    else:
        print('CatGT starting...')
        completed = subprocess.run([f'{runit_path}', f'{command_args}'], text=True, stderr=subprocess.STDOUT)
        info['status'] = completed.returncode
        info['result'] = completed.stdout
        print(f'CatGT exit status {completed.returncode} with result: {completed.stdout}')

    finish = datetime.now(timezone.utc)
    info['finish'] = str(finish)
    duration = finish - start
    info['duration'] = str(duration)
    print(f'CatGT end datetime: {finish} ({duration} elapsed)')

    # Look for new log entries appended.
    if log_file.exists():
        with open(info['log_file']) as f:
            new_log = [line.rstrip() for line in f if not line.isspace()]
    else:
        new_log = []

    info['log_entries'] = new_log
    old_log_count = len(old_log)
    new_log_count = len(new_log)
    diff_log_count = new_log_count - old_log_count
    print(f'CatGT wrote {diff_log_count} new log entries ({new_log_count} total).')
    new_log_entries = new_log[old_log_count:new_log_count]
    info['new_log_entries'] = new_log_entries
    for entry in new_log_entries:
        print(f'CatGT log entry: {entry}')

    if info['status'] != 0:
        raise Exception(f'CatGT nonzero exit status {info["status"]} with result: {info["result"]}')

    # Look for the "FYI" file that describes output files.
    fyi_file = Path(fyi_dir, f'{run_name}_g{first_g}_fyi.txt')
    info['fyi_file'] = str(fyi_file)
    if fyi_file.exists():
        print(f'CatGT fyi file found: {fyi_file}')
        fyi = read_key_value_pairs(fyi_file)
        info['fyi'] = fyi

        # The fyi file also mentions output dirs, in addition to individual files.
        # Look for files written in these dirs.
        # Note: these dirs might be under the given dataPath,
        # or some other path if the "-dest=path" option was provided.
        out_files = []
        for key in fyi:
            if key.startswith('outpath'):
                out_path = Path(fyi[key])
                if out_path.exists() and out_path.is_dir():
                    files = [str(Path(out_path, f.name)) for f in os.scandir(out_path) if f.is_file]
                    out_files = out_files + files

        info['out_files'] = out_files
        print(f'CatGT {len(out_files)} output files found.')
        for out_file in out_files:
            print(f'CatGT output file: {out_file}')
    else:
        print(f'CatGT fyi file not found at: {fyi_file}')


    # Look for the "offsets" file that has sample offsets for input file.
    if '-supercat' in options:
        offsets_file = Path(fyi_dir, f'{run_name}_g{first_g}_sc_offsets.txt')
    else:
        offsets_file = Path(fyi_dir, f'{run_name}_g{first_g}_ct_offsets.txt')
    info['offsets_file'] = str(offsets_file)
    if offsets_file.exists():
        print(f'CatGT offsets file found: {offsets_file}')
        info['offsets'] = read_key_value_pairs(offsets_file, ':')
    else:
        print(f'CatGT offsets file not found at: {offsets_file}')

    print('CatGT ^^^^^')

    return info


def tprime(to_stream, from_streams, sync_period=1.0, dry_run=False, which_runit=None):
    """ Call TPrime to align event times with sync times.
    Handle shell / command line integration.
    Parse and return results from the shell and files produced by TPrime.

    Returns a struct with info about the TPrime run, including:
    - shell command and execution status and result
    - datetimes and duration around the TPrime call
    - TPrime log file in the working directory, 'TPrime.log'
    - output files produced

    This util is intended to instantiate documention from the TPrime
    ReadMe.txt, for convenience and integration into pipelines.
    The Readme.txt comes with the TPrime download, eg TPrime-linux/ReadMe.txt

    The to_stream positional arg is the path to a file containing sync pulse edge
    event times, for example one of the sync_ni or sync_imec files produced
    by CatGT.  This declares the canonical stream to which other event
    streams will be aligned.

    The from_streams positional arg is a list of triples describing event streams
    that should be aligned to the canonical stream.  Each element of from_streams
    should be a tuple of three file names, like this:

    [ ... (edges_file, events_file, out_file),
          (edges_file, events_file, out_file), ...]

    Each list element contains the following triple items:
    edges_file -- sync pulse edge event times from any event stream,
                 especially a stream other than to_stream.
    events_file -- other event times from the same event stream as
                   edges_file, to be realigned with respect to to_stream.
    out_file -- the name of the output file where realigned event times
                should be written.  If out_file is None, a unique path will
                be automatically chosen, in the same dir as events_file.

    The sync_period keyword arg is the period of the sync pulse recoded by
    each data stream -- usually 1.0 (Hz).

    The dry_run keyword arg is false by default.  If set to true, this util
    will skip invoking TPrime but still try to print and parse everything
    else like normal.

    The which_runit keyword arg can be the file path to TPrimes's "runit" shell
    script on the current machine.  If omitted, this util makes a best-effort
    attempt to locate a "runit.sh" or "runit.bat" in the same folder as a "TPrime"
    file, somewhere in or below the current directory.
    """

    print('TPrime VVVVV')

    info = {}

    working_dir = os.getcwd()
    info['pwd'] = working_dir
    print(f'TPrime working dir: {working_dir}')

    if not which_runit:
        # Search the current folder and subfolders for the "TPrime" executable.
        tprime_matches = glob('**/TPrime', root_dir=working_dir, recursive=True)
        if not tprime_matches:
            raise Exception(f'TPrime executable not found within pwd: {working_dir}')

        tprime_dir = Path(tprime_matches[0]).parent
        if platform.system() == "Windows":
            which_runit = Path(tprime_dir, 'runit.bat')
        else:
            which_runit = Path(tprime_dir, 'runit.sh')

    runit_path = Path(which_runit).absolute()
    if runit_path.exists():
        print(f'TPrime runit script found: {runit_path}')
    else:
        raise Exception(f'TPrime runit script not found or not a file: {runit_path}')

    info['runit'] = str(runit_path)

    # Read the existing log file, which TPrime will append to when we call it.
    # From the TPrime ReadMe.txt:
    # Run messages are appended to TPrime.log in the current working directory.
    log_file = Path(working_dir, 'TPrime.log')
    info['log_file'] = str(log_file)
    if log_file.exists():
        print(f'TPrime existing log file found: {log_file}')
        with open(info['log_file']) as f:
            old_log = [line.rstrip() for line in f if not line.isspace()]
    else:
        print(f'TPrime log file does not exist yet at: {log_file}')
        old_log = []

    # Auto-construct fromStream outFiles as needed.
    to_file = Path(to_stream)
    for index, from_stream in enumerate(from_streams):
        if len(from_stream) < 3 or not from_stream[2]:
            events_file = Path(from_stream[1])
            out_name = f'{events_file.stem}_WRT_{to_file.stem}{events_file.suffix}'
            out_file = Path(events_file.parent, out_name)
            from_streams[index] = (from_stream[0], from_stream[1], out_file)

    info['from_streams'] = from_streams

    # Call TPrime with a big command line.
    # runit.sh -syncperiod=1.0 -tostream=path/edgefile.txt -fromstream=5,path/edgefile.txt -events=5,path/in_eventfile.txt,path/out_eventfile.txt
    from_args = []
    for index, (edges_file, events_file, out_file) in enumerate(from_streams):
        from_args.append(f'-fromstream={index},{edges_file} -events={index},{events_file},{out_file}')

    command_args = f'-syncperiod={sync_period} -tostream={to_file} {" ".join(from_args)}'
    command_line = f"'{runit_path}' '{command_args}'"
    info['command'] = command_line

    start = datetime.now(timezone.utc)
    info['start'] = str(start)
    print(f'TPrime start datetime: {start}')

    print(f'TPrime command: {command_line}')
    if dry_run:
        print(f'TPrime dry run: skipping actual TPrime call.')
        info['status'] = 0
        info['result'] = 'test'
    else:
        print('TPrime starting...')
        completed = subprocess.run([f'{runit_path}', f'{command_args}'], text=True, stderr=subprocess.STDOUT)
        info['status'] = completed.returncode
        info['result'] = completed.stdout
        print(f'TPrime exit status {completed.returncode} with result: {completed.stdout}')

    finish = datetime.now(timezone.utc)
    info['finish'] = str(finish)
    duration = finish - start
    info['duration'] = str(duration)
    print(f'TPrime end datetime: {finish} ({duration} elapsed)')

    # Look for new log entries appended.
    if log_file.exists():
        with open(info['log_file']) as f:
            new_log = [line.rstrip() for line in f if not line.isspace()]
    else:
        new_log = []

    info['log_entries'] = new_log
    old_log_count = len(old_log)
    new_log_count = len(new_log)
    diff_log_count = new_log_count - old_log_count
    print(f'TPrime wrote {diff_log_count} new log entries ({new_log_count} total).')
    new_log_entries = new_log[old_log_count:new_log_count]
    info['new_log_entries'] = new_log_entries
    for entry in new_log_entries:
        print(f'TPrime log entry: {entry}')

    if info['status'] != 0:
        raise Exception(f'TPrime nonzero exit status {info["status"]} with result: {info["result"]}')

    print('TPrime ^^^^^')

    return info
