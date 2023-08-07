#!/bin/bash
set -euo pipefail
#
# Increase the file swap memory. 
#
# - OOM crashing bustakube-control-plane 
#
size="${1:-6}"
file="${2:-$(mktemp /swapfile-XXXXXXX)}"
uuid=$(uuidgen)

echo "Creating swap: ${file} ${size}"
dd if=/dev/zero of=${file} bs=1MiB count=$((${size}*1024))

chmod 0600 ${file}
mkswap --uuid ${uuid} ${file}

echo "# Adding ${file} ${size}G" >> /etc/fstab
echo "${file}   swap   swap  defaults  0 0" >> /etc/fstab
swapon ${file}
