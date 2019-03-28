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
if [ ! -d /etc/openstack_deploy/osa-warp ]; then
  mkdir -p /etc/openstack_deploy/osa-warp
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
elif [[ ${TARGET} == "ocata" ]]; then
  echo "Upgrade directly to Ocata is not supported."
  echo "Pike would be the next supported upgrade target."
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
set_secrets_file

if [ "${SKIP_PREFLIGHT}" != "true" ]; then
  pre_flight
fi

# shut down containers
power_down

# run configuration and database migrations
for RELEASE_TO_DO in ${TODO}; do
  if [[ ${RELEASE_TO_DO} != ${TARGET} ]]; then
    checkout_release ${RELEASE_TO_DO}
    config_migration ${RELEASE_TO_DO}
    if [ ! -f /etc/openstack_deploy/osa-warp/${RELEASE_TO_DO}_migrate.complete ]; then
      pushd /opt/osa-warp/playbooks
        openstack-ansible remove-apt-proxy.yml
        openstack-ansible db-migration-${RELEASE_TO_DO}.yml
      popd
    fi
  fi
done

# run target upgrade
pushd /opt/openstack-ansible
  checkout_release ${TARGET}
  regen_repo_containers
  run_upgrade
popd

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

# run through TODO list and run all migrations
#for RELEASE_TO_DO in ${TODO}; do
#  echo "Starting leap upgrade to ${TARGET^}"
#  bash ubuntu16-upgrade-to-${TARGET}.sh
#done

# this is not final, testing orchestration before making a loop
# based on user input

#### ocata leap ####

#pushd /opt/openstack-ansible
#  git checkout stable/ocata
#popd

#pushd /opt/openstack-ansible/scripts/upgrade-utilities/playbooks
#  openstack-ansible ansible_fact_cleanup.yml
#  openstack-ansible deploy-config-changes.yml
#  openstack-ansible user-secrets-adjustment.yml
#  openstack-ansible pip-conf-removal.yml
#popd

#pushd /opt/rpc-upgrades/incremental/playbooks
#  openstack-ansible db-migration-ocata.yml
#popd

#### pike leap ####

## potentially move all neutron interactions to end after all other migrations
## power down neutron here and migrate for o/p/q to maximize network uptime
## to leave things available while rest of control plane is shutdown

