#!/bin/bash

# Declare needed variables
declare task_logs_path="/volume3/system/scripts/output"
declare archived_logs_path="/volume3/system/logs"

# Get the epoch time for one year ago
declare -i one_year_ago=$(date -d "1 year ago" +%s)

# Preface the verbose output from the rm commands
echo "Performed the following action(s) (if any):"

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
        # Check if this directory is older than one year and delete it
        if (( ${date_path##*/} < $one_year_ago ))
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
      # Check if this directory is older than one year and delete it
      if (( ${date_path##*/} < $one_year_ago ))
      then
        rm --force --recursive --verbose "$date_path"
      fi    
    done
  fi
done

# Loop through all the files in the archived logs path
# Note: since we need to perform regex matching inside the loop we are not using the find
#       command's regex argument
find "$archived_logs_path" -maxdepth 1 -type f -print0 | while IFS="" read -d "" -r path
do
  # Check if the file name matches the expected date format and capture the needed regex group
  declare regex="^.*/[0-9]{4}-[0-9]{2}-[0-9]{2}_([0-9]{4}-[0-9]{2}-[0-9]{2})_?[0-9]*.DB$"
  if [[ "$path" =~ $regex ]]
  then
    # Check if this file is older than one year and delete it
    if (( $(date -d "${BASH_REMATCH[1]}" +%s) < $one_year_ago ))
    then
      rm --force --recursive --verbose "$path"
    fi
  fi
done
