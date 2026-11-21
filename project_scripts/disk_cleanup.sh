#!/bin/bash

# ### Problem
# Your FDFS servers write logs and data every day. One day a disk fills up to 100%, PostgreSQL stops, and you only find out when users complain.

# Write a script that checks every disk on the server and warns you when any of them is **more than 80% full**, showing which disk it is and how full it is, so you can act **before** it's full.




usage_list=$(df -t ext4 | awk 'NR>1 {print $5}' | tr -d '%')
disk_list=$(df -t ext4 | awk 'NR>1 {print $1}')
threshold=10    # use a lower value (e.g. 20) to test the warning

if [ -n "${usage_list}" ]; then
    echo "Checking ext4 disks (warning limit: ${threshold}%)"
else
    echo "ERROR: no ext4 disks found - check the filesystem type"
    exit 1
fi


while IFS= read -r usage && IFS= read -r -u 3 disk; do
    if [ "${usage}" -gt "${threshold}" ]; then
        echo "WARNING: ${disk} is ${usage}% full - take action now"
    else
        echo "OK: ${disk} is ${usage}% full"
    fi
done <<< "${usage_list}" 3<<< "${disk_list}"