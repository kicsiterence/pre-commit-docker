#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
# shellcheck source=_common.sh
. "$SCRIPT_DIR/_common.sh"

common::install::github_release \
  -o "gruntwork-io" \
  -d "binary" \
  -l "https://.+?/${TOOL}_${TARGETOS}_${TARGETARCH}" \
  -s "https://.+?${VERSION}/${TOOL}_${TARGETOS}_${TARGETARCH}"

common::version
