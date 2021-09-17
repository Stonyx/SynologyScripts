#!/bin/bash

# Declare needed variables
declare -a disks_to_use=("/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde")
declare -A array_partition_map=(["/dev/md0"]="1" ["/dev/md1"]="2")

# Loop through the arrays
declare -i make_things_pretty=1
for array in "${!array_partition_map[@]}"
do
  # Get the array details
  declare array_details=$(mdadm --misc --detail "$array")

  # Get the array devices count
  declare -i array_devices_count=$(echo "$array_details" | grep --extended-regex \
    "^ +Raid Devices : [0-9]+$" | grep --extended-regex --only-matching "[0-9]+")

  # Check if the array devices count is 16
  if (( $array_devices_count == 16 ))
  then
    echo "The $array raid array device count is already set to 16."
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

  # Loop through the disks to use
  for disk in "${disks_to_use[@]}"
  do
    # Get the corresponding disk partition for this array
    declare partition="$disk${array_partition_map[$array]}"

    # Check if the partition is part of this array as an active device or as a spare device
    if echo "$array_devices_details" | grep --extended-regex \
      "^ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +active sync +$partition$" --quiet || \
      echo "$array_devices_details" | grep --extended-regex \
      "^ +[0-9]+ +[0-9]+ +[0-9]+ +- +spare +$partition$" --quiet
    then
      # Remove the partition from the array devices details string
      array_devices_details=$(echo "$array_devices_details" | grep --extended-regex \
        --invert-match "^ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +active sync +$partition$" | grep \
        --extended-regex --invert-match "^ +[0-9]+ +[0-9]+ +[0-9]+ +- +spare +$partition$")
    else
      echo "The $partition partition is not an active or spare device in the $array raid" \
        "array."
      echo "Double check the specified disk(s) to use."
      echo "No actions will be performed on the $array raid array."
      if (( $make_things_pretty == 1 ))
      then
        echo
        make_things_pretty=0
      fi
      continue 2
    fi
  done

  # Remove removed devices from the array devices details string
  array_devices_details=$(echo "$array_devices_details" | grep --extended-regex --invert-match \
    "^ +- +[0-9]+ +[0-9]+ +[0-9]+ +removed$")    

  # Check if there are any other devices left in the array devices details string
  if [[ "$array_devices_details" != "" ]]
  then
    echo "Unexpected devices or device states in the $array raid array."
    echo "No actions will be performed on the $array raid array."
    if (( $make_things_pretty == 1 ))
    then
      echo
      make_things_pretty=0
    fi
    continue
  fi

  # Preface the output from the mdadm commands
  echo "Performed the following action on $array raid array:"

  # Resize the array
  echo -n "mdadm: "
  mdadm --grow --raid-devices=16 --force "$array"
  echo "Waiting for $array raid array to finish rebuilding ..."

  # Wait 60 seconds
  sleep 60

  # Update the array details
  array_details=$(mdadm --misc --detail "$array")

  # Wait until the array is no longer in recovering state
  while echo "$array_details" | grep --extended-regex "^ +State : .*recovering.*$" --quiet
  do
    # Wait 60 seconds
    sleep 60

    # Update the array details
    array_details=$(mdadm --misc --detail "$array")
  done

  # Make things pretty
  if (( $make_things_pretty == 1 ))
  then
    echo
    make_things_pretty=0
  fi
done
