#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
# shellcheck source=_common.sh
. "$SCRIPT_DIR/_common.sh"

# shellcheck disable=SC2153 # We are using the variable from _common.sh
if [ "$VERSION" == "latest" ]; then
  UNIQUE_VERSION="$(curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | \
    grep tag_name | \
    grep -o -E -m 1 "[0-9.]+")"
else
  UNIQUE_VERSION=${VERSION#*v}
fi

readonly UNIQUE_VERSION

curl -L "https://releases.hashicorp.com/terraform/${UNIQUE_VERSION}/${TOOL}_${UNIQUE_VERSION}_${TARGETOS}_${TARGETARCH}.zip" > "${TOOL}.zip"
unzip "${TOOL}.zip" "$TOOL"
rm "${TOOL}.zip"

common::version
