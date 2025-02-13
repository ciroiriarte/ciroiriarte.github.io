# Cloud Images
apt install libguestfs-tools

DSTORE="replica-3"
BRIDGE=vmbr1
VMIDBASE=9000

let VMID=VMID+1
IMG=openSUSE-Leap-15.6.x86_64-NoCloud.qcow2
wget https://rsync.opensuse.org/repositories/Cloud%3A/Images%3A/Leap_15.6/images/${IMG}

qm create ${VMID} --name "tmpl-ci-opensuse-15.6" --cores 2 --memory 2048 \
--net0 virtio,firewall=1,bridge=${BRIDGE} --scsihw virtio-scsi-pci \
--bios ovmf --machine q35 --agent enabled=1 --ostype l26 \
--serial0 socket --vga serial0 \
--efidisk0 ${DSTORE}:${VMID},efitype=4m --scsi1 ${DSTORE}:cloudinit

qm importdisk ${VMID} ${IMG} ${DSTORE} --format qcow2
qm set ${VMID} --scsihw virtio-scsi-pci --scsi0 ${DSTORE}:vm-${VMID}-disk-0
#qm resize 90000 scsi0 10G 
#qm set 100000 --ide2 local-lvm:cloudinit
qm set ${VMID} --boot c --bootdisk scsi0
#qm set 100000 --serial0 socket --vga serial0

IMG=Rocky-9-GenericCloud-LVM-9.5-20241118.0.x86_64.qcow2
wget https://dl.rockylinux.org/pub/rocky/9/images/x86_64/${IMG}
qm import 9002

IMG=noble-server-cloudimg-amd64.img
wget https://cloud-images.ubuntu.com/noble/current/${IMG}
virt-customize -a ${IMG} --install qemu-guest-agent
qemu-img resize ${IMG} 10G
qm importdisk 9003 ${IMG} ${DSTORE}

IMG=jammy-server-cloudimg-amd64.img
wget https://cloud-images.ubuntu.com/jammy/current/${IMG}
virt-customize -a ${IMG} --install qemu-guest-agent
qemu-img resize ${IMG} 10G
qm importdisk 9004 ${IMG} replica-3

IMG=debian-12-generic-amd64.qcow2
wget https://cdimage.debian.org/images/cloud/bookworm/latest/${IMG}
virt-customize -a ${IMG} --install qemu-guest-agent
qemu-img resize ${IMG} 10G
qm importdisk 9005 ${IMG} replica-3

