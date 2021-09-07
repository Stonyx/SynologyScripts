#!/bin/bash

# Declare needed variables
declare -A shared_folder_snapshot_map=(["/volume1/Media"]="/volume1/@sharesnap/Media" \
   ["/volume1/Storage"]="/volume2/@sharesnap/Storage")

# Loop through the shared folder paths
declare -i make_things_pretty=1
for shared_folder_path in "${!shared_folder_snapshot_map[@]}"
do
  # Preface the verbose output from the btrfs commands
  echo "The defrag_modified_files.sh script defragmented the following file(s) in the" \
    "${shared_folder_path#/volume*/} shared folder:"

  # Get the snapshots path for this shared folder
  declare snapshots_path="${shared_folder_snapshot_map[$shared_folder_path]}"

  # Loop through all the snapshots path sub paths
  # Note: since we need to modify a variable inside the while loop we are using process substition
  #       to feed the find command's output to the read command
  declare -i newest_snapshot_time=0
  while IFS="" read -d "" -r snapshot_path
  do
    # Check if the snapshot directory name matches the expected date/time format and capture the
    #   needed regex groups
    declare regex="^.*/(GMT-[0-9]{2})-([0-9]{4})\.([0-9]{2})\.([0-9]{2})-([0-9]{2})\.([0-9]{2})\.([0-9]{2})$"
    if [[ "$snapshot_path" =~ $regex ]]
    then
      # Convert the snapshot directory name to epoch time
      declare -i snapshot_time=$(date -d \
        "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}-${BASH_REMATCH[3]}-${BASH_REMATCH[4]} ${BASH_REMATCH[5]}:${BASH_REMATCH[6]}:${BASH_REMATCH[7]}" \
        +%s)

      # Check if this snapshot time is newer than the current newest snapshot time
      if (( $snapshot_time > $newest_snapshot_time ))
      then
        # Update the newest snapshot time
        newest_snapshot_time=$snapshot_time
      fi
    fi
  # Note: since we need to perform regex matching inside the loop we are not using the find
  #       command's regex argument
  done < <(find "$snapshots_path" -maxdepth 1 -type d ! -path "$snapshots_path" -print0)

  # Find all files modified since the newest snapshot time and loop through them
  find "$shared_folder_path" -type f -newermt "@$newest_snapshot_time" -print0 | \
    while IFS="" read -d "" -r file
  do
    # Defrag the file
    btrfs filesystem defragment -f -t 1G -v "$file"
  done

  # Make things pretty
  if (( $make_things_pretty != ${#shared_folder_snapshot_map[@]} ))
  then
    echo
    make_things_pretty=$((make_things_pretty + 1))
  fi
done