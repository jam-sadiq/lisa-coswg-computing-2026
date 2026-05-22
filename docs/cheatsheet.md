# ⚡ Command Cheat Sheet

Quick reference for all commands used across the bootcamp notebooks.

---

## uv — Python environments (Notebook 01)

```bash
# Project setup
uv init .                        # create pyproject.toml in current dir
uv venv                          # create .venv/
uv venv --python 3.11            # create .venv/ with specific Python

# Activate / deactivate (local terminal only)
source .venv/bin/activate        # Linux / macOS
.venv\Scripts\Activate.ps1      # Windows PowerShell
deactivate                       # exit the environment

# Packages
uv add numpy scipy astropy       # add packages (updates pyproject.toml)
uv add --dev pytest hypothesis   # add dev-only packages
uv add "gwpy>=3.0"               # add with version constraint
uv remove matplotlib             # remove a package
uv pip list                      # list installed packages

# Reproducibility
uv sync                          # recreate environment from uv.lock
uv lock --upgrade                # upgrade all packages
uv run python script.py          # run inside env without activating
uv run pytest                    # run tests inside env
```

---

## OpenAI API (Notebook 02)

```python
from openai import OpenAI

client = OpenAI(api_key="your-key-here")   # or use env var OPENAI_API_KEY

response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "Your question here"}]
)
print(response.choices[0].message.content)
```

---

## Code Profiling (Notebook 03)

```bash
# cProfile — function-level profiling
python -m cProfile -o profile.out my_script.py
snakeviz profile.out                          # interactive visualisation

# line_profiler — line-by-line
pip install line_profiler
kernprof -l -v my_script.py                   # add @profile decorator to functions

# memory_profiler
pip install memory_profiler
python -m memory_profiler my_script.py        # add @profile decorator
```

---

## Hypothesis — property-based testing (Notebook 04)

```python
from hypothesis import given, settings
from hypothesis import strategies as st

@given(st.floats(min_value=1.0, max_value=100.0))
def test_my_function(x):
    result = my_function(x)
    assert result > 0           # property that must always hold
```

---

## Git (Notebooks 03 & 04)

```bash
git clone <url>                  # clone a repository
git status                       # what has changed?
git add file.py                  # stage a file
git commit -m "message"         # commit
git push                         # push to remote

git checkout -b my-branch        # create and switch to a new branch
git log --oneline                # compact history
git diff                         # see unstaged changes
```

---

## Docker (Notebook 05)

```bash
docker build -t my-image:latest .     # build image from Dockerfile
docker run my-image:latest            # run a container
docker run -v $(pwd)/data:/data \
           my-image:latest            # mount local data folder
docker images                         # list images
docker ps -a                          # list containers
docker rm <container-id>              # remove container
docker rmi <image-id>                 # remove image
```

---

## GWOSC / gwpy — gravitational wave data (Notebook 05)

```python
from gwosc.datasets import find_datasets
from gwpy.timeseries import TimeSeries

# Find available datasets
print(find_datasets(type='event'))

# Fetch open data around GW150914
data = TimeSeries.fetch_open_data('H1', 1126259462, 1126259562)
```
