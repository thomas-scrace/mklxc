#!/bin/bash

# Creates a privileged lxc container with the specified name.
# Starts the container.
# Prints out IP address and other useful info.
# Optionally shares one or more directories from the host to the container.

set -e

function contains () {
  local e
  for e in "${@:2}"; do
    if [ "$e" == "$1" ]; then
      echo 0
      return
    fi
  done
  echo 1
}

# We have to be root to create privileged containers.
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

CONTAINER_NAME=$1

EXISTING_CONTAINERS=(`echo $(lxc-ls)`)
EXISTS=`contains $CONTAINER_NAME "${EXISTING_CONTAINERS[@]}"`

if [ $EXISTS == 0 ]; then
   echo "Container \"$CONTAINER_NAME\" already exists. Aborting." 1>&2
   exit 1
fi

lxc-create -n $CONTAINER_NAME -t ubuntu
lxc-start -n $CONTAINER_NAME -d
# Wait a few seconds for networking to wake up:
sleep 6

cat <<EOF
Success!
$CONTAINER_NAME created
`lxc-info -n $CONTAINER_NAME`
EOF
#
#Return to host
#--------------
#Ctrl-A then q
#
#Sharing files between host and container
#----------------------------------------
#Open a console to the container and create the target dir:
#    $ mkdir /home/ubuntu/your-proj
#
#Exit the console and edit the container's config file:
#    $ vi /var/lib/lxc/container-name/config
#
#Add:
#    lxc.mount.entry = /home/you/your-proj home/ubuntu/your-proj none ro,bind 0.0
#
#See IP address and state of container
#-------------------------------------
#    $ lxc-ls --fancy container-name
#
