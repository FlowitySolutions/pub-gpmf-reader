"""CLI: Extract GPX tracks from all GoPro MP4 files in a directory.

This wraps the original script logic into a callable ``main()`` so it can
be exposed via an entry point.
"""
from __future__ import annotations

import logging
import os

from flowitygpmf.src import parse
from gpxpy.gpx import GPX, GPXTrack

logger = logging.getLogger(__name__)
from pathlib import Path


def extract_dir_all(target_dir: str) -> list[str]:
    """Extract all MP4 telemetry in ``target_dir``.

    Returns a list of written GPX file paths.
    """
    if not os.path.isdir(target_dir):
        raise FileNotFoundError(f"Directory not found: {target_dir}")

    mp4_files = sorted(f for f in os.listdir(target_dir) if f.lower().endswith(".mp4"))
    written: list[str] = []
    outdir = os.path.join(target_dir, "outputs")
    os.makedirs(outdir, exist_ok=True)

    for vid in mp4_files:
        if vid.startswith('.'):
            continue
        video_file = os.path.join(target_dir, vid)
        stream_info = parse.find_gpmf_stream(video_file)
        if not stream_info:
            logger.warning("No GPMF stream found in %s", video_file)
            continue
        gpmf = parse.extract_gpmf_stream(video_file, stream_info)
        track = parse.gpmf2gpx(gpmf)
        base, _ = os.path.splitext(vid)
        outfile = os.path.join(outdir, base + ".gpx")
        parse.write_gpx(track, outfile)
        written.append(outfile)
        logger.info("Wrote %s", outfile)
    return written


def extract_gpx_track(mp4_path: str | Path) -> GPXTrack:
    """Extract GPS telemetry from a GoPro MP4 file as a GPXTrack object.

    Parameters
    ----------
    mp4_path : str | Path
        Path to the GoPro MP4 file.

    Returns
    -------
    GPXTrack
        A gpxpy GPXTrack containing the GPS data.

    Raises
    ------
    FileNotFoundError
        If the MP4 file does not exist.
    ValueError
        If no GPMF stream is found in the file.
    """
    mp4_path = Path(mp4_path)
    if not mp4_path.exists():
        raise FileNotFoundError(f"File not found: {mp4_path}")

    stream_info = parse.find_gpmf_stream(str(mp4_path))
    if not stream_info:
        raise ValueError(f"No GPMF stream found in {mp4_path}")

    gpmf_data = parse.extract_gpmf_stream(str(mp4_path), stream_info)
    track = parse.gpmf2gpx(gpmf_data)
    return track
