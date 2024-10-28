#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
# shellcheck source=_common.sh
. "$SCRIPT_DIR/_common.sh"

# cargo, gcc, git, musl-dev, rust and CARGO envvar required for compilation of rustworkx@0.13.2
# no longer required once checkov version depends on rustworkx >0.14.0
# https://github.com/bridgecrewio/checkov/pull/6045
# gcc libffi-dev musl-dev required for compilation of cffi, until it contains musl aarch64
export CARGO_NET_GIT_FETCH_WITH_CLI=true
common::install::pip
common::version
