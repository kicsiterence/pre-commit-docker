#!/usr/bin/env bash

set -eo pipefail

function common::usage::github_release() {
  b="$(printf '\e[1m')"
  u="$(printf '\e[4m')"
  r="$(printf '\e[0m')"

  cat <<EOF >&2
${b}NAME${r}
    ${u}Install from github release${r} - Install the latest or specific version of the tool from GitHub release.

${b}OPTIONS${r}
    -o, --github-org
        GitHub organization name where the tool is hosted.

    -d, --distributed-as
        How the tool is distributed.
        Can be: 'tar.gz', 'zip' or 'binary'

    -l, --latest-version-regex
        Regular expression to match the latest release URL.

    -s, --specific-version-regex
        Regular expression to match the specific version release URL.

    -u, --unique-tool-name
        If the tool in the tar.gz package is not in the root or
        named differently than the tool name itself.
        For example, includes the version number or is in a subdirectory.

    -h
        Show this help.
EOF
}

#######################################################################
# Globals:
#   TOOL - Name of the tool
#   VERSION - Version of the tool
#######################################################################
function common::install::github_release() {

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -o | --github-org)
      local GITHUB_ORG="$2"
      shift
      ;;
    -d | --distributed)
      local DISTRIBUTED_AS="$2"
      shift
      ;;
    -l | --latest-version-regex)
      local LATEST_VERSION_REGEX="$2"
      shift
      ;;
    -s | --specific-version-regex)
      local SPECIFIC_VERSION_REGEX="$2"
      shift
      ;;
    -u | --unique-tool-name)
      local UNIQUE_TOOL_NAME="$2"
      shift
      ;;
    -h | --help)
      common::usage::github_release
      exit 0
      ;;
    *)
      args+=("${1}")
      ;;
    esac
    shift
  done

  if [[ -z "$GITHUB_ORG" ]] ||
    [[ -z "$DISTRIBUTED_AS" ]] ||
    [[ -z "$LATEST_VERSION_REGEX" ]] ||
    [[ -z "$SPECIFIC_VERSION_REGEX" ]]; then
    common::usage::github_release
    exit 1
  fi

  case $DISTRIBUTED_AS in
  tar.gz | zip)
    local -r PACKAGE="${TOOL}.${DISTRIBUTED_AS}"
    ;;
  binary)
    local -r PACKAGE="$TOOL"
    ;;
  *)
    echo "Unknown DISTRIBUTED_AS: '$DISTRIBUTED_AS'. Should be one of: 'tar.gz', 'zip' or 'binary'." >&2
    exit 1
    ;;
  esac

  # Download tool
  local -r RELEASES="https://api.github.com/repos/${GITHUB_ORG}/${TOOL}/releases"

  if [ "$VERSION" == "latest" ]; then
    curl -L "$(curl "${RELEASES}/latest" | grep -o -E -i -m 1 "$LATEST_VERSION_REGEX")" >"$PACKAGE"
  else
    COUNT=0
    while true; do

      RELEASE_PAGE="$(curl -s "$RELEASES?page=$COUNT")"
      DOWNLOAD_URL="$(grep -o -E -i -m 1 "$SPECIFIC_VERSION_REGEX" <<<"$RELEASE_PAGE" || echo "NonExisting")"

      # If there is no more GitHub release page to check the script will exit.
      if jq -e '. == []' <<<"$RELEASE_PAGE"; then
        echo "No more pages! Please check the '$TOOL' releases." >&2
        exit 1
      fi

      # If the $DOWNLOAD_URL is 'NonExisting' string it downloads the $TOOL
      # otherwise will increase the $COUNT and checks the next page.
      if [ "$DOWNLOAD_URL" != "NonExisting" ]; then
        curl -L "$DOWNLOAD_URL" >"$PACKAGE"
        break
      fi

      COUNT=$((COUNT + 1))
    done
  fi

  # Make tool ready to use
  if [ "$DISTRIBUTED_AS" == "tar.gz" ] && [ -z "$UNIQUE_TOOL_NAME" ]; then
    tar -xzf "$PACKAGE" "$TOOL"
    rm "$PACKAGE"
  fi

  if [ "$DISTRIBUTED_AS" == "tar.gz" ] && [ -n "$UNIQUE_TOOL_NAME" ]; then
    tar -xzf "$PACKAGE" "$UNIQUE_TOOL_NAME"
    mv "$UNIQUE_TOOL_NAME" "$TOOL"
    rm "$PACKAGE"
  fi

  if [ "$DISTRIBUTED_AS" == "zip" ]; then
    unzip "$PACKAGE"
    rm "$PACKAGE"
  fi

  if [ "$DISTRIBUTED_AS" == "binary" ]; then
    chmod +x "$PACKAGE"
  fi
}

#######################################################################
# Globals:
#   TOOL - Name of the tool
#   VERSION - Version of the tool
#######################################################################
function common::install::pip() {
  if [ "$VERSION" == "latest" ]; then
    "${PYTHON_VENV}/bin/pip3" install --no-cache-dir "$TOOL"
  else
    "${PYTHON_VENV}/bin/pip3" install --no-cache-dir "${TOOL}==${VERSION}"
  fi
}

#######################################################################
# Globals:
#   TOOL - Name of the tool
#   TOOLS_VERSION_FILE - File which contains version info
#######################################################################
function common::version() {
  local INSTALLED_TOOL_VERSION
  INSTALLED_TOOL_VERSION=$($TOOL --version)

  if [ ! -f "$TOOLS_VERSION_FILE" ]; then
    printf "%s\n" \
      "---" \
      "tools:" >"$TOOLS_VERSION_FILE"
  fi

  printf "%s\n" \
    "  - tool: $TOOL" \
    "    version: |" \
    "      ${INSTALLED_TOOL_VERSION//$'\n'/$'\n      '}" >>"$TOOLS_VERSION_FILE" # Needed for the correct indentation
}

#######################################################################
# Main
#######################################################################
# Tool name, based on filename.
# Tool filename MUST BE same as in package manager/binary name.
TOOL=${0##*/}
readonly TOOL=${TOOL%%.*}

# Get "TOOL_VERSION". Created in Dockerfile before execution of this script.
# shellcheck disable=SC1091
source /.env
env_var_name="${TOOL//-/_}"
env_var_name="${env_var_name^^}_VERSION"
# shellcheck disable=SC2034 # Used in other scripts
readonly VERSION="${!env_var_name}"

# Mandatory tools to install.
if [ "$VERSION" == "false" ] && [ "$TOOL" == "pre-commit" ]; then
  echo "Vital software can't be skipped!" >&2
  exit 1
fi

# Skip tool installation if the version is set to "false".
if [ "$VERSION" == "false" ]; then
  echo "'$TOOL' skipped."
  exit 0
fi
