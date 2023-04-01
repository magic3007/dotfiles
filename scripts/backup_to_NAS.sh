#!/bin/bash
#
# backup_to_NAS 
#   a script to synchronize local files with those on a remote host
#
# Mark Alford, Oct 2019

# make a note of whether the script was invoked with the -interactive option
# this will change later behavior: we will add in a dry run and an option to abort

interactive="false"
if [[ $1 == "-interactive" || $1 == "-i" ]]
then 
  interactive="true" 
fi

# log file for outcome reporting:
log_file=${HOME}/NAS_backups.log

# list of subdirectories that we do NOT want to include in the backup:
exclusions=(/.anaconda /.conda /.eclipse /.gnupg /.keras /.nv /.slocdata /.cache /.config /.kde /.local 
  /.mozilla /.wine /.wine-pipelight /shared /.Xauthority /.bash_history /.zsh_history /docker-volumes 
  /.wastebasket)

rsync_exclusions_file=`mktemp`
for pattern in "${exclusions[@]}"
do 
  echo $pattern >> ${rsync_exclusions_file}
done


remote_storage_mountpoint=${HOME}/shared

dir_to_be_backed_up=${HOME}

# Check that remote_storage_mountpoint is mounted:

echo Checking remote storage mount point  ${remote_storage_mountpoint}

if findmnt ${remote_storage_mountpoint} >&/dev/null
then
  echo Remote storage ${remote_storage_mountpoint} mounted OK
else
  mount ${remote_storage_mountpoint}
  if ! (  findmnt ${remote_storage_mountpoint} >&/dev/null )
  then
    echo `date '+%F %R'` Failed to mount remote storage ${remote_storage_mountpoint} >> ${log_file}
    mount_cmd=`which mount.cifs`
    if [ ! -u ${mount_cmd} ]; then
      echo \ \ Need to do:  sudo chmod u+s ${mount_cmd}  >> ${log_file}
    fi  
    exit 40
  fi
fi

# For the mount command to work, you need to tell Linux how to mount the backup directory, e.g. via a line like this in fstab:
# //192.168.0.15/mari /backup  cifs  users,noauto,uid=mari,gid=mari,username=mari,password=XXX,file_mode=0644,dir_mode=0755   0 0


# Set rsync options, including a directory where it will backup any files on the NAS that it is asked to delete
rsync_backupdir=../`date '+%F'`
rsync_opts="-r --progress --stats --times --delete --safe-links --backup --backup-dir=${rsync_backupdir}"

from_dir=${dir_to_be_backed_up}
to_dir=${remote_storage_mountpoint}/rsync_backup/${HOSTNAME}/snapshot

echo backing up from ${from_dir}
echo \ \ \ \ \ \ \ \ \ \ \ \ \ to ${to_dir}

mkdir -p ${to_dir}


declare -A rsync_code_dict
rsync_code_dict=( \
["0"]="Success" \
["1"]="Syntax or usage error" \
["2"]="Protocol incompatibility" \
["3"]="Errors selecting input/output files, dirs" \
["4"]="Requested  action not supported: an attempt was made to manipulate 64-bit files on a platform that cannot support them; or an option was specified that is supported by the client and not by the server." \
["5"]="Error starting client-server protocol" \
["6"]="Daemon unable to append to log-file" \
["10"]="Error in socket I/O" \
["11"]="Error in file I/O" \
["12"]="Error in rsync protocol data stream" \
["13"]="Errors with program diagnostics" \
["14"]="Error in IPC code" \
["20"]="Received SIGUSR1 or SIGINT" \
["21"]="Some error returned by waitpid()" \
["22"]="Error allocating core memory buffers" \
["23"]="Partial transfer due to error" \
["24"]="Partial transfer due to vanished source files" \
["25"]="The --max-delete limit stopped deletions" \
["30"]="Timeout in data send/receive" \
["35"]="Timeout waiting for daemon connection" )


if [[ "${interactive}" == "true" ]]
then
  # if running interactively we will do a dry run first. At the end we
  # give a list of all files that would be deleted in the target directory
  echo Doing dry run first...
  rsyncout=`mktemp`
  rsync --dry-run ${rsync_opts} --exclude-from=${rsync_exclusions_file} \
    ${from_dir}/ ${to_dir} | tee ${rsyncout}
  echo
  echo ==== DELETIONS:
  grep '^deleting' ${rsyncout}
  echo ====
  echo
  response="xxx"
  while [[ $response != 'y' && $response != 'n' ]]
  do
    read -p "Now do it for real (y|n)? " response
  done
  if [[ ${response} != 'y' ]]
  then
    exit 0
  fi
fi

# This is the actual backup, done using rsync:

cmd="${rsync_opts} --exclude-from=${rsync_exclusions_file} \
    ${from_dir}/ ${to_dir}"
echo rsync ${cmd}
rsync ${rsync_opts} --exclude-from=${rsync_exclusions_file} \
    ${from_dir}/ ${to_dir} &> ${HOME}/last_rsync.log

rsync_status=$?
rsync_message="${rsync_code_dict[${rsync_status}]}"

# Logging: write a ststus message to the log file
echo `date '+%F %R'` rsync exit status ${rsync_status}: ${rsync_message}  >> ${log_file}

#echo Unmounting remote storage mount point  ${remote_storage_mountpoint}
#umount ${remote_storage_mountpoint}

#exit ${rsync_status}

