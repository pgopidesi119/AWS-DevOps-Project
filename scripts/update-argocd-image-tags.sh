#!/bin/sh
# Copyright The OpenTelemetry Authors
# SPDX-License-Identifier: Apache-2.0

set -eu

REPOSITORY_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$REPOSITORY_ROOT"

: "${AWS_REGION:?Set AWS_REGION to the AWS region containing the ECR repository}"
: "${ECR_REPOSITORY:=opentelemetry-demo}"
IMAGE_TAG=${IMAGE_TAG:-$(git rev-parse --verify HEAD)}

for tool in aws git python3; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "Required tool is missing: $tool" >&2
        exit 1
    }
done

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
case "$ACCOUNT_ID" in
    ''|*[!0-9]*)
        echo "Could not determine the AWS account ID from the active credentials." >&2
        exit 1
        ;;
esac

BEFORE=$(git rev-parse --verify HEAD)
ECR_IMAGE="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}"
python3 scripts/update-argocd-image-tags.py "$ECR_IMAGE" "$IMAGE_TAG"

if git diff --quiet -- argocd/overlays/demo/kustomization.yaml; then
    echo "ArgoCD image tags already match ${IMAGE_TAG}."
    exit 0
fi

git config user.name "CI Image Publisher"
git config user.email "ci-image-publisher@users.noreply.github.com"
git add argocd/overlays/demo/kustomization.yaml
git commit -m "chore(gitops): update ECR image tags [gitops-only]"

AFTER=$(git rev-parse --verify HEAD)
if [ "$BEFORE" = "$AFTER" ]; then
    echo "GitOps image tag commit was not created." >&2
    exit 1
fi
