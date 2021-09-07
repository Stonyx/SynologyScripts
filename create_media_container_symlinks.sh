#!/bin/bash

# Declare needed variables
declare -a container_paths=("/volume1/docker/radarr" "/volume3/docker/sonarr")

# Preface the verbose output from the ln and chown commands
echo "The create_media_container_symlinks.sh script performed the following action(s):"

# Loop through the containers
for container_path in "${container_paths[@]}"
do
  # Check if localtime symoblic link doesn't exist for this container
  if [[ ! -h "$conatiner_path/localtime" ]]
  then
    # Create the symlink
    echo -n "created symlink "
    ln --symbolic --verbose "/etc/localtime" "$container_path/localtime"

    # Change the symlink permissions
    chown --no-dereference --verbose "media-container:users" "$container_path/localtime"
  fi
done