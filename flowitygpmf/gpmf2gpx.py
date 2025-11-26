"""CLI: Extract GPX tracks from all GoPro MP4 files in a directory.

This wraps the original script logic into a callable ``main()`` so it can
be exposed via an entry point.
"""
from __future__ import annotations

import argparse
import logging
import os

from flowitygpmf.src import parse

logger = logging.getLogger(__name__)



def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Extract GPMF data from GoPro .MP4 files in a directory into individual GPX files (per input video)."
    )
    p.add_argument(
        "wkdir",
        type=str,
        help="Directory containing .MP4 files (each will produce one .gpx in an 'outputs' subfolder).",
    )
    return p


def extract_all(target_dir: str) -> list[str]:
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


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s :: %(levelname)s :: %(name)s :: %(message)s",
    )
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        written = extract_all(args.wkdir)
    except Exception as e:  # noqa: BLE001 - surface any extraction issue
        logger.exception("Extraction failed: %s", e)
        return 2
    if not written:
        logger.warning("No GPX files produced.")
        return 1
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
