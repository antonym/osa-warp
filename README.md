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
Pike, Queens to Rocky on Ubuntu 16.04.  Must be at a Newton or greater
starting point running Ubuntu 16.04.

    git clone https://github.com/antonym/osa-warp.git /opt/osa-warp
    cd /opt/osa-warp
    # valid jumps (releases) are currently ocata, pike, queens, rocky
    ./osa-warp.sh <target_release>

TODO:
* Ensure all databases for services have been captured in migration scripts.
* Generate venvs for each latest stable release to use for migrations (or find
  a place where they are currently hosted with OpenStack to move away from
  using rpco-repo.
* Add future release support
* Squashing whatever bugs may be present... surely none of those exist...

Generating venvs to be used for migrations

```
# create an AIO and partially install to get venvs
export OSA_TAG=18.1.6
git clone --branch ${OSA_TAG} https://github.com/openstack/openstack-ansible.git /opt/openstack-ansible
cd /opt/openstack-ansible
scripts/bootstrap-ansible.sh
scripts/bootstrap-aio.sh
# copy aio files into place so all available venvs are built
cp /opt/openstack-ansible/etc/openstack_deploy/conf.d/*.yml.aio /etc/openstack_deploy/conf.d/
for f in $(ls -1 /etc/openstack_deploy/conf.d/*.aio); do mv -v ${f} ${f%.*}; done
openstack-ansible setup-hosts.yml
openstack-ansible setup-infrastructure.yml
# retrieve venvs from repo container
lxc-attach --name `lxc-ls repo_container` ls -la /var/www/repo/venvs/$OSA_TAG
```


