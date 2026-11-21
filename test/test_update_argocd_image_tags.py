#!/usr/bin/python
# Copyright The OpenTelemetry Authors
# SPDX-License-Identifier: Apache-2.0

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
UPDATE_SCRIPT = REPOSITORY_ROOT / "scripts" / "update-argocd-image-tags.py"
IMAGE_SUFFIXES = (
    "accounting",
    "ad",
    "cart",
    "checkout",
    "currency",
    "email",
    "flagd-ui",
    "fraud-detection",
    "frontend",
    "frontend-proxy",
    "image-provider",
    "load-generator",
    "payment",
    "product-catalog",
    "quote",
    "recommendation",
    "shipping",
)


class ArgoCDImageTagUpdateTests(unittest.TestCase):
    def run_updater(self, content: str) -> tuple[subprocess.CompletedProcess[str], Path]:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        overlay = Path(directory.name) / "kustomization.yaml"
        overlay.write_text(content, encoding="utf-8")
        result = subprocess.run(
            [
                sys.executable,
                str(UPDATE_SCRIPT),
                "123456789012.dkr.ecr.us-west-2.amazonaws.com/opentelemetry-demo",
                "abc123",
                "--file",
                str(overlay),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        return result, overlay

    def test_updates_all_service_images_to_the_same_source_revision(self):
        overlay = "\n".join(
            f'        value: "ghcr.io/open-telemetry/demo:2.0.2-{suffix}" '
            f"# ci-image:{suffix}"
            for suffix in IMAGE_SUFFIXES
        )

        result, overlay_path = self.run_updater(overlay)

        self.assertEqual(result.returncode, 0, result.stderr)
        updated = overlay_path.read_text(encoding="utf-8")
        for suffix in IMAGE_SUFFIXES:
            self.assertIn(
                f'123456789012.dkr.ecr.us-west-2.amazonaws.com/opentelemetry-demo:'
                f"abc123-{suffix}",
                updated,
            )

    def test_fails_without_rewriting_when_a_service_marker_is_missing(self):
        overlay = 'value: "ghcr.io/open-telemetry/demo:2.0.2-cart" # ci-image:cart\n'

        result, overlay_path = self.run_updater(overlay)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing image patch markers", result.stderr)
        self.assertEqual(overlay_path.read_text(encoding="utf-8"), overlay)


if __name__ == "__main__":
    unittest.main()
