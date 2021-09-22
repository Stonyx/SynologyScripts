#!/bin/bash

# Declare needed variables
declare disk_to_restore_from="/dev/sde"
declare -a disks_to_restore_to=("/dev/sda")
declare -a disks_to_not_use=("/dev/sdb" "/dev/sdc" "/dev/sdd")
declare -A array_partition_map=(["/dev/md0"]="1" ["/dev/md1"]="2")

# Loop through the DSM arrays
declare -i make_things_pretty=1
for array in "${!array_partition_map[@]}"
do
  # Get the array details
  declare array_details=$(mdadm --misc --detail "$array")

  # Get the array devices count
  declare -i array_devices_count=$(echo "$array_details" | grep --extended-regex \
    "^ +Raid Devices : [0-9]+$" | grep --extended-regex --only-matching "[0-9]+")

  # Check if the array devices count is less than one (number of disks to restore from) plus the
  #   number of disks to restore to or greater than one (number of disks to restore from) plus the
  #   number of disks to restore to and disks to not use have been specified
  if (( $array_devices_count < 1 + ${#disks_to_restore_to[@]} || 
    ($array_devices_count > 1 + ${#disks_to_restore_to[@]} && ${#disks_to_not_use[@]} > 0) ))
  then
    echo "The $array raid array device count is less than one (the nubmer of disks to restore" \
      "from) plus the number of disks to restore to or greater than one (the number of disks to" \
      "restore from) plus the number of disks to restore to and disks to not use have been" \
      "specified."
    echo "Double check the specified disk(s) to restore to or disk(s) to not use."
    echo "No actions will be performed on the $array raid array."
    if (( $make_things_pretty == 1 ))
    then
      echo
      make_things_pretty=0
    fi
    continue
  fi

  # Get the array devices details
  declare array_devices_details=$(echo "$array_details" | grep --after-context=100 \
    --extended-regex "^ +Number +Major +Minor +RaidDevice +State$" | grep --extended-regex \
    --invert-match "^ +Number +Major +Minor +RaidDevice +State$")

  # Loop through the disk to restore from and disks to restore to
  declare -a disks=("$disk_to_restore_from" "${disks_to_restore_to[@]}")
  for disk in "${disks[@]}"
  do
    # Get the corresponding disk partition for this array
    declare partition="$disk${array_partition_map[$array]}"

    # Check if the partition is part of this array as an active device
    if echo "$array_devices_details" | grep --extended-regex \
      "^ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +active sync +$partition$" --quiet
    then
      # Remove the partition from the array devices details
      array_devices_details=$(echo "$array_devices_details" | grep --extended-regex \
        --invert-match "^ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +active sync +$partition$")
    else
      echo "The $partition partition is not an active device in the $array raid array."
      echo "Double check the specified disk to restore from and disk(s) to restore to."
      echo "No actions will be performed on the $array raid array."
      if (( $make_things_pretty == 1 ))
      then
        echo
        make_things_pretty=0
      fi
      continue 2
    fi
  done

  # Loop through the disks to not use
  for disk in "${disks_to_not_use[@]}"
  do
    # Get the corresponding disk partition for this array
    declare partition="$disk${array_partition_map[$array]}"

    # Check if the partition is part of this array as a spare device
    if echo "$array_devices_details" | grep --extended-regex \
      "^ +[0-9]+ +[0-9]+ +[0-9]+ +- +spare +$partition$" --quiet
    then
      # Remove the partition from the array devices details
      array_devices_details=$(echo "$array_devices_details" | grep --extended-regex \
        --invert-match "^ +[0-9]+ +[0-9]+ +[0-9]+ +- +spare +$partition$")
    else
      echo "The $partition partition is not a spare device in the $array raid array."
      echo "Double check the specified disk(s) to not use."
      echo "No actions will be performed on the $array raid array."
      if (( $make_things_pretty == 1 ))
      then
        echo
        make_things_pretty=0
      fi
      continue 2
    fi
  done

  # Remove removed devices from the array devices details
  array_devices_details=$(echo "$array_devices_details" | grep --extended-regex --invert-match \
    "^ +- +[0-9]+ +[0-9]+ +[0-9]+ +removed$")    

  # Check if there are any devices left in the array devices details
  if [[ "$array_devices_details" != "" ]]
  then
    echo "The $array raid array has unexpected devices or device states."
    echo "No actions will be performed on the $array raid array."
    if (( $make_things_pretty == 1 ))
    then
      echo
      make_things_pretty=0
    fi
    continue
  fi

  # Preface the output from the mdadm commands
  echo "Performed the following action(s) on the $array raid array:"

  # Loop through the disks to not use
  # Note: we loop through the disks to not use first since spare devices need to be removed first
  declare -a partitions_to_not_use=()
  for disk in "${disks_to_not_use[@]}"
  do
    # Get the corresponding disk partition for this array and add it to the partitions to not use
    #   array
    declare partition="$disk${array_partition_map[$array]}"
    partitions_to_not_use+=("$partition")

    # Remove the partition from this array
    mdadm --manage "$array" --remove "$partition"
  done

  # Loop through the disks to restore to
  declare -a partitions_to_restore_to=()
  for disk in "${disks_to_restore_to[@]}"
  do
    # Get the corresponding disk partition for this array and add it to the partitions to restore
    #   to array
    declare partition="$disk${array_partition_map[$array]}"
    partitions_to_restore_to+=("$partition")

    # Fail the partition in this array in preparation for removing the partition
    mdadm --manage "$array" --fail "$partition"
  done

  # Wait to avoid device busy errors
  sleep 1

  # Loop through the partitions to restore to
  for partition in "${partitions_to_restore_to[@]}"
  do
    # Remove the partition from this array
    mdadm --manage "$array" --remove "$partition"
  done

  # Wait to avoid device busy errors
  sleep 1

  # Loop through the partitions to not use and the partitions to restore to
  declare -a partitions=("${partitions_to_not_use[@]}" "${partitions_to_restore_to[@]}")
  for partition in "${partitions[@]}"
  do
    # Overwrite the partition superblock
    echo "mdadm: zeroed $partition superblock"
    mdadm --misc --zero-superblock --metadata=0.9 "$partition"
  done

  # Make things pretty
  if (( $make_things_pretty == 1 ))
  then
    echo
    make_things_pretty=0
  fi
done
