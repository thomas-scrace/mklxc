#!/bin/bash

# Creates a privileged ubuntu lxc container with the specified name.
# Starts the container.
# Prints out IP address and other useful info.
# Optionally shares one or more directories from the host to the container.

set -e

CONTAINER_NAME=$1
CONFIG_PATH=/var/lib/lxc/$CONTAINER_NAME/config
shift
DIRS_TO_SHARE=$*
CONTAINER_USER=ubuntu
RESTART=0
exit

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

function share_directory () {
  host_dir=$1
  basename=`basename $1`
  line="lxc.mount.entry = \"$host_dir\" home/$CONTAINER_USER/$basename none ro,bind 0.0"
  if grep -Fxq "$line" $CONFIG_PATH; then
    echo "Configuring shared directory \"$host_dir\""
    echo $line >>$CONFIG_PATH
    RESTART=1
  fi
  remote_dir_exists=(`ssh $CONTAINER_USER@$CONTAINER_IP '[ -d /home/$CONTAINER_USER/$basename ]'`)
  if [ $remote_dir_exists == 0 ]; then
    `create remote dir`
    RESTART=1
  fi
}

# We have to be root to create privileged containers.
if [ "$(id -u)" != "0" ]; then
   echo "mklxc: This script must be run as root" 1>&2
   exit 1
fi



EXISTING_CONTAINERS=(`echo $(lxc-ls)`)
EXISTS=`contains $CONTAINER_NAME "${EXISTING_CONTAINERS[@]}"`

if [ $EXISTS == 1 ]; then
   echo "mklxc: Container does not yet exist. Creating it..."
   lxc-create -n $CONTAINER_NAME -t ubuntu
fi

for d in $DIRS_TO_SHARE; do
   share_directory $d
done

STATE=(`echo $(lxc-info -s -n $CONTAINER_NAME)`)
RUNNING=`contains "RUNNING" "${STATE[@]}"`

if [ $RUNNING == 1 ]; then
   echo "mklxc: Container is not running. Starting it..."
   lxc-start -n $CONTAINER_NAME -d
   # Wait a few seconds for networking to wake up:
   sleep 6
fi


cat <<EOF
mklxc: Container "$CONTAINER_NAME" is running with the following details.
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
