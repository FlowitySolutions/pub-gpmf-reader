Telemetry Extraction
====================

Extract GPMF telemetry from GoPro videos and merge GPX tracks.

## Installation

Install directly from the repository (replace `<org>` and `<repo>` if different):

```bash
pip install git+https://github.com/<org>/<repo>.git
```

For development (editable install):

```bash
git clone https://github.com/<org>/<repo>.git
cd <repo>
pip install -e .
```

## CLI Usage

The unified CLI exposes subcommands:

- `extract` — process a directory of GoPro `.MP4` files and write one `.gpx` per video into an `outputs/` subfolder.
- `merge` — merge all `.gpx` files in a directory into a single multi-segment GPX track.

Examples:

```bash
# Extract telemetry from videos (writes to <dir>/outputs/*.gpx)
flowitygpmf extract /path/to/mp4_directory

# Merge GPX files into one track
flowitygpmf merge /path/to/gpx_directory

# Merge with optimization (store only lat/lon, multiple segments)
flowitygpmf merge /path/to/gpx_directory --optimize
```

### Logging

Control verbosity with `--log-level` (default: `INFO`). Allowed values: `CRITICAL`, `ERROR`, `WARNING`, `INFO`, `DEBUG`.

```bash
flowitygpmf --log-level DEBUG extract /path/to/mp4_directory
flowitygpmf --log-level WARNING merge /path/to/gpx_directory
```

## Library Usage

```python
from flowitygpmf.gpmf2gpx import extract_all
from flowitygpmf.mergegpx import merge

# Extract one GPX per input video into <dir>/outputs
written_files = extract_all("/path/to/mp4_directory")

# Merge GPX files into a single track
merged_path = merge("/path/to/gpx_directory", optimize=False)
```

Legacy script names `flowitygpmf.gpmf2gpx` and `flowitygpmf.mergegpx` have been consolidated into the single `flowitygpmf` CLI with subcommands `extract` and `merge`.

## Requirements

* Python >= 3.9
* gpxpy >= 1.6.2

## License

MIT




