## Openstack-Ansible Warp (osa-warp)

** WORK IN PROGRESS, experimental, not ready for Production yet **

Allows you to warp from one version of OSA to another rapidly
by handling all DB and configuration migrations across versions
first before running setup-openstack specific playbooks from
the target release.  This is useful for moving through the
upgrade processes quickly reducing potential failures from
moving through each version incrementally.

Stages:

* List of releases to do is determined.
* Control Plane is shutdown.
* Next release from currently running release is checked out
* Partial configuration and database migration is ran for that release.
* Next release is checked out... etc until all releases except target
  are completed.
* Final target OSA is checked out and regular run-upgrade.sh script is ran.
* Cleanup scripts for all previous upgrade scripts are ran to remove
  unused containers.
* Cloud is then upgraded to target release.

Currently supports warping more than one release across Newton, Ocata, 
Pike, Queens to Rocky on Ubuntu 16.04

    git clone https://github.com/antonym/osa-warp.git /opt/osa-warp
    cd /opt/osa-warp
    ./osa-warp.sh <target_release>

TODO:
* Ensure all databases for services have been captured in migration scripts.
* Generate venvs for each latest stable release to use for migrations (or find
  a place where they are currently hosted with OpenStack to move away from
  using rpco-repo.
* Use latest releases versions instead of stable/branch so that it uses proper
  releases and potentially add the option to jump to a particuar release version.
* Add future release support
* Squashing whatever bugs may be present... surely none of those exist...
