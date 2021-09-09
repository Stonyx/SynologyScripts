#!/bin/bash

# Declare needed variables
declare disk_to_restore_from="/dev/sde"
declare -a disks_to_restore_to=("/dev/sda")
declare -a disks_to_not_use=("/dev/sdb" "/dev/sdc" "/dev/sdd")
declare -A dsm_array_partition_map=(["/dev/md0"]="1" ["/dev/md1"]="2")

# Loop through the DSM arrays and make sure everything is as expected
for dsm_array in "${!dsm_array_partition_map[@]}"
do
  # Get the array details
  declare array_details=$(mdadm --misc --detail "$dsm_array")

  # Get the array devices count
  declare -i array_devices_count=$(echo "$array_details" | grep --extended-regex \
    "^ +Raid Devices : [0-9]+$" | grep --extended-regex --only-matching "[0-9]+")

  # Check if the array devices count is less than the number of disks to restore to or not
  #   equal to the number of disks to restore to and disks to not use have been specified
  if (( $array_devices_count < ${#disks_to_restore_to[@]} + 1 || 
    ($array_devices_count != ${#disks_to_restore_to[@]} + 1 && ${#disks_to_not_use[@]} > 0) ))
  then
    echo "The $dsm_array raid array device count is less than the number of disks to restore" \
      "to or not equal to the number of disks to restore to and disks to not use have been" \
      "specified."
    echo "No actions will be performed."
    exit 1
  fi

  # Get the array devices details
  declare array_devices_details=$(echo "$array_details" | grep --after-context=100 \
    --extended-regex "^ +Number +Major +Minor +RaidDevice +State$" | grep --extended-regex \
    --invert-match "^ +Number +Major +Minor +RaidDevice +State$")

  # Loop through the disk to restore from and disks to restore to
  declare disks=("$disk_to_restore_from" "${disks_to_restore_to[@]}")
  for disk in "${disks[@]}"
  do
    # Get the corresponding disk partition for this array
    declare partition="$disk${dsm_array_partition_map[$dsm_array]}"

    # Check if the partition is part of this array as an active device
    if echo "$array_devices_details" | grep --extended-regex \
      "^ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +active sync +$partition$" --quiet
    then
      # Remove the partition from the array devices details string
      array_devices_details=$(echo "$array_devices_details" | grep --extended-regex \
        --invert-match "^ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +active sync +$partition$")
    else
      echo "The $partition partition is not an active device in the $dsm_array raid array."
      echo "Double check the specified disk to restore from and disk(s) to restore to."
      echo "No actions will be performed."
      exit 1
    fi
  done

  # Loop through the disks to not use
  for disk in "${disks_to_not_use[@]}"
  do
    # Get the corresponding disk partition for this array
    declare partition="$disk${dsm_array_partition_map[$dsm_array]}"

    # Check if the partition is part of this array as a spare device
    if echo "$array_devices_details" | grep --extended-regex \
      "^ +[0-9]+ +[0-9]+ +[0-9]+ +- +spare +$partition$" --quiet
    then
      # Remove the partition from the array devices details string
      array_devices_details=$(echo "$array_devices_details" | grep --extended-regex \
        --invert-match "^ +[0-9]+ +[0-9]+ +[0-9]+ +- +spare +$partition$")
    else
      echo "The $partition partition is not a spare device in the $dsm_array raid array."
      echo "Double check the specified disk(s) to not use."
      echo "No actions will be performed."
      exit 1
    fi
  done

  # Remove removed devices from the array devices details string
  array_devices_details=$(echo "$array_devices_details" | grep --extended-regex --invert-match \
    "^ +- +[0-9]+ +[0-9]+ +[0-9]+ +removed$")    

  # Check if there are any other devices left in the array devices details string
  if [[ "$array_devices_details" != "" ]]
  then
    echo "The $dsm_array raid array has unexpected devices or device states."
    echo "No actions will be performed."
    exit 1
  fi
done

# Loop through the DSM arrays and perform the changes
declare -i make_things_pretty=1
for dsm_array in "${!dsm_array_partition_map[@]}"
do
  # Preface the output from the mdadm commands
  echo "The prep_to_restore_dsm_backup.sh script performed the following action(s) on the" \
    "$dsm_array raid array:"

  # Loop through the disks to not use
  for disk in "${disks_to_not_use[@]}"
  do
    # Get the corresponding disk partition for this array
    declare partition="$disk${dsm_array_partition_map[$dsm_array]}"

    # Remove the partition from this array
    mdadm --manage "$dsm_array" --remove "$partition"

    # Overwrite the partition superblock
    echo "mdadm: zeroed $partition superblock"
    mdadm --misc --zero-superblock --metadata=0.9 "$partition"
  done

  # Loop through the disks to restore to
  for disk in "${disks_to_restore_to[@]}"
  do
    # Get the corresponding disk partition for this array
    declare partition="$disk${dsm_array_partition_map[$dsm_array]}"

    # Remove the partition from this array
    mdadm --manage "$dsm_array" --fail "$partition" --remove "$partition"

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