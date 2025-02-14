# Cloud Images

## Template creation
apt install -y libguestfs-tools

mkdir /tmp/cloud-images
cd /tmp/cloud-images

DSTORE="p-replica3"
BRIDGE=vmbr1
VMIDBASE=9000

### Opensuse
let VMID=VMIDBASE+1
IMG=openSUSE-Leap-15.6.x86_64-NoCloud.qcow2
VMNAME="tmpl-ci-opensuse-15.6"

wget https://download.opensuse.org/repositories/Cloud%3A/Images%3A/Leap_15.6/images/${IMG}

qm create ${VMID} --name ${VMNAME} --cores 2 --memory 2048 \
--net0 virtio,firewall=1,bridge=${BRIDGE} --scsihw virtio-scsi-pci \
--bios ovmf --machine q35 --agent enabled=1 --ostype l26 \
--serial0 socket --vga serial0 \
--efidisk0 ${DSTORE}:${VMID},efitype=4m --scsi1 ${DSTORE}:cloudinit

qm importdisk ${VMID} ${IMG} ${DSTORE} --format qcow2
qm set ${VMID} --scsihw virtio-scsi-pci --scsi0 ${DSTORE}:vm-${VMID}-disk-1,discard=on,ssd=1
qm set ${VMID} --boot c --bootdisk scsi0
qm template ${VMID}
rm ${IMG}



### Rocky Linux 9
IMG=Rocky-9-GenericCloud-LVM-9.5-20241118.0.x86_64.qcow2
wget https://dl.rockylinux.org/pub/rocky/9/images/x86_64/${IMG}
qm import 9002

### Ubuntu 24.04
IMG=noble-server-cloudimg-amd64.img
wget https://cloud-images.ubuntu.com/noble/current/${IMG}
virt-customize -a ${IMG} --install qemu-guest-agent
qemu-img resize ${IMG} 10G
qm importdisk 9003 ${IMG} ${DSTORE}

### Ubuntu 22.04
IMG=jammy-server-cloudimg-amd64.img
wget https://cloud-images.ubuntu.com/jammy/current/${IMG}
virt-customize -a ${IMG} --install qemu-guest-agent
qemu-img resize ${IMG} 10G
qm importdisk 9004 ${IMG} replica-3

### Debian 12
IMG=debian-12-generic-amd64.qcow2
wget https://cdimage.debian.org/images/cloud/bookworm/latest/${IMG}
virt-customize -a ${IMG} --install qemu-guest-agent
qemu-img resize ${IMG} 10G
qm importdisk 9005 ${IMG} replica-3

## Template usage
TMPL=tmpl-ci-opensuse-15.6
NETBR=frontend
NETIP="192.168.0.100/24"
NETGW="192.168.0.1"
DNS=8.8.8.8
DNSSEARCH="domain1.com domain2.com"
NEWVMNAME=test100.my.domain
GUESTUSER=cloudadmin
GUESTPASS=Cambiar123
MYKEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC2VGRnhFsToNkKhLuXrzkt4td9P6qodYZ5NdFPO6ZDo6cHp5dbucpGPaFOAUgVohgQf5sG/aIXupdxvvlxinH9G3upLrr/MSORfap18xduSm+xwrewhq6RVZo5kM7J2l6FeQgXJweITB0+FNHl1rj492IdnCMnfbsQ59RjpR+JU/D6oMTbIzBgwfu+i2YtQhvddWqHn406vKFfp0uJOIghzHtxLOU3fOssthQ2IKjMJtfuNRBstSMhdV0mPI6JC3s+3krOBx8Idgz5GCotC7fgQQ2YMWag56LgHZm2fBKDoKFp5IsCoWtcaVElHgHp7Pxz+2cvz9D/QMVbF+ssMCzT Ciro Iriarte v2"
KEYFILE=/tmp/ssh-%{RANDOM}
echo ${MYKEY} > ${KEYFILE}

NEWVM_ID=$(pvesh get /cluster/nextid)
TMPL_ID=$(pvesh get /cluster/resources --type vm --noborder|grep ${TMPL}| awk '{ print $1 }'|cut -f 2 -d "/")

qm clone ${TMPL_ID} ${NEWVM_ID} --name ${NEWVMNAME} --full 1
qm set ${NEWVM_ID} --ciuser ${GUESTUSER} --cipassword ${GUESTPASS}
qm set ${NEWVM_ID} --sshkeys "${KEYFILE}" && rm ${KEYFILE}
qm set ${NEWVM_ID} --ipconfig0 ip=${NETIP},gw=${NETGW}
qm set ${NEWVM_ID} --nameserver ${DNS} --searchdomain "${DNSSEARCH}"
#qm set ${NEWVM_ID} --ciupgrade 0
qm start ${NEWVM_ID}
qm terminal ${NEWVM_ID}
