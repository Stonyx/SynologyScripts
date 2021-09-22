#!/bin/bash

# Preface the verbose output from the mkdir command and the echo statements
echo "Performed the following action(s) (if any):"

# Check if /dev/net/tun character special file doesn't exist
if [[ ! -c "/dev/net/tun" ]]
then
  # Check if /dev/net directory doesn't exist and create it
  if [[ ! -d "/dev/net" ]]
  then
    mkdir --mode=755 --verbose "/dev/net"
  fi

  # Create /dev/net/tun character special file
  echo "mknod: created character special file '/dev/net/tun'"
  mknod "/dev/net/tun" c 10 200
fi

# Check if tun module isn't loaded and load it
if ! (lsmod | grep -q "^tun\s")
then
  echo "insmod: inserted kernel module '/lib/modules/tun.ko'"
  insmod "/lib/modules/tun.ko"
fi
