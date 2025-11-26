"""CLI: Merge GPX files in a directory.

Wraps original script logic into callable ``main()`` for entry point use.
"""
from __future__ import annotations

import logging
import os

from flowitygpmf import utils

logger = logging.getLogger(__name__)


def merge_dir(target_dir: str, optimize: bool) -> str:
    return utils.merge_gpx_files(target_dir, optimize=optimize)
