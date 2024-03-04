#!/bin/sh

access_mothership_db() {
    export CC_DOTFILES_BETA=true
    . /Users/lliu/Workspaces/cc-dotfiles/caas.sh

    ENVIRONMENT=devel

    # Refresh ssh key to the desired ENVIRONMENT if needed
    assume 280640245378/nonprod-administrator
    # or for stag or prod:
    # assume 746494496109/nonprod-administrator

    # Create a ssh tunnel to the read only mothership database
    cctunnel db-ro -e ${ENVIRONMENT}
    # Output: connect to localhost:8432 to access the ENVIRONMENT mothership Read-Only DB
    psql
}
