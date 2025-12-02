"""Unified CLI providing subcommands.

Subcommands:
  extract   - Extract GPX from GoPro MP4 files in a directory (was gpmf2gpx).
  merge     - Merge GPX files in a directory into one (was mergegpx).

Backward compatibility: previous entry points can be removed and replaced by
this single script entry in pyproject.toml.
"""
from __future__ import annotations

import argparse
import logging
import os
from typing import List

from . import mergegpx
from .gpmf2gpx import extract_dir_all

logger = logging.getLogger(__name__)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="gpmfreader",
        description="Extract and merge GPX telemetry from GoPro videos (GPMF).",
    )

    parser.add_argument(
        "--log-level",
        default="WARNING",
        choices=["CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG"],
        help="Root logging level (default: WARNING).",
    )

    subparsers = parser.add_subparsers(dest="command", metavar="command")

    # extract subcommand (was gpmf2gpx)
    p_extract = subparsers.add_parser(
        "extract",
        help="Extract GPX tracks from all GoPro .MP4 files in a directory.",
        description="Extract GPMF data from GoPro .MP4 files in a directory into individual GPX files.",
    )
    p_extract.add_argument(
        "wkdir",
        type=str,
        help="Directory containing .MP4 files (each will produce one .gpx in an 'outputs' subfolder).",
    )

    # merge subcommand
    p_merge = subparsers.add_parser(
        "merge",
        help="Merge .gpx files in a directory into a single multi-segment GPX track.",
        description="Merge .gpx files in a directory into a single multi-segment GPX track.",
    )
    p_merge.add_argument("wkdir", type=str, help="Directory containing .gpx files to merge")
    p_merge.add_argument(
        "--optimize",
        action="store_true",
        help="Strip points to lat/lon only and create one track with multiple segments.",
    )

    return parser


def _cmd_extract(wkdir: str) -> int:
    if not os.path.isdir(wkdir):
        logger.error("Directory not found: %s", wkdir)
        return 1
    try:
        written = extract_dir_all(wkdir)
    except Exception as e:  # noqa: BLE001
        logger.exception("Extraction failed: %s", e)
        return 2
    if not written:
        logger.warning("No GPX files produced.")
        return 1
    logger.info("Wrote %d GPX files", len(written))
    return 0


def _cmd_merge(wkdir: str, optimize: bool) -> int:
    if not os.path.isdir(wkdir):
        logger.error("Directory not found: %s", wkdir)
        return 1
    try:
        output_path = mergegpx.merge_dir(wkdir, optimize=optimize)
    except Exception as e:  # noqa: BLE001
        logger.exception("Failed merging GPX files: %s", e)
        return 2
    logger.info("Merged GPX written to %s", output_path)
    return 0


def main(argv: List[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    # Initialize logging after parsing so --log-level can take effect.
    logging.basicConfig(
        level=getattr(logging, args.log_level, logging.WARNING),
        format="%(asctime)s :: %(levelname)s :: %(message)s",
    )
    logging.debug("Starting gpmfreader with args: %s", args)
    if args.command == "extract":
        return _cmd_extract(args.wkdir)
    if args.command == "merge":
        return _cmd_merge(args.wkdir, optimize=args.optimize)
    parser.print_help()
    return 1


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
