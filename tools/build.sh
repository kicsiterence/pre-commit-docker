#!/usr/bin/env sh

usage() {
    b="$(printf '\e[1m')"
    u="$(printf '\e[4m')"
    r="$(printf '\e[0m')"

    cat <<EOF
${b}NAME${r}
    ${u}local build${r} - Build docker image to test it locally.

${b}OPTIONS${r}
    -n, --name   NAME
        Name of the docker image to build.

    -t, --tag TAG
        Tag name of the image to build.
        (Defaults to 'latest' branch.)

    -h
        Show this help.
EOF
}


GIT_DIR=$(git rev-parse --show-toplevel)
DOCKER_ARG="$GIT_DIR/docker.args"
IMAGE_TAG="latest"

while [ $# -gt 0 ]; do
    case "$1" in
        -n|--name)
            IMAGE_NAME="$2";;
        -t|--tag)
            IMAGE_TAG="$2";;
        -h|--help)
            usage;
            exit 0;;
        *)
            args="${args}${2}"
    esac
    shift 1
done

if [ -z "$IMAGE_NAME" ]; then    usage
    exit 1
fi

# Export tool versions from docker.args so the docker-bake.hcl variables pick
# them up, then build the host-arch image and load it into Docker for testing.
set -a
# shellcheck disable=SC1090
. "$DOCKER_ARG"
set +a

IMAGE="$IMAGE_NAME" IMAGE_TAG="$IMAGE_TAG" \
  docker buildx bake -f "$GIT_DIR/docker-bake.hcl" --pull --load "${BAKE_TARGET:-test}"
