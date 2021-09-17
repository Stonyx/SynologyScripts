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

  # Get the array active devices count
  declare -i array_active_devices_count=$(echo "$array_details" | grep --extended-regex \
    "^ +Active Devices : [0-9]+$" | grep --extended-regex --only-matching "[0-9]+")
  
  # Check if the array active devices count is greater than one
  if (( $array_active_devices_count > 1 ))
  then
    echo "The $array raid array active device count is already greater than one."
    echo "No actions will be performed on the $array raid array."
    if (( $make_things_pretty == 1 ))
    then
      echo
      make_things_pretty=0
    fi
    continue
  fi

  # Get the array devices count
  declare -i array_devices_count=$(echo "$array_details" | grep --extended-regex \
    "^ +Raid Devices : [0-9]+$" | grep --extended-regex --only-matching "[0-9]+")

  # Check if the array devices count is less than the number of disks to restore to or not
  #   equal to the number of disks to restore to and disks to not use have been specified
  if (( $array_devices_count < ${#disks_to_restore_to[@]} + 1 || 
    ($array_devices_count != ${#disks_to_restore_to[@]} + 1 && ${#disks_to_not_use[@]} > 0) ))
  then
    echo "The $array raid array device count is less than the number of disks to restore" \
      "to or not equal to the number of disks to restore to and disks to not use have been" \
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

  # Get the corresponding disk partition for this array
  declare partition="$disk_to_restore_from${array_partition_map[$array]}"

  # Check if the partition is part of this array as an active device
  if echo "$array_devices_details" | grep --extended-regex \
    "^ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +active sync +$partition$" --quiet
  then
    # Remove the partition from the array devices details string
    array_devices_details=$(echo "$array_devices_details" | grep --extended-regex \
      --invert-match "^ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +active sync +$partition$")
  else
    echo "The $partition partition is not an active device in the $array raid array."
    echo "Double check the specified disk to restore from."
    echo "No actions will be performed on the $array raid array."
    if (( $make_things_pretty == 1 ))
    then
      echo
      make_things_pretty=0
    fi
    continue
  fi

  # Remove removed devices from the array devices details string
  array_devices_details=$(echo "$array_devices_details" | grep --extended-regex --invert-match \
    "^ +- +[0-9]+ +[0-9]+ +[0-9]+ +removed$")    

  # Check if there are any other devices left in the array devices details string
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
  echo "Performed the following action on the $array raid array:"

  # Loop through the disks to restore to
  for disk_to_restore_to in "${disks_to_restore_to[@]}"
  do
    # Get the corresponding disk partition for this array
    declare partition="$disk_to_restore_to${array_partition_map[$array]}"

    # Add the partition back to this array as an active device
    mdadm --manage "$array" --add "$partition"
  done

  # Loop through the disks to not use
  for disk_to_not_use in "${disks_to_not_use[@]}"
  do
    # Get the corresponding disk partition for this array
    declare partition="$disk_to_not_use${array_partition_map[$array]}"

    # Add the partition back to this array as a spare device
    mdadm --manage "$array" --add-spare "$partition"
  done
 
  # Make things pretty
  if (( $make_things_pretty == 1 ))
  then
    echo
    make_things_pretty=0
  fi
done
