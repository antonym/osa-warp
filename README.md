## Openstack-Ansible Warp (osa-warp)

** WORK IN PROGRESS **

Allows you to warp from one version of OSA to another rapidly
by handling all DB and configuration migrations across versions
first before running setup-openstack specific playbooks from
the target release.

Stages:
List of releases to do is determined.
Control Plane is shutdown.
Next release from currently running release is checked out
Partial configuration and database migration is ran for that release.
Next release is checked out... etc until all releases except target
are completed.
Final target OSA is checked out and regular run-upgrade.sh script is ran.
Cleanup scripts for all previous upgrade scripts are ran to remove
unused containers.
Cloud is then upgraded to target release.

Currently supports Newton to Rocky.

    git clone osa-warp
    cd /opt/osa-warp
    ./osa-warp <target_release>



