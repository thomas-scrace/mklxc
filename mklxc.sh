#!/bin/bash

# Creates a privileged ubuntu lxc container with the specified name.
# Starts the container.
# Optionally shares one or more directories from the host to the container.
# Sets up ssh access using keys
# Prints out the IP address
# First arg is the container name to use. Subsequent args are paths to
# directories on the host to share.

set -e

CONTAINER_NAME=$1
CONFIG_PATH=/var/lib/lxc/$CONTAINER_NAME/config
shift
DIRS_TO_SHARE=$*
CONTAINER_USER=ubuntu
CONTAINER_PASS=ubuntu
RESTART=0

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

function config_directory () {
  host_dir=$1
  basename=`basename $1`
  line="lxc.mount.entry = $host_dir home/$CONTAINER_USER/$basename none rw,bind 0.0"
  if ! sudo grep -Fxq "$line" $CONFIG_PATH; then
    echo "Configuring shared directory \"$host_dir\""
    sudo bash -c "echo $line >>$CONFIG_PATH"
    RESTART=1
  fi
}

function mk_remote_dir () {
  basename=`basename $1`
  if ! (`ssh -oStrictHostKeyChecking=no $CONTAINER_USER@$CONTAINER_IP "[ -d /home/$CONTAINER_USER/$basename ]"`); then
    echo "Creating /home/$CONTAINER_USER/$basename in container"
    ssh $CONTAINER_USER@$CONTAINER_IP "mkdir /home/$CONTAINER_USER/$basename"
    RESTART=1
  fi
}

function get_container_ip () {
    echo `sudo lxc-info -iH -n $CONTAINER_NAME`
}

function setup_ssh_keys () {
    sshpass -p $CONTAINER_PASS ssh-copy-id -oStrictHostKeyChecking=no $CONTAINER_USER@$CONTAINER_IP
}

EXISTING_CONTAINERS=(`echo $(sudo lxc-ls)`)
EXISTS=`contains $CONTAINER_NAME "${EXISTING_CONTAINERS[@]}"`

if [ $EXISTS == 1 ]; then
   echo "mklxc: Container does not yet exist. Creating it..."
   sudo lxc-create -n $CONTAINER_NAME -t ubuntu
fi

STATE=(`echo $(sudo lxc-info -s -n $CONTAINER_NAME)`)
RUNNING=`contains "RUNNING" "${STATE[@]}"`

if [ $RUNNING == 1 ]; then
   echo "mklxc: Container is not running. Starting it..."
   sudo lxc-start -n $CONTAINER_NAME -d
   # Wait a few seconds for networking to wake up:
   sleep 6
fi

CONTAINER_IP=`get_container_ip`

for d in $DIRS_TO_SHARE; do
   config_directory $d
done

setup_ssh_keys

for d in $DIRS_TO_SHARE; do
   mk_remote_dir $d
done

if [ $RESTART == 1 ]; then
    sudo lxc-stop -n $CONTAINER_NAME
    sudo lxc-start -n $CONTAINER_NAME
fi

echo "mklxc: Container "$CONTAINER_NAME" is running with IP address $CONTAINER_IP"
echo "mklxc: You may connect over ssh using:"
echo "ssh $CONTAINER_USER@$CONTAINER_IP"
