#!/bin/bash

# Declare needed variables
declare task_logs_path="/volume1/system/scriptoutput"
declare archived_logs_path="/volume1/system/logs"

# Get the epoch time for one month ago
declare -i one_month_ago=$(date -d "1 month ago" +%s)

# Preface the verbose output from the rm commands
echo "The delete_old_logs.sh script performed the following action(s):"

# Loop through all the sub paths in the task logs path
find "$task_logs_path" -maxdepth 1 -type d ! -path "$task_logs_path" -print0 | \
  while IFS="" read -d "" -r path
do
  # Check if this is the "synoscheduler" directory or a custom named triggered task directory
  if [[ "${path##*/}" == "synoscheduler" ]]
  then
    # Loop through all the task sub paths
    find "$path" -maxdepth 1 -type d ! -path "$path" -print0 | while IFS="" read -d "" -r task_path
    do
      # Loop through all the date sub paths for this task
      find "$task_path" -maxdepth 1 -type d ! -path "$task_path" -regextype "posix-extended" \
        -regex "^.*/[0-9]{10}$" -print0 | while IFS="" read -d "" -r date_path
      do
        # Check if this directory is older than one month and delete it
        if (( ${date_path##*/} < $one_month_ago ))
        then
          rm --force --recursive --verbose "$date_path"
        fi    
      done    
    done
  else
    # Loop through all the date sub paths for this task
    find "$path" -maxdepth 1 -type d ! -path "$path" -regextype "posix-extended" \
      -regex "^.*/[0-9]{10}$" -print0 | while IFS="" read -d "" -r date_path
    do
      # Check if this directory is older than one month and delete it
      if (( ${date_path##*/} < $one_month_ago ))
      then
        rm --force --recursive --verbose "$date_path"
      fi    
    done
  fi
done
