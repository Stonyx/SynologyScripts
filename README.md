# SynologyScripts

A collection of scripts designed to run on Synology NAS units.

### remove_dsm_disks.sh

This script will change the disks that the Synology DSM operating system is installed on.  It first makes sure the existing RAID array configuration is exactly as the script expects it to be, then it removes the partitions on the disks that were specified to be removed from the OS and swap RAID arrays and adds them back as spare devices so that DSM doesn't complain.

This script can be run via SSH or setup to run at every boot via the Task Scheduler using the GUI.  There is no harm in running this script at every boot.

To use this script, change the first two declare statements to define the disks to keep and the disks to remove and make sure to run the script as root.

This script has been tested extensively, however, we are not responsible for any data loss.  Use at your own risk.

### reset_dsm_disks.sh

This script will undo the changes made by the change_dsm_raid_disks.sh script.  It first makes sure the existing RAID array configuration is exactly as the script expects it to be, then it resizes the array back to having 16 devices.

This script can be run via SSH or setup to run at every boot via the Task Scheduler using the GUI.  There is no harm in running this script at every boot.

To use this script, change the first declare statement to define the disks to use and make sure to run the script as root.

This script has been tested extensively, however, we are not responsible for any data loss.  Use at your own risk.
