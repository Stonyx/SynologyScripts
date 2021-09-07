#!/bin/bash

# Declare needed variables
declare -a disks_to_use=("/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde")
declare -A dsm_array_partition_map=(["/dev/md0"]="1" ["/dev/md1"]="2")

# Loop through the arrays and make sure everything is as expected
for dsm_array in "${!dsm_array_partition_map[@]}"
do
  # Get the array details
  declare array_details=$(mdadm --misc --detail "$dsm_array")

  # Get the array devices count
  declare -i array_devices_count=$(echo "$array_details" | grep --extended-regex \
    "^ +Raid Devices : [0-9]+$" | grep --extended-regex --only-matching "[0-9]+")

  # Check if the array devices count is 16
  if (( $array_devices_count == 16 ))
  then
    echo "The \"$dsm_array\" raid array device count is already set to 16."
    echo "No actions will be performed."
    exit 1
  fi

  # Get the array devices details
  declare array_devices_details=$(echo "$array_details" | grep --after-context=100 \
    --extended-regex "^ +Number +Major +Minor +RaidDevice +State$" | grep --extended-regex \
    --invert-match "^ +Number +Major +Minor +RaidDevice +State$")

  # Loop through the disks to use
  for disk_to_use in "${disks_to_use[@]}"
  do
    # Get the corresponding disk partition for this array
    declare partition="$disk_to_use${dsm_array_partition_map[$dsm_array]}"

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
    echo "Unexpected devices or device states in the \"$dsm_array\" raid array."
    echo "No actions will be performed."
    exit 1
  fi
done

# Loop through the DSM arrays and perform the changes
for dsm_array in "${!dsm_array_partition_map[@]}"
do
  # Preface the verbose output from the mdadm commands
  echo "The reset_dsm_raid_disks.sh script performed the following action(s) on" \
    "\"$dsm_array\" raid array:"

  # Resize the array
  mdadm --grow --raid-devices=16 "$dsm_array" --force --verbose
done