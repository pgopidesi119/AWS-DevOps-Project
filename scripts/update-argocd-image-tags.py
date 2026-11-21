#!/usr/bin/python
# Copyright The OpenTelemetry Authors
# SPDX-License-Identifier: Apache-2.0

import argparse
import re
import sys
from pathlib import Path


SERVICE_IMAGE_SUFFIXES = {
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
}

TAG_PATTERN = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}\Z")
IMAGE_PATCH_LINE = re.compile(
    r'^(?P<prefix>[ \t]*value:[ \t]*)"[^"\r\n]+"'
    r"(?P<marker>[ \t]+# ci-image:(?P<service>[a-z0-9-]+))[ \t]*$",
    re.MULTILINE,
)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Update ArgoCD's ECR image tags for the current source revision."
    )
    parser.add_argument("ecr_image", help="ECR image repository URI")
    parser.add_argument("image_tag", help="Container image tag")
    parser.add_argument(
        "--file",
        type=Path,
        default=Path("argocd/overlays/demo/kustomization.yaml"),
        help="Kustomize overlay file to update",
    )
    args = parser.parse_args()

    if not TAG_PATTERN.fullmatch(args.image_tag):
        parser.error("image_tag must be a valid container image tag")
    if not args.ecr_image or any(character.isspace() for character in args.ecr_image):
        parser.error("ecr_image must be a non-empty image repository URI")

    text = args.file.read_text(encoding="utf-8")
    updated_services = set()

    def replace_image(match: re.Match[str]) -> str:
        service = match.group("service")
        if service not in SERVICE_IMAGE_SUFFIXES:
            return match.group(0)
        if service in updated_services:
            raise ValueError(f"Duplicate image patch marker: {service}")
        updated_services.add(service)
        return (
            f'{match.group("prefix")}"{args.ecr_image}:'
            f'{args.image_tag}-{service}"{match.group("marker")}'
        )

    try:
        updated = IMAGE_PATCH_LINE.sub(replace_image, text)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 1

    missing_services = SERVICE_IMAGE_SUFFIXES - updated_services
    if missing_services:
        print(
            "Kustomize overlay is missing image patch markers: "
            + ", ".join(sorted(missing_services)),
            file=sys.stderr,
        )
        return 1

    args.file.write_text(updated, encoding="utf-8")
    print(f"Updated {len(updated_services)} ArgoCD image tags to {args.image_tag}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
