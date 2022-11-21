# Read from the binary file starting at sample number samp0
# up through nSamp samples (or as much as is available).
#
# To limit memory usage, read the data in chunks of fixed
# number of samples.  For each chunk, keep only the min and
# max.
#
# Min and max have property of being actual, raw sample
# values from the binary data.  This facilitates downstream
# processing that makes assumptions about possible values
# or their encodings (for example, digital words).  Other
# summary stats, like mean, lack this property.  Median
# would also have this property, but it's slower to compute.
#
# Return an array of mins and maxes from all chunks
# in the specified range.  Also return a corresponding
# array of sample numbers where the mins and maxs occured.
#
# Both retuned arrays have dimensions [n_chan, 2 * n_chunks],
# where n_chunks = ceil(n_samp / samp_per_chunk).
#
# IMPORTANT: samp_0 and n_samp must be integers.

import numpy as np

def read_bin_ben(samp_0, n_samp, meta, bin_file, samp_per_chunk=100):
    n_chan = int(meta["nSavedChans"])
    n_file_samp = int(int(meta["fileSizeBytes"]) / (2 * n_chan))

    samp_0 = max(samp_0, 0)
    n_samp = min(n_samp, n_file_samp - samp_0)
    n_chunks = int(np.ceil(n_samp / samp_per_chunk))

    output_size = (n_chan, 2 * n_chunks)
    values = np.zeros(output_size)
    indices = np.zeros(output_size, dtype='int64')

    for ii in range(n_chunks):
        chunk_samp_0 = ii * samp_per_chunk + samp_0
        chunk_n_samp = min(samp_per_chunk, n_file_samp - chunk_samp_0)
        chunk_size = (n_chan, chunk_n_samp)
        chunk_offset = chunk_samp_0 * 2 * n_chan
        chunk_data = np.memmap(bin_file, dtype='int16', mode='r', shape=chunk_size, offset=chunk_offset, order='F')

        min_inds = chunk_data.argmin(1, keepdims=True)
        mins = np.take_along_axis(chunk_data, min_inds, 1)
        min_samps = min_inds + chunk_samp_0

        max_inds = chunk_data.argmax(1, keepdims=True)
        maxes = np.take_along_axis(chunk_data, max_inds, 1)
        max_samps = max_inds + chunk_samp_0

        result_start = np.ones((n_chan, 1), dtype='int64') * (ii * 2)
        result_end = result_start + 1
        np.put_along_axis(values, result_start, mins, 1)
        np.put_along_axis(values, result_end, maxes, 1)
        np.put_along_axis(indices, result_start, min_samps, 1)
        np.put_along_axis(indices, result_end, max_samps, 1)

    return (values, indices)
    