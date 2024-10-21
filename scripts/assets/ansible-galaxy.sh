#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
# shellcheck source=_common.sh
. "$SCRIPT_DIR/_common.sh"

ANSIBLE_COLLECTIONS_PATH=/bin_dir/collections \
  ansible-galaxy collection install --force \
  ansible.posix \
  community.general \
  community.mysql \
  community.docker \
  amazon.aws

ANSIBLE_ROLES_PATH=/bin_dir/roles \
  ansible-galaxy role install \
  geerlingguy.mysql

common::version
