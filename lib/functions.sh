#!/usr/bin/env bash

# Copyright 2019, Rackspace US, Inc.
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

# functions for upgrades

function discover_code_version {
  if [[ ! -f "/etc/openstack-release" ]]; then
    failure "No release file could be found, failing..."
    exit 99
  elif [[ -f "${WORKING_DIR}/openstack-release.upgrade" ]]; then
    source ${WORKING_DIR}/openstack-release.upgrade
    determine_release
  else
    source /etc/openstack-release
    determine_release
  fi
}

function determine_release {
  case "${DISTRIB_RELEASE%%.*}" in
    *14|newton-eol)
      export CODE_UPGRADE_FROM="newton"
      echo "You seem to be running Newton"
    ;;
    *15|ocata)
      export CODE_UPGRADE_FROM="ocata"
      echo "You seem to be running Ocata"
    ;;
    *16|pike)
      export CODE_UPGRADE_FROM="pike"
      echo "You seem to be running Pike"
    ;;
    *17|queens)
      export CODE_UPGRADE_FROM="queens"
      echo "You seem to be running Queens"
    ;;
    *18|rocky)
      export CODE_UPGRADE_FROM="rocky"
      echo "You seem to be running Rocky"
    ;;
    *19|stein)
      export CODE_UPGRADE_FROM="stein"
      echo "You seem to be running Stein"
    ;;
    *)
      echo "Unable to detect current OpenStack version, failing...."
      exit 99
    esac
}

# Fail if Ubuntu Major release is not the minimum required for a given OpenStack upgrade
function require_ubuntu_version {
  REQUIRED_VERSION="$1"
  if [ "$(lsb_release -r | cut -f2 -d$'\t' | cut -f1 -d$'.')" -lt "$REQUIRED_VERSION" ]; then
    echo "Please upgrade to Ubuntu "$REQUIRED_VERSION" before attempting to upgrade OpenStack"
    exit 99
  fi
}

function pre_flight {
    ## Pre-flight Check ----------------------------------------------------------
    # Clear the screen and make sure the user understands whats happening.
    clear

    # Notify the user.
    echo -e "
    Once you start the upgrade there is no going back.
    This script will guide you through the process of
    upgrading OSA from:

    ${CODE_UPGRADE_FROM^} to ${TARGET^}

    Note that the upgrade targets impacting the data
    plane as little as possible, but assumes that the
    control plane can experience some down time.

    This script executes a one-size-fits-all upgrade,
    and given that the tests implemented for it are
    not monitored as well as those for a greenfield
    environment, the results may vary with each release.

    Please use it against a test environment with your
    configurations to validate whether it suits your
    needs and does a suitable upgrade.

    Are you ready to perform this upgrade now?
    "

    # Confirm the user is ready to upgrade.
    read -p 'Enter "YES" to continue or anything else to quit: ' UPGRADE
    if [ "${UPGRADE}" == "YES" ]; then
      echo "Running Upgrade from ${CODE_UPGRADE_FROM^} to ${TARGET^}"
    else
      exit 99
    fi
}

function check_user_variables {
  if [[ ! -f /etc/openstack_deploy/user_variables.yml ]]; then
     echo "---" > /etc/openstack_deploy/user_variables.yml
     echo "default_bind_mount_logs: False" >> /etc/openstack_deploy/user_variables.yml
  elif [[ -f /etc/openstack_deploy/user_variables.yml ]]; then
     if ! grep -i -q "default_bind_mount_logs" /etc/openstack_deploy/user_variables.yml; then
       echo "default_bind_mount_logs: False" >> /etc/openstack_deploy/user_variables.yml
     fi
  fi
}

function configure_osa {
  rm -rf /etc/openstack_deploy/group_vars
  # clean out any existing env.d inventory
  if [ -d "/etc/openstack_deploy/env.d" ]; then
    rm -rf /etc/openstack_deploy/env.d
  fi
}

function osa_warp_configs {
  pushd /opt/osa-warp/playbooks
    openstack-ansible osa-warp-configs.yml
  popd
}

function power_down {
  pushd /opt/osa-warp/playbooks
    openstack-ansible power-down.yml
  popd
}

function checkout_release {
  export STABLE_RELEASE=${1^^}_RELEASE

  if [ ! -d "/opt/openstack-ansible" ]; then
    git clone --recursive ${OSA_REPO} /opt/openstack-ansible
    pushd /opt/openstack-ansible
      git checkout "${!STABLE_RELEASE}"
    popd
  else
    pushd /opt/openstack-ansible
      git remote set-url origin ${OSA_REPO}
      git reset --hard HEAD
      git fetch --all
      git checkout "${!STABLE_RELEASE}"
    popd
  fi
}

function bootstrap_ansible {
  pushd /opt/openstack-ansible
    scripts/bootstrap-ansible.sh
  popd  
}

function config_migration {
  case "${1}" in
    ocata)
      pushd /opt/openstack-ansible/scripts/upgrade-utilities/playbooks
        openstack-ansible ansible_fact_cleanup.yml
        openstack-ansible deploy-config-changes.yml
        openstack-ansible user-secrets-adjustment.yml
        openstack-ansible pip-conf-removal.yml
      popd
    ;;
    pike)
      pushd /opt/openstack-ansible/scripts/upgrade-utilities/playbooks
        openstack-ansible ansible_fact_cleanup.yml
        openstack-ansible deploy-config-changes.yml
        openstack-ansible user-secrets-adjustment.yml
        openstack-ansible pip-conf-removal.yml
        openstack-ansible ceph-galaxy-removal.yml
      popd
    ;;
    queens)
      pushd /opt/openstack-ansible/scripts/upgrade-utilities/playbooks
        openstack-ansible ansible_fact_cleanup.yml
        openstack-ansible deploy-config-changes.yml
        openstack-ansible user-secrets-adjustment.yml
        openstack-ansible pip-conf-removal.yml
        openstack-ansible ceph-galaxy-removal.yml
      popd
    ;;
    rocky)
      # run rocky configs
    ;;
    *)
      echo "Unable to detect required OpenStack version, failing...."
      exit 99
    ;;
  esac
}

function regen_repo_containers {
  pushd /opt/openstack-ansible/playbooks
    openstack-ansible lxc-containers-destroy.yml -e force_containers_destroy=true -e force_containers_data_destroy=true --limit repo_container
    openstack-ansible lxc-containers-create.yml --limit repo-infra_all -e lxc_container_fs_size=10G
    touch ${WORKING_DIR}/${TARGET}-repo-regen.complete
  popd
}

function run_upgrade {
  pushd /opt/openstack-ansible
    cp /opt/osa-warp/releases/${TARGET}/run-upgrade.sh /opt/openstack-ansible/scripts/run-upgrade.sh
    export TERM=linux
    export I_REALLY_KNOW_WHAT_I_AM_DOING=true
    export SETUP_ARA=true
    export ANSIBLE_CALLBACK_PLUGINS=/etc/ansible/roles/plugins/callback:/opt/ansible-runtime/local/lib/python2.7/site-packages/ara/plugins/callbacks
    echo "YES" | bash scripts/run-upgrade.sh
  popd
}

function cleanup {
  case "${1}" in
    ocata)
      # run ocata cleanup
    ;;
    pike)
      # run pike cleanup
    ;;
    queens)
      pushd /opt/openstack-ansible/scripts/upgrade-utilities/playbooks
        openstack-ansible cleanup-nova.yml -e force_containers_destroy=yes -e force_containers_data_destroy=yes
        openstack-ansible cleanup-cinder.yml -e force_containers_destroy=yes -e force_containers_data_destroy=yes
        openstack-ansible cleanup-heat.yml -e force_containers_destroy=yes -e force_containers_data_destroy=yes
        openstack-ansible cleanup-ironic.yml -e force_containers_destroy=yes -e force_containers_data_destroy=yes
        openstack-ansible cleanup-trove.yml -e force_containers_destroy=yes -e force_containers_data_destroy=yes
      popd
    ;;
    rocky)
      # run rocky cleaning
    ;;
    *)
      echo "Unable to detect required OpenStack version, failing...."
      exit 99
    ;;
  esac
}

function mark_started {
  echo "Starting ${TARGET^} upgrade..."
  if [ ! -f ${WORKING_DIR}/upgrade-to-${TARGET}.started ]; then
    cp /etc/openstack-release ${WORKING_DIR}/openstack-release.upgrade
  fi
  touch ${WORKING_DIR}/upgrade-to-${TARGET}.started
}

function mark_completed {
  echo "Completing ${TARGET^} upgrade..."
  touch ${WORKING_DIR}/upgrade-to-${TARGET}.complete
}

