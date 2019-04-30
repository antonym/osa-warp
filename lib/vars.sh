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

# stable release versions to use for migrations and deploy
export OCATA_RELEASE="${OCATA_RELEASE:-15.1.28}"
export PIKE_RELEASE="${PIKE_RELEASE:-16.0.28}"
export QUEENS_RELEASE="${QUEENS_RELEASE:-17.1.10}"
export ROCKY_RELEASE="${ROCKY_RELEASE:-18.1.6}"
export STEIN_RELEASE="${STEIN_RELEASE:-stable/stein}"

OSA_REPO=${OSA_REPO:-https://github.com/openstack/openstack-ansible.git}
RELEASES="newton
          ocata
          pike
          queens
          rocky
          stein"

STARTING_RELEASE=false
SKIP_PREFLIGHT=${SKIP_PREFLIGHT:-false}
WORKING_DIR=/etc/openstack_deploy/osa-warp

