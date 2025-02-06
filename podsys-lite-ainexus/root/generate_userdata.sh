
generate_userdata() {
    local manager_nic=$1
    local nexus_encrypted_password=$2
    local PermitRootLogin=$3
    local compute_storage=$4 
    cat <<EOF
#cloud-config
autoinstall:
  version: 1
  apt:
    disable_components: []
    geoip: true
    fallback: continue-anyway
    preserve_sources_list: false
    primary:
    - arches:
      - amd64
      - i386
      uri: http://archive.ubuntu.com/ubuntu
    - arches:
      - default
      uri: http://ports.ubuntu.com/ubuntu-ports
  drivers:
    install: false
  kernel:
    package: linux-generic
  keyboard:
    layout: us
    toggle: null
    variant: ''
  locale: en_US.UTF-8
  network:
    ethernets:
      nic:
        dhcp4: true
    version: 2
  source:
    id: ubuntu-server
    search_drivers: false
  identity:
    hostname: nexus
    password: ${nexus_encrypted_password}
    realname: nexus
    username: nexus
  ssh:
    allow-pw: true
    authorized-keys: []
    install-server: true
  early-commands:
    - wget http://${manager_ip}:5000/user-data/preseed.sh && chmod 755 preseed.sh && bash preseed.sh ${manager_ip} ${compute_storage}
  late-commands:
    - cp /etc/netplan/00-installer-config.yaml /target/etc/netplan/00-installer-config.yaml
    - curtin in-target --target=/target -- wget http://${manager_ip}:5000/user-data/install.sh
    - curtin in-target --target=/target -- chmod 755 install.sh || true
    - curtin in-target --target=/target -- /install.sh ${manager_ip} ${PermitRootLogin}
    - rm -f  /target/install.sh || true
    - reboot
  storage:
    swap:
        size: 0
    grub:
        reorder_uefi: false
    config:
    - ptable: gpt
      path: /dev/${compute_storage}
      wipe: superblock-recursive
      preserve: false
      name: ''
      grub_device: false
      type: disk
      id: disk-${compute_storage}
    - device: disk-${compute_storage}
      size: 1127219200
      wipe: superblock
      flag: boot
      number: 1
      preserve: false
      grub_device: true
      offset: 1048576
      type: partition
      id: partition-0
    - fstype: fat32
      volume: partition-0
      preserve: false
      type: format
      id: format-0
    - device: disk-${compute_storage}
      size: 2147483648
      wipe: superblock
      number: 2
      preserve: false
      grub_device: false
      offset: 1128267776
      type: partition
      id: partition-1
    - fstype: ext4
      volume: partition-1
      preserve: false
      type: format
      id: format-1
    - device: disk-${compute_storage}
      size: -1
      wipe: superblock
      number: 3
      preserve: false
      grub_device: false
      offset: 3275751424
      type: partition
      id: partition-2
    - name: ubuntu-vg-1
      devices:
      - partition-2
      preserve: false
      type: lvm_volgroup
      id: lvm_volgroup-0
    - name: ubuntu-lv
      volgroup: lvm_volgroup-0
      size: -1
      wipe: superblock
      preserve: false
      type: lvm_partition
      id: lvm_partition-0
    - fstype: ext4
      volume: lvm_partition-0
      preserve: false
      type: format
      id: format-2
    - path: /
      device: format-2
      type: mount
      id: mount-2
    - path: /boot
      device: format-1
      type: mount
      id: mount-1
    - path: /boot/efi
      device: format-0
      type: mount
      id: mount-0
EOF
}