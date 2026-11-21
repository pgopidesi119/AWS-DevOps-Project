#!/bin/sh
# Copyright The OpenTelemetry Authors
# SPDX-License-Identifier: Apache-2.0

set -eu

REPOSITORY_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$REPOSITORY_ROOT"

: "${AWS_REGION:?Set AWS_REGION to the AWS region containing the ECR repository}"
: "${ECR_REPOSITORY:=opentelemetry-demo}"
IMAGE_TAG=${IMAGE_TAG:-$(git rev-parse --verify HEAD)}
ACTION=${1:-all}

case "$IMAGE_TAG" in
    ''|[!A-Za-z0-9_]*|*[!A-Za-z0-9_.-]*)
        echo "IMAGE_TAG contains unsupported characters: $IMAGE_TAG" >&2
        exit 1
        ;;
esac

require_tool() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Required tool is missing: $1" >&2
        exit 1
    }
}

get_ecr_registry() {
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    case "$ACCOUNT_ID" in
        ''|*[!0-9]*)
            echo "Could not determine the AWS account ID from the active credentials." >&2
            exit 1
            ;;
    esac

    ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
}

login_ecr() {
    require_tool aws
    require_tool docker
    docker compose version
    get_ecr_registry

    if ! aws ecr describe-repositories \
        --region "$AWS_REGION" \
        --repository-names "$ECR_REPOSITORY" >/dev/null 2>&1; then
        aws ecr create-repository \
            --region "$AWS_REGION" \
            --repository-name "$ECR_REPOSITORY" \
            --image-scanning-configuration scanOnPush=true >/dev/null
    fi

    ECR_PASSWORD_FILE=$(mktemp)
    trap 'rm -f "$ECR_PASSWORD_FILE"' EXIT HUP INT TERM
    aws ecr get-login-password --region "$AWS_REGION" > "$ECR_PASSWORD_FILE"
    docker login --username AWS --password-stdin "$ECR_REGISTRY" < "$ECR_PASSWORD_FILE"
}

build_images() {
    require_tool docker
    docker compose version

    export IMAGE_NAME=local/opentelemetry-demo
    export DEMO_VERSION="$IMAGE_TAG"
    export DOCKER_BUILDKIT=1

    docker compose --env-file .env --env-file .env.override build \
        accounting ad cart checkout currency email fraud-detection frontend \
        frontend-proxy image-provider load-generator payment product-catalog \
        quote recommendation shipping flagd-ui
}

push_images() {
    require_tool aws
    require_tool docker
    get_ecr_registry
    ECR_IMAGE="${ECR_REGISTRY}/${ECR_REPOSITORY}"
    IMAGE_NAME=local/opentelemetry-demo

    while IFS= read -r COMPOSE_SERVICE; do
        [ -n "$COMPOSE_SERVICE" ] || continue
        SOURCE_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}-${COMPOSE_SERVICE}"
        TARGET_IMAGE="${ECR_IMAGE}:${IMAGE_TAG}-${COMPOSE_SERVICE}"
        docker tag "$SOURCE_IMAGE" "$TARGET_IMAGE"
        docker push "$TARGET_IMAGE"
    done <<'COMPOSE_SERVICES'
accounting
ad
cart
checkout
currency
email
flagd-ui
fraud-detection
frontend
frontend-proxy
image-provider
load-generator
payment
product-catalog
quote
recommendation
shipping
COMPOSE_SERVICES

    echo "Published service images to ${ECR_IMAGE} with tag prefix ${IMAGE_TAG}."
}

case "$ACTION" in
    login)
        login_ecr
        ;;
    build)
        build_images
        ;;
    push)
        push_images
        ;;
    all)
        login_ecr
        build_images
        push_images
        ;;
    *)
        echo "Usage: $0 [login|build|push|all]" >&2
        exit 2
        ;;
esac
