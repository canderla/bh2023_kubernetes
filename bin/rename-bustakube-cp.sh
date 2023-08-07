#!/bin/bash

DIR="/usr/lib/libvirt/images"

if [ -e ${DIR}/bustakube-cp.qcow2 ] ; then
   mv ${DIR}/bustakube-cp.qcow2 ${DIR}/bustakube-control-plane.qcow2
fi

if [ -e ${DIR}/bustakube-cp.qcow2.gz ] ; then
   mv ${DIR}/bustakube-cp.qcow2.gz ${DIR}/bustakube-control-plane.qcow2.gz
fi
