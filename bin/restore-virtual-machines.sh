#!/bin/bash
#
#  Restore virtual machines to the inital state
#
#set -euo pipefail

cat <<END
** WARNING **

This restores the QCOW2 images for the class to what you originally
recieved. This process takes a long time. Also any changes you made
within the VM for class will be lost.

END

fix_names=$(virsh list --all | grep "shut\ off" | awk '{print $2}')

git_root="/root/bhusa2023"
virt_dir="/var/lib/libvirt/images"

restore_images(){
    for domain in ${fix_names} ; do
        if [[ ! -f ${git_root}/files/${domain}.reinstall ]] ; then
            echo "Missing: ${git_root}/files/${domain}.reinstall"
            echo "I'll creating one for you."
            virsh dumpxml ${domain} > ${git_root}/files/${domain}.reinstall
        fi
        if [[ -f ${virt_dir}/${domain}.qcow2 ]]; then
            virsh start ${domain} 2>/dev/null 
            virsh destroy ${domain} 2>/dev/null
            virsh undefine ${domain} 2>/dev/null
            
            # Clean up a typo that put the file in the wrong place, ugh.
            if [[ -f ${virt_dir}${domain}.qcow2 ]]; then
                rm -rf ${virt_dir}${domain}.qcow2
            fi

            echo "Restoring ${domain}.qcow2 ..."
            echo "zcat ${virt_dir}/backup/${domain}.qcow2.gz > ${virt_dir}/${domain}.qcow2"
            
            zcat ${virt_dir}/backup/${domain}.qcow2.gz > ${virt_dir}/${domain}.qcow2
            chown -R libvirt-qemu:libvirt-qemu /var/lib/libvirt/images
            virsh define ${git_root}/files/${domain}.reinstall

            # Make a virtual machine disk sparse
            du -sh --apparent-size ${virt_dir}/${domain}.qcow2
	    echo "virt-sparsify --in-place ${virt_dir}/${domain}.qcow2"
            virt-sparsify --in-place ${virt_dir}/${domain}.qcow2
            du -sh ${virt_dir}/${domain}.qcow2
            echo "-----------------------------------------------------"
        fi
    done
}

echo -n "Do you want to contine? (y/N): "

read answer
case $answer in
y|Y)
	restore_images;;
*)
	exit;;
esac
