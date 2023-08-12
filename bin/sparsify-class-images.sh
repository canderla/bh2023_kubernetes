#!/usr/bin/env bash
#
# vim:set ts=4 sw=4 sts=4 et:
# 
#set -euo pipefail

cat <<END
** WARNING **

Using virt-sparsify on live virtual machines, or concurrently with 
other disk editing tools, can be dangerous, potentially causing 
disk corruption. The virtual machine must be shut down before you 
use this command, and disk images must not be edited concurrently.

END

virt_dir="/var/lib/libvirt/images"

shrink_qcow2(){
	# Suspend vms
	echo "Start"
	for vm in $(virsh list --all | grep "running" | awk '{print $2}' ) ; do
		echo "Suspending vm $vm ... "
		virsh managedsave $vm
	done

	for vm in $(virsh list --all | grep "shut\ off" | awk '{print $2}' ) ; do
		# Make a virtual machine disk sparse
		du -sh --apparent-size  ${virt_dir}/${vm}.qcow2
		echo "virt-sparsify --in-place ${virt_dir}/${vm}.qcow2"
		virt-sparsify --in-place ${virt_dir}/${vm}.qcow2
		du -sh ${virt_dir}/${vm}.qcow2
		echo "-----------------------------------------------------"
	done
}

echo -n "Do you want to contine? (y/N): "
read answer
case $answer in
y|Y)
	shrink_qcow2 ;;
*)
	exit;;
esac

