#! /usr/bin/env bash
# Usgae: <path_to_script> <ssh config abbreviation> <remote_mount_point> <local_mount_point> <volume_name>

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <ssh config abbreviation> <remote_mount_point> <local_mount_point> <volume_name>" >&2
  exit 1
fi

SSH_CONNECTION=$1
REMOTE_MOUNT_POINT=$2
LOCAL_MOUNT_POINT=$3
VOLUME_NAME=$4

# Check if the sshfs is installed
if ! [ -x "$(command -v sshfs)" ]; then
  echo 'Error: sshfs is not installed.' >&2
  exit 1
fi

# Check if the local mount point exists
if [ ! -d "$LOCAL_MOUNT_POINT" ]; then
  echo "Warning: $LOCAL_MOUNT_POINT does not exist." >&2
  # try to create the directory if it does not exist, ask for permission
  read -p "Do you want to create the directory? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    mkdir -p $LOCAL_MOUNT_POINT
  else
    exit 1
  fi
fi

# mount the remote directory to the local directory
sshfs ${SSH_CONNECTION}:${REMOTE_MOUNT_POINT} ${LOCAL_MOUNT_POINT} -o volname=${VOLUME_NAME},reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,idmap=user,auto_xattr,dev,suid,defer_permissions,noappledouble,noapplexattr