# 📂 Data

This folder is a placeholder for data used in the workshop notebooks.

## Where does data come from?

Most data in this workshop is fetched **on the fly** inside the notebooks using open-access services — you do not need to download anything manually beforehand.

| Notebook | Data source | How it is fetched |
|---|---|---|
| 03 — Profiling | SIGWAY repo (synthetic GW signals) | Cloned from GitHub inside the notebook |
| 04 — Hypothesis | Synthetic waveforms | Generated in-notebook with numpy/scipy |
| 05 — Containers | GWOSC open data (e.g. GW150914) | Fetched with `gwpy` / `gwosc` Python packages |

## Large files

Large data files (HDF5, frame files, etc.) should **not** be committed to this repository.  
Add them to `.gitignore` and document where to download them here instead.

```gitignore
# In .gitignore
data/*.hdf5
data/*.gwf
data/*.h5
```

## Useful links

- [GWOSC — Gravitational Wave Open Science Center](https://gwosc.org)
- [GWOSC data access tutorial](https://gwosc.org/tutorials/)
- [gwpy documentation](https://gwpy.github.io)
