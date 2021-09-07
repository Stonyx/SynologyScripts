#!/bin/bash

# Declare needed variables
declare -a disks_to_keep=("/dev/sda" "/dev/sde")
declare -a disks_to_remove=("/dev/sdb" "/dev/sdc" "/dev/sdd")
declare -A dsm_array_partition_map=(["/dev/md0"]="1" ["/dev/md1"]="2")

# Loop through the DSM arrays and make sure everything is as expected
for dsm_array in "${!dsm_array_partition_map[@]}"
do
  # Get the array details
  declare array_details=$(mdadm --misc --detail "$dsm_array")

  # Get the array devices count
  declare -i array_devices_count=$(echo "$array_details" | grep --extended-regex \
    "^ +Raid Devices : [0-9]+$" | grep --extended-regex --only-matching "[0-9]+")

  # Check if the array devices count is less than or equal to the number of disks to keep
  if (( $array_devices_count <= ${#disks_to_keep[@]} ))
  then
    echo "The \"$dsm_array\" raid array device count is already less than or equal to the number" \
      "of disks to keep."
    echo "No actions will be performed."
    exit 1
  fi

  # Get the array devices details
  declare array_devices_details=$(echo "$array_details" | grep --after-context=100 \
    --extended-regex "^ +Number +Major +Minor +RaidDevice +State$" | grep --extended-regex \
    --invert-match "^ +Number +Major +Minor +RaidDevice +State$")

  # Loop through the disks to keep
  for disk_to_keep in "${disks_to_keep[@]}"
  do
    # Get the corresponding disk partition for this array
    declare partition="$disk_to_keep${dsm_array_partition_map[$dsm_array]}"

    # Check if the partition is part of this array as an active device
    if echo "$array_devices_details" | grep --extended-regex \
      "^ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +active sync +$partition$" --quiet
    then
      # Remove this device from the array devices details string
      array_devices_details=$(echo "$array_devices_details" | grep --extended-regex \
        --invert-match "^ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +active sync +$partition$")
    else
      echo "The \"$partition\" partition is not an active device in the \"$dsm_array\" raid array."
      echo "Double check the specified disks to keep."
      echo "No actions will be performed."
      exit 1
    fi
  done

  # Loop through the disks to remove
  for disk_to_remove in "${disks_to_remove[@]}"
  do
    # Get the corresponding disk partition for this array
    declare partition="$disk_to_remove${dsm_array_partition_map[$dsm_array]}"

    # Check if the partition is part of this array as an active device or as a spare device
    if echo "$array_devices_details" | grep --extended-regex \
      "^ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +active sync +$partition$" --quiet || \
      echo "$array_devices_details" | grep --extended-regex \
      "^ +[0-9]+ +[0-9]+ +[0-9]+ +- +spare +$partition$" --quiet
    then
      # Remove this device from the array devices details string
      array_devices_details=$(echo "$array_devices_details" | grep --extended-regex \
        --invert-match "^ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +active sync +$partition$" | grep \
        --extended-regex --invert-match "^ +[0-9]+ +[0-9]+ +[0-9]+ +- +spare +$partition$")
    else
      echo "The \"$partition\" partition is not an active or spare device in the \"$dsm_array\"" \
        "raid array."
      echo "Double check the specified disks to remove."
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
    echo "The \"$dsm_array\" raid array has unexpected devices or device states."
    echo "No actions will be performed."
    exit 1
  fi
done

# Loop through the DSM arrays and perform the changes
declare -i make_things_pretty=1
for dsm_array in "${!dsm_array_partition_map[@]}"
do
  # Preface the verbose output from the mdadm commands
  echo "The change_dsm_raid_disks.sh script performed the following action(s) on the" \
    "\"$dsm_array\" raid array:"

  # Loop through the disks to remove
  declare -a removed_partitions=()
  for disk_to_remove in "${disks_to_remove[@]}"
  do
    # Get the corresponding disk partition for this array
    declare partition="$disk_to_remove${dsm_array_partition_map[$dsm_array]}"

    # Remove the partition from this array and add it to the removed partitions array
    mdadm --manage "$dsm_array" --fail "$partition" --remove "$partition" --verbose
    removed_partitions+=("$partition")
  done

  # Resize this array
  if (( ${#disks_to_keep[@]} == 1 ))
  then
    mdadm --grow --raid-devices=${#disks_to_keep[@]} "$dsm_array" --force --verbose
  else
    mdadm --grow --raid-devices=${#disks_to_keep[@]} "$dsm_array" --verbose
  fi

  # Loop through the removed partitions
  for removed_partition in "${removed_partitions[@]}"
  do
    # Add the partition back to this array as a spare device
    mdadm --manage "$dsm_array" --add-spare "$removed_partition" --verbose
  done

  # Make things pretty
  if (( $make_things_pretty == 1 ))
  then
    echo
    make_things_pretty=0
  fi
done