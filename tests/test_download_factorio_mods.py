#!/usr/bin/env python3
"""Unit tests for the headless Mod Portal downloader."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch


MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts" / "download-factorio-mods.py"
SPEC = importlib.util.spec_from_file_location("download_factorio_mods", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
DOWNLOADER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DOWNLOADER)


class DependencyNamesTest(unittest.TestCase):
    def test_recommended_dependencies_are_included_by_default(self) -> None:
        info_json = {
            "dependencies": [
                "base >= 2.1.0",
                "+ advanced-energy-grid",
                "? optional-integration",
                "(?) hidden-integration",
                "~ load-order-independent-required",
                "hard-required",
                "! incompatible-mod",
            ]
        }

        self.assertEqual(
            DOWNLOADER.dependency_names(info_json, include_optional=False),
            ["advanced-energy-grid", "load-order-independent-required", "hard-required"],
        )
        self.assertEqual(
            DOWNLOADER.dependency_names(info_json, include_optional=True),
            [
                "advanced-energy-grid",
                "optional-integration",
                "hidden-integration",
                "load-order-independent-required",
                "hard-required",
            ],
        )

    def test_local_metadata_includes_optional_dependencies_without_recursing(self) -> None:
        # Only what `local-mod` declares directly should be downloaded.
        # include_dependencies must be False here: a downloaded dependency's
        # own optional/recommended/hidden-optional dependencies must not be
        # pulled in, since that graph can reach arbitrarily far across the
        # Mod Portal (e.g. a hidden-optional compatibility shim several hops
        # away with no Factorio-version-compatible release).
        with patch.object(DOWNLOADER, "download_mod_closure") as download_mod:
            DOWNLOADER.download_info_dependency_closure(
                {
                    "name": "local-mod",
                    "dependencies": ["? optional-mod", "+ recommended-mod", "base"],
                },
                factorio_version="2.1",
                mods_dir=Path("/tmp/mods"),
                username="user",
                token="token",
            )

        self.assertEqual([call.args[0] for call in download_mod.call_args_list], ["optional-mod", "recommended-mod"])
        for call in download_mod.call_args_list:
            self.assertFalse(call.kwargs["include_dependencies"])
            self.assertTrue(call.kwargs["include_optional_dependencies"])
            self.assertEqual(call.kwargs["visited"], {"local-mod"})


if __name__ == "__main__":
    unittest.main()
