# Gravitational Wave Analysis on a Cluster

A practical guide to fetching GW strain data, splitting it into segments, writing job scripts, submitting to a cluster, and collecting results.

---

## Overview

The general workflow is:

1. **Fetch data** — download strain data from GWOSC or a local archive to shared storage
2. **Split segments** — divide the data into chunks, one per cluster job
3. **Write a job script** — define resources and the analysis command
4. **Submit jobs** — hand off to SLURM or HTCondor
5. **Collect results** — merge per-job outputs into a final dataset

---

## 1. Fetch the Data

Use `gwpy` to pull strain data from the GWOSC open data API and write it to a shared filesystem (NFS, GPFS, Lustre) that all cluster nodes can read.

```python
from gwpy.timeseries import TimeSeries

# Fetch ~4096 s of H1 strain around GW150914
data = TimeSeries.fetch_open_data('H1', 1126259462, 1126259462 + 4096)
data.write('segment_0.hdf5')
```

**Tips:**
- Store files on a shared path (e.g. `/scratch/project/gw_data/`) — not on a local disk that only one node can see.
- For large datasets, pre-fetch everything in a single serial job before launching the array.
- Supported detectors: `'H1'` (LIGO Hanford), `'L1'` (LIGO Livingston), `'V1'` (Virgo).

---

## 2. Split Into Segments

Generate a segment list and save it as JSON so each cluster task can look up its own time range by index.

```python
import json

start    = 1126259462   # GPS start
end      = 1126359462   # GPS end (~27.8 hours)
seg_len  = 4096         # seconds per segment

segments = [(t, t + seg_len) for t in range(start, end, seg_len)]

with open('segments.json', 'w') as f:
    json.dump(segments, f, indent=2)

print(f"Generated {len(segments)} segments")
```

This produces `segments.json` with entries like:

```json
[
  [1126259462, 1126263558],
  [1126263558, 1126267654],
  ...
]
```

---

## 3. Write the Analysis Script

`run_analysis.py` loads the segment for its task index, runs the pipeline, and writes one output file.

```python
import argparse, json
import numpy as np
import h5py
from gwpy.timeseries import TimeSeries

parser = argparse.ArgumentParser()
parser.add_argument('--segment-index', type=int, required=True)
parser.add_argument('--segments',      type=str, default='segments.json')
parser.add_argument('--outdir',        type=str, default='results/')
args = parser.parse_args()

with open(args.segments) as f:
    segments = json.load(f)

t_start, t_end = segments[args.segment_index]
print(f"Processing segment {args.segment_index}: {t_start} – {t_end}")

# Load data
data = TimeSeries.read(f'data/segment_{args.segment_index}.hdf5')

# --- Your analysis goes here ---
# Example: compute a simple SNR proxy via matched filter or PSD
snr = np.random.uniform(4, 20)   # placeholder

# Save result
import os
os.makedirs(args.outdir, exist_ok=True)
outfile = os.path.join(args.outdir, f'result_{args.segment_index:04d}.hdf5')
with h5py.File(outfile, 'w') as h:
    h['snr']       = snr
    h['t_start']   = t_start
    h['t_end']     = t_end
    h['seg_index'] = args.segment_index

print(f"Saved → {outfile}")
```

---

## 4. Write the Job Script

### SLURM (sbatch)

```bash
#!/bin/bash
#SBATCH --job-name=gw_analysis
#SBATCH --array=0-99            # one task per segment (adjust to len(segments)-1)
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --output=logs/%A_%a.out
#SBATCH --error=logs/%A_%a.err

# Activate environment
source activate gw_env          # conda
# or: source /path/to/venv/bin/activate

mkdir -p logs results

python run_analysis.py \
    --segment-index $SLURM_ARRAY_TASK_ID \
    --segments segments.json \
    --outdir results/
```

Key `#SBATCH` options:

| Option | Meaning |
|---|---|
| `--array=0-99` | Run 100 independent tasks (indices 0 to 99) |
| `--cpus-per-task=4` | Cores per task |
| `--mem=8G` | RAM per task |
| `--time=02:00:00` | Wall-clock limit (HH:MM:SS) |
| `--output=logs/%A_%a.out` | `%A` = job ID, `%a` = array index |

### HTCondor (used on LIGO clusters: CIT, UWM, etc.)

Create `job.sub`:

```
universe   = vanilla
executable = /usr/bin/python3
arguments  = run_analysis.py --segment-index $(Process) --segments segments.json --outdir results/

output     = logs/job_$(Process).out
error      = logs/job_$(Process).err
log        = logs/job.log

request_cpus   = 4
request_memory = 8192
request_disk   = 2048

queue 100
```

---

## 5. Submit the Jobs

### SLURM

```bash
# Test with a single task first
sbatch --array=0-0 job.sh

# Submit the full array once happy
sbatch job.sh
```

Monitor and manage:

```bash
squeue -u $USER           # list your jobs
squeue -j <jobid>         # status of one job
scancel <jobid>           # cancel all tasks in a job
scancel <jobid>_<index>   # cancel one specific task
```

### HTCondor

```bash
condor_submit job.sub     # submit
condor_q                  # monitor queue
condor_q -analyze <id>    # debug why a job is idle
condor_rm <id>            # remove a job
```

---

## 6. Collect and Merge Results

Once all tasks complete, merge the per-task HDF5 files:

```python
import glob, h5py
import numpy as np

files = sorted(glob.glob('results/result_*.hdf5'))

snrs, starts, ends = [], [], []

for f in files:
    with h5py.File(f, 'r') as h:
        snrs.append(float(h['snr'][()]))
        starts.append(int(h['t_start'][()]))
        ends.append(int(h['t_end'][()]))

snrs   = np.array(snrs)
starts = np.array(starts)
ends   = np.array(ends)

# Save combined result
with h5py.File('results/combined.hdf5', 'w') as out:
    out['snr']     = snrs
    out['t_start'] = starts
    out['t_end']   = ends

print(f"Merged {len(files)} segments")
print(f"Max SNR: {snrs.max():.2f} at GPS {starts[snrs.argmax()]}")
```

---

## Quick-start Checklist

- [ ] Data files on shared filesystem accessible from all nodes
- [ ] `segments.json` generated and matches `--array` range in job script
- [ ] Environment activated and all packages installed (`gwpy`, `h5py`, `pycbc` etc.)
- [ ] `logs/` and `results/` directories exist (or created in script)
- [ ] Tested with `--array=0-0` before full submission
- [ ] Wall-time estimate validated on a single task before scaling

---

## Environment Setup

```bash
# Create a conda environment with GW tools
conda create -n gw_env python=3.10
conda activate gw_env
pip install gwpy pycbc h5py numpy scipy

# Or with LALSuite (for LIGO-specific pipelines)
conda install -c conda-forge lalsuite
```

---

## Production Pipelines

For production-grade searches, consider using built-in workflow tools:

| Tool | Command | Use case |
|---|---|---|
| PyCBC | `pycbc_make_coinc_search_workflow` | CBC matched-filter search |
| LALApps | `lalapps_submit_dag` | Submits a Condor DAG |
| BayesWave | `BayesWavePost` | Burst / glitch analysis |
| Bilby | `bilby_pipe` | Parameter estimation |

These wrap the steps above into automated DAG workflows with dependency tracking and automatic resubmission of failed jobs.

---

## Useful References

- [GWOSC Open Data](https://gwosc.org)
- [GWpy documentation](https://gwpy.github.io)
- [PyCBC documentation](https://pycbc.org)
- [SLURM documentation](https://slurm.schedmd.com)
- [HTCondor documentation](https://htcondor.readthedocs.io)
