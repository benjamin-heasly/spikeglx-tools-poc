from pathlib import Path
import os
import platform
import subprocess
import shutil
from datetime import datetime


def cat_gt(data_path, run_name, g, t, which_streams, options='', output_path=None, dry_run=False, which_runit=None):
    """Call CatGT with its various arguments for file coordinates and operators.
    Handle shell / command line integration.
    Parse and return results from the shell and files produced by CatGT.

    Return a dict with info about the CatGT run, including:
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
    attempt to locate a "runit.sh" or "runit.bat" in the same folder as a GatGT
    executable on the system path.
    """

    print('CatGT VVVVV')

    info = {};

    g_parts = g.split(':|,')
    first_g = g_parts[0]
    if not output_path:
        # Look here for the fyi file and offsets file, below.
        g_folder = f'{run_name}_g{first_g}'
        fyi_path = Path(data_path, g_folder)
    else:
        # Write new data files here.
        Path.mkdir(output_path, parents=True, exist_ok=True)
        options = f'{options} -dest={output_path}'

        # Look here for the fyi file and offsets file, below.
        if '-supercat' in options:
            g_folder = f'supercat_{run_name}_g{first_g}'
        else:
            g_folder = f'catgt_{run_name}_g{first_g}'

        fyi_path = Path(output_path, g_folder)

    if not which_runit:
        # There should be a "CatGT" executable somewhere on the system path.
        which_catgt = shutil.which('CatGT', mode=os.F_OK|os.X_OK)

        # However, the CatGT entrypoint is a "runit" script in the same dir.
        if which_catgt:
            catgt_path = Path(which_catgt)
            if platform.system() == "Windows":
                which_runit = Path(catgt_path.parent, 'runit.bat')
            else:
                which_runit = Path(catgt_path.parent, 'runit.sh')

    info['runit'] = which_runit
    runit_path = Path(which_runit)
    if runit_path.exists:
        print(f'CatGT runit script found: {runit_path}')
    else:
        raise Exception(f'CatGT runit script not found or not a file: {runit_path}')

    # Read the existing log file, which CatGT will append to when we call it.
    # From the CatGT ReadMe.html:
    # "Errors and run messages are appended to CatGT.log in the current working directory."
    working_dir = os.getcwd()
    log_path = Path(working_dir, 'CatGT.log')
    info['log_file'] = log_path.absolute()
    if log_path.exists():
        print(f'CatGT existing log file found: {log_path}')
        with open(info['log_file']) as f:
            old_log = [line.rstrip('\n') for line in f if not line.isspace()]
    else:
        print(f'CatGT log file does not exist yet at: {log_path}')
        old_log = []

    #Call CatGT with a big command line.
    command_args = f"-dir={data_path} -run={run_name} -g={g} -t={t} {which_streams} {options}"
    command_line = f"'{which_runit}' '{command_args}'"
    info['command'] = command_line
    info['pwd'] = working_dir
    print(f'CatGT working dir: {working_dir}')

    start = datetime.now()
    info['start'] = start
    print(f'CatGT start datetime: {str(start)}')

    print(f'CatGT command: {command_line}')
    if dry_run:
        print(f'CatGT dry run: skipping actual CatGT call.')
        info['status'] = 0
        info['result'] = 'test'
    else:
        print('CatGT starting...')
        completed = subprocess.run([f'{which_runit}', f'{command_args}'], text=True, stderr=subprocess.STDOUT)
        info['status'] = completed.returncode
        info['result'] = completed.stdout
        print(f'CatGT exit status {completed.returncode} with result: {completed.stdout}')

    finish = datetime.now()
    info['finish'] = finish
    duration = finish - start
    info['duration'] = duration
    print(f'CatGT end datetime: {str(finish)} ({duration} elapsed)')

    # Look for new log entries appended.
    with open(info['log_file']) as f:
        new_log = [line.rstrip('\n') for line in f if not line.isspace()]

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

# % Look for the "FYI" file that describes output files.
# info.fyiFile = fullfile(fyiPath, sprintf('%s_g%s_fyi.txt', runName, firstG));
# if isfile(info.fyiFile)
#     fprintf('CatGT fyi file found: %s\n', info.fyiFile);
#     info.fyi = ReadKeyValuePairs(info.fyiFile);

#     % The fyi file also mentions output dirs, in addition to individual files.
#     % Look for files written in these dirs.
#     % Note: these dirs might be under the given dataPath,
#     % or some other path if the "-dest=path" option was provided.
#     fyiFields = fieldnames(info.fyi);
#     info.outFiles = {};
#     for ii = 1:numel(fyiFields)
#         fieldName = fyiFields{ii};
#         outPath = info.fyi.(fieldName);
#         if startsWith(fieldName, 'outpath') && isfolder(outPath)
#             dirInfo = dir(outPath);
#             isNewFile = arrayfun(@(d)~d.isdir, dirInfo);
#             outFilePaths = cellfun(@(name)fullfile(outPath, name), {dirInfo(isNewFile).name}, 'UniformOutput', false);
#             info.outFiles = cat(1, info.outFiles, outFilePaths(:));
#         end
#     end

#     outFileCount = numel(info.outFiles);
#     fprintf('CatGT %d output files found.\n', outFileCount);
#     for ii = 1:outFileCount
#         fprintf('CatGT output file: %s\n', info.outFiles{ii});
#     end
# else
#     fprintf('CatGT fyi file not found at: %s\n', info.fyiFile);
# end


# % Look for the "offsets" file that has sample offsets for input file.
# if contains(options, '-supercat')
#     info.offsetsFile = fullfile(fyiPath, sprintf('%s_g%s_sc_offsets.txt', runName, firstG));
# else
#     info.offsetsFile = fullfile(fyiPath, sprintf('%s_g%s_ct_offsets.txt', runName, firstG));
# end
# if isfile(info.offsetsFile)
#     fprintf('CatGT offsets file found: %s\n', info.offsetsFile);
#     info.offsets = ReadKeyValuePairs(info.offsetsFile);
# else
#     fprintf('CatGT offsets file not found at: %s\n', info.offsetsFile);
# end

# fprintf('CatGT ^^^^^\n');

    return info
