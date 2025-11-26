"""Utility functions for GPX merging.

Moved from root-level ``utils.py`` to package.
"""
from __future__ import annotations

import os
from typing import List

import gpxpy
import gpxpy.gpx

def _list_gpx_files(directory: str) -> List[str]:
    files = [
        os.path.join(directory, f)
        for f in os.listdir(directory)
        if f.lower().endswith(".gpx") and os.path.isfile(os.path.join(directory, f))
    ]
    files.sort()
    return files


def _extract_tracks_points(gpx: gpxpy.gpx.GPX) -> List[List[gpxpy.gpx.GPXTrackPoint]]:
    """Return a list of segments; each segment is a list of GPXTrackPoint."""
    segments: List[List[gpxpy.gpx.GPXTrackPoint]] = []
    for trk in gpx.tracks:
        for seg in trk.segments:
            if seg.points:
                segments.append(list(seg.points))
    # Also include routes as independent segments if present
    for rte in gpx.routes:
        if rte.points:
            segments.append([
                gpxpy.gpx.GPXTrackPoint(p.latitude, p.longitude, elevation=p.elevation, time=p.time)
                for p in rte.points
            ])
    # Waypoints are individual points; treat them as tiny segments of length 1
    for w in gpx.waypoints:
        segments.append([gpxpy.gpx.GPXTrackPoint(w.latitude, w.longitude, elevation=w.elevation, time=w.time)])
    return segments


def _optimize_to_polyline_only(segments: List[List[gpxpy.gpx.GPXTrackPoint]]) -> gpxpy.gpx.GPX:
    """Create a GPX containing a single track with multiple segments, lat/lon only."""
    out = gpxpy.gpx.GPX()
    track = gpxpy.gpx.GPXTrack(name="Merged")
    out.tracks.append(track)
    for seg_points in segments:
        seg = gpxpy.gpx.GPXTrackSegment()
        for p in seg_points:
            seg.points.append(gpxpy.gpx.GPXTrackPoint(p.latitude, p.longitude))
        track.segments.append(seg)
    return out


def _merge_full(segments: List[List[gpxpy.gpx.GPXTrackPoint]]) -> gpxpy.gpx.GPX:
    """Merge keeping typical GPX structure (single track, multi segments)."""
    return _optimize_to_polyline_only(segments)


def merge_gpx_files(directory: str, optimize: bool = False) -> str:
    """Merge all .gpx files in a directory into one output GPX file.

    Args:
        directory: Path containing .gpx files.
        optimize: If True, output contains lat/lon only.

    Returns:
        Path to written GPX file.
    """
    files = _list_gpx_files(directory)
    if not files:
        raise FileNotFoundError(f"No GPX files found in '{directory}'")

    all_segments: List[List[gpxpy.gpx.GPXTrackPoint]] = []
    for path in files:
        with open(path, "r", encoding="utf-8") as fh:
            gpx = gpxpy.parse(fh)
        all_segments.extend(_extract_tracks_points(gpx))

    merged = _optimize_to_polyline_only(all_segments) if optimize else _merge_full(all_segments)

    dirname = os.path.basename(os.path.normpath(directory))
    output_filename = f"{dirname}_optimized.gpx" if optimize else f"{dirname}.gpx"
    output_path = os.path.join(directory, output_filename)

    with open(output_path, "w", encoding="utf-8") as out_f:
        out_f.write(merged.to_xml())

    return output_path
