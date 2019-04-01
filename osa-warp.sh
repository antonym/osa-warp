#!/usr/bin/env bash

# Copyright 2018, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

source lib/functions.sh
source lib/vars.sh

discover_code_version
require_ubuntu_version 16

# create working directory if it doesn't exist
if [ ! -d ${WORKING_DIR} ]; then
  mkdir -p ${WORKING_DIR}
fi

# if target not set, exit and inform user how to proceed
if [[ -z "$1" ]]; then
  echo "Please set the target to upgrade to:"
  echo "i.e ./osa-warp.sh queens"
  exit 1
fi
# convert target to lowercase
TARGET=${1,,}

# check if environment is already upgraded to desired target
if [[ ${TARGET} == ${CODE_UPGRADE_FROM} ]]; then
  echo "Nothing to do, you're already upgraded to ${TARGET^}."
  exit 99
fi

# iterate RELEASES and generate TODO list based on target set
for RELEASE in ${RELEASES}; do
  if [[ "${RELEASE}" == "${CODE_UPGRADE_FROM}" ]]; then
    STARTING_RELEASE=true
  elif [[ "${RELEASE}" != "${TARGET}" && "${STARTING_RELEASE}" == "true" ]]; then
    TODO+="${RELEASE} "
  fi
  if [[ "${RELEASE}" == "${TARGET}" && "${STARTING_RELEASE}" == "true" ]]; then
    TODO+="${RELEASE} "
    break
  fi
done

# validate desired target is valid in the RELEASES list
if ! echo ${TODO} | grep -w ${TARGET} > /dev/null; then
  echo Unable to upgrade to the specified target, please check the target and try again.
  echo Valid releases to use are:
  echo ${RELEASES}
  exit 99
fi

check_user_variables

if [ "${SKIP_PREFLIGHT}" != "true" ]; then
  pre_flight
fi

# generate osa-warp-configs
osa_warp_configs

# shut down containers
power_down

# run configuration and database migrations
for RELEASE_TO_DO in ${TODO}; do
  if [[ ${RELEASE_TO_DO} != ${TARGET} ]]; then
    if [ ! -f ${WORKING_DIR}/${RELEASE_TO_DO}_config.complete ]; then
      checkout_release ${RELEASE_TO_DO}
      bootstrap_ansible
      config_migration ${RELEASE_TO_DO}
      touch ${WORKING_DIR}/${RELEASE_TO_DO}_config.complete
    fi
    if [ ! -f ${WORKING_DIR}/${RELEASE_TO_DO}_migrate.complete ]; then
      pushd /opt/osa-warp/playbooks
        openstack-ansible remove-apt-proxy.yml
        openstack-ansible db-migration-${RELEASE_TO_DO}.yml
      popd
    fi
  fi
done

# run target upgrade
if [ ! -f ${WORKING_DIR}/${TARGET}-upgrade.complete ]; then
  pushd /opt/openstack-ansible
    checkout_release ${TARGET}
    bootstrap_ansible
    regen_repo_containers
    run_upgrade
    touch ${WORKING_DIR}/${TARGET}-upgrade.complete
  popd
fi

# run cleanup
for RELEASE_TO_DO in ${TODO}; do
  if [[ ${RELEASE_TO_DO} != ${TARGET} ]]; then
    checkout_release ${RELEASE_TO_DO}
    cleanup
  fi
done

# ensure target is checked out before ending
checkout_release ${TARGET}
pushd /opt/openstack-ansible/playbooks
  openstack-ansible haproxy-install.yml --tags=haproxy_server-config
popd
