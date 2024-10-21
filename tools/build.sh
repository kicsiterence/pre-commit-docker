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

grep -v -e "^#" -e "^$" "$DOCKER_ARG" | \
  xargs printf -- '--build-arg %s\n' | \
  xargs docker build --progress plain --no-cache --pull -t "$IMAGE_NAME:$IMAGE_TAG" "$GIT_DIR"
