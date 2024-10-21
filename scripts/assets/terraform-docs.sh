#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
# shellcheck source=_common.sh
. "$SCRIPT_DIR/_common.sh"

common::install::github_release \
  -o "terraform-docs" \
  -d "tar.gz" \
  -l "https://.+?-${TARGETOS}-${TARGETARCH}.tar.gz" \
  -s "https://.+?${VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz"

common::version
