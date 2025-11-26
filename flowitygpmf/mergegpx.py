"""CLI: Merge GPX files in a directory.

Wraps original script logic into callable ``main()`` for entry point use.
"""
from __future__ import annotations

import argparse
import logging
import os

from flowitygpmf import utils

logger = logging.getLogger(__name__)


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Merge .gpx files in a directory into a single multi-segment GPX track."
    )
    p.add_argument("wkdir", type=str, help="Directory containing .gpx files to merge")
    p.add_argument(
        "--optimize",
        action="store_true",
        help="Strip points to lat/lon only and create one track with multiple segments.",
    )
    return p


def merge(target_dir: str, optimize: bool) -> str:
    return utils.merge_gpx_files(target_dir, optimize=optimize)


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s :: %(levelname)s :: %(name)s :: %(message)s",
    )
    parser = build_parser()
    args = parser.parse_args(argv)
    if not os.path.isdir(args.wkdir):
        logger.error("Directory not found: %s", args.wkdir)
        return 1
    try:
        output_path = merge(args.wkdir, optimize=args.optimize)
    except Exception as e:  # noqa: BLE001
        logger.exception("Failed merging GPX files: %s", e)
        return 2
    logger.info("Merged GPX written to %s", output_path)
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
