#!/bin/bash
#
#  Fix for "Kubernetes Own the Nodes"
#
fix_names="
bustakube-control-plane
bustakube-node-1
bustakube-node-2
"

git_root="/root/bhusa2023"
virt_dir="/var/lib/libvirt/images"

for domain in ${fix_names} ; do
    if [[ -f ${virt_dir}/${domain}.qcow2 ]]; then
        virsh start ${domain} 2>/dev/null 
        virsh destroy ${domain} 2>/dev/null
        virsh undefine ${domain} 2>/dev/null
        echo "Restoring ${domain}.qcow2 ..."
        # Clean up a typo
        if [[ -f ${virt_dir}${domain}.qcow2 ]]; then
            rm -rf ${virt_dir}${domain}.qcow2
        fi
        zcat ${virt_dir}/backup/${domain}.qcow2.gz > ${virt_dir}/${domain}.qcow2
        chown -R libvirt-qemu:libvirt-qemu /var/lib/libvirt/images
        virsh define ${git_root}/files/${domain}.reinstall        
    fi
done
