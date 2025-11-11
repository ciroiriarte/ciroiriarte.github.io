Your environment is using Ceph as a backend for one or both of nova-compute
or cinder and as a result it is essential to use images with raw format in
order to avoid a large capacity and performance impact on your cloud and ceph
cluster. This format is also needed in order to benefit from Copy-on-Write
cloning of images in both Cinder and Nova.




To start provisioning of virtual machine instances, OS images are required. We'll be using Cloud Images provided by the Linux distributions.


Tooling

Depending on the machine you're working on, install guestfs-tools.

openSUSE

	sudo zypper install -y guestfs-tools

Ubuntu

	sudo apt install -y libguestfs-tools whois


Free Images

Find a spot to download files

	mkdir cloud-images
	cd cloud-images

	BOOTDISKSIZE=60G

openSUSE

IMG=Leap-16.0-Minimal-VM.x86_64-Cloud.qcow2
NAME=tmpl-ci-opensuse-leap-16.0-x86_64-$(date '+%Y%m%d.%H%M')

# Download the official image
wget https://download.opensuse.org/repositories/openSUSE:/Leap:/16.0:/Images/images/${IMG}
qemu-img resize ${IMG} ${BOOTDISKSIZE}

# Fix PTP synchronization
echo ptp_kvm > /tmp/ptp_kvm.conf
sudo virt-customize -a ${IMG} --copy-in /tmp/ptp_kvm.conf:/etc/modules-load.d/

glance image-create \
--disk-format qcow2 --container-format bare \
--property os_type='linux' \
--property os_distro='opensuse' \
--property os_version='16.0' \
--property os_license=opensource \
--property os_admin_user='opensuse' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=true \
--property description="openSUSE Leap 16.0 - Cloud Image" \
--visibility public --file ${IMG} --name ${NAME}


Rocky Linux

LVM based image

IMG=Rocky-9-GenericCloud-LVM.latest.x86_64.qcow2 

NAME=tmpl-ci-rocky-9-lvm

wget https://dl.rockylinux.org/pub/rocky/9/images/x86_64/${IMG}
qemu-img resize ${IMG} ${BOOTDISKSIZE}

glance image-create \
--disk-format qcow2 --container-format bare \
--property os_type='linux' \
--property os_distro='rocky' \
--property os_version='9.6' \
--property os_license=opensource \
--property os_admin_user='rocky' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=false \
--property description="Rocky Linux 9.6 with LVM - Cloud Image" \
--visibility public --file ${IMG} --name ${NAME}

Simple partitions image

IMG=Rocky-9-GenericCloud-Base.latest.x86_64.qcow2 

NAME=tmpl-ci-rocky-9

wget https://dl.rockylinux.org/pub/rocky/9/images/x86_64/${IMG}
qemu-img resize ${IMG} ${BOOTDISKSIZE}

glance image-create \
--disk-format qcow2 --container-format bare \
--property os_type='linux' \
--property os_distro='rocky' \
--property os_version='9.6' \
--property os_license=opensource \
--property os_admin_user='rocky' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=false \
--property description="Rocky Linux 9.6 - Cloud Image" \
--visibility public --file ${IMG} --name ${NAME}

Ubuntu 24.04

IMG=noble-server-cloudimg-amd64.img
NAME=tmpl-ci-ubuntu-24.04.3-x86_64-$(date '+%Y%m%d.%H%M')

wget https://cloud-images.ubuntu.com/noble/current/${IMG}
sudo virt-customize -a ${IMG} --install qemu-guest-agent
qemu-img resize ${IMG} ${BOOTDISKSIZE}

glance image-create \
--disk-format qcow2 --container-format bare \
--property os_type='linux' \
--property os_distro='ubuntu' \
--property os_version='24.04.3' \
--property os_license=opensource \
--property os_admin_user='ubuntu' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=true \
--property description="Ubuntu 24.04.3 (Noble) - Cloud Image" \
--visibility public --file ${IMG} --name ${NAME}

Ubuntu 22.04

IMG=jammy-server-cloudimg-amd64.img
NAME=tmpl-ci-ubuntu-22.04.5-x86_64-$(date '+%Y%m%d.%H%M')

wget https://cloud-images.ubuntu.com/jammy/current/${IMG}
sudo virt-customize -a ${IMG} --install qemu-guest-agent
qemu-img resize ${IMG} ${BOOTDISKSIZE}

glance image-create \
--disk-format qcow2 --container-format bare \
--property os_type='linux' \
--property os_distro='ubuntu' \
--property os_version='22.04.5' \
--property os_license=opensource \
--property os_admin_user='ubuntu' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=true \
--property description="Ubuntu 22.04.5 (Jammy) - Cloud Image" \
--visibility public --file ${IMG} --name ${NAME}

Debian 12

IMG=debian-12-generic-amd64.qcow2
NAME=tmpl-ci-debian-12-x86_64-$(date '+%Y%m%d.%H%M')

wget https://cdimage.debian.org/images/cloud/bookworm/latest/${IMG}
sudo virt-customize -a ${IMG} --install qemu-guest-agent
qemu-img resize ${IMG} ${BOOTDISKSIZE}

glance image-create \
--disk-format qcow2 --container-format bare \
--property os_type='linux' \
--property os_distro='debian' \
--property os_version='12.12' \
--property os_license=opensource \
--property os_admin_user='debian' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=true \
--property description="Debian 12.12 (Bookworm) - Cloud Image" \
--visibility public --file ${IMG} --name ${NAME}

Paid Images

RedHat Enterprise Linux 10

Download from the client portal and upload it to a jump host.

IMG=rhel-10.0-x86_64-kvm.qcow2
NAME=tmpl-ci-rhel-10.0-x86_64-$(date '+%Y%m%d.%H%M')
	
qemu-img resize ${IMG} ${BOOTDISKSIZE}

glance image-create \
--disk-format qcow2 --container-format bare \
--property os_type='linux' \
--property os_distro='rhel' \
--property os_version='10.0' \
--property os_license=rhel \
--property os_admin_user='cloud-user' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=true \
--property description="RedHat Enterprise Linux 10.0 - Cloud Image" \
--visibility public --file ${IMG} --name ${NAME}


RedHat Enterprise Linux 9

Download from the client portal and upload it to a jump host.

IMG=rhel-9.6-x86_64-kvm.qcow2
NAME=tmpl-ci-rhel-9.6-x86_64-$(date '+%Y%m%d.%H%M')
	
qemu-img resize ${IMG} ${BOOTDISKSIZE}

glance image-create \
--disk-format qcow2 --container-format bare \
--property os_type='linux' \
--property os_distro='rhel' \
--property os_version='9.6' \
--property os_license=rhel \
--property os_admin_user='cloud-user' \
--property hw_qemu_guest_agent=true \
--property os_require_quiesce=true \
--property hw_require_fsfreeze=true \
--property hw_machine_type="q35" \
--property hw_firmware_type=uefi \
--property hw_serial_port_count=1 \
--property hw_vif_model=virtio \
--property hw_vif_multiqueue_enabled=true \
--property hw_virtio_packed_ring=true \
--property hw_scsi_model=virtio-scsi \
--property hw_disk_bus=scsi \
--property hw_video_model=virtio \
--property has_auto_disk_config=true \
--property description="RedHat Enterprise Linux 9.6 - Cloud Image" \
--visibility public --file ${IMG} --name ${NAME}




Download from: https://yum.oracle.com/templates/OracleLinux/OL9/u5/x86_64/OL9U5_x86_64-kvm-b259.qcow2

Procedure:

wget https://yum.oracle.com/templates/OracleLinux/OL9/u5/x86_64/OL9U5_x86_64-kvm-b259.qcow2

date '+%Y%m%d.%H%M' > /tmp/release.txt
export RELEASE=$(cat /tmp/release.txt)
BOOTDISKSIZE=60G
IMG=OL9U5_x86_64-kvm-b259.qcow2
NAME=img-vanilla-oraclelinux-9.5-x86_64-${RELEASE}.qcow2

qemu-img resize ${IMG} ${BOOTDISKSIZE}

glance image-create --disk-format qcow2 --container-format bare \
  --visibility public --file ${IMG} --name ${NAME}

openstack image create ${NAME} --disk-format qcow2 --container-format bare --public --file ${IMG}
