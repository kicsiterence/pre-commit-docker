#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
# shellcheck source=_common.sh
. "$SCRIPT_DIR/_common.sh"

common::install::github_release \
  -o "terraform-linters" \
  -d "zip" \
  -l "https://.+?_${TARGETOS}_${TARGETARCH}.zip" \
  -s "https://.+?/${VERSION}/${TOOL}_${TARGETOS}_${TARGETARCH}.zip"

common::version
