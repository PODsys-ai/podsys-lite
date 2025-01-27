#!/bin/bash
cd $(dirname $0)

get_subnet_mask() {
    ip_address=$1
    ip_info=$(ip a | grep -A 1 $ip_address)
    if [ -z "$ip_info" ]; then
        echo "Error: IP address $ip_address not found." >&2
        exit 1
    fi
    subnet_mask=$(echo "$ip_info" | grep -oE 'inet\s[0-9\.]+/[0-9]+' | grep -oE '/[0-9]+')
    echo $subnet_mask
}

manager_ip=$(grep "manager_ip" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')
manager_nic=$(grep "manager_nic" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')
compute_storage=$(grep "compute_storage" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')
nexus_passwd=$(grep "nexus_passwd" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')
root_passwd=$(grep "root_passwd" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')
PermitRootLogin=$(grep "PermitRootLogin" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')
dhcp_s=$(grep "dhcp_s" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')
dhcp_e=$(grep "dhcp_e" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')
iso=$(grep "iso" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')
subnet_mask=$(get_subnet_mask ${manager_ip})

chmod 755 /workspace/${iso}
mount /workspace/${iso} /iso
cp /iso/casper/initrd* /initrd
cp /iso/casper/vmlinuz /vmlinuz

echo -e "\033[43;31m "Welcome to the podsys-lite"\033[0m"
echo "  ____     ___    ____    ____   __   __  ____  ";
echo " |  _ \   / _ \  |  _ \  / ___|  \ \ / / / ___| ";
echo " | |_) | | | | | | | | | \___ \   \ V /  \___ \ ";
echo " |  __/  | |_| | | |_| |  ___) |   | |    ___) |";
echo " |_|      \___/  |____/  |____/    |_|   |____/ (lite)";
echo

echo -e "\033[31mdhcp-config : /etc/dnsmasq.conf\033[0m"
echo -e "\033[31muser-data   : /user-data/user-data\033[0m"


nexus_encrypted_password=$(printf "${nexus_passwd}" | openssl passwd -6 -salt 'FhcddHFVZ7ABA4Gi' -stdin)

################################ get /etc/dnsmasq.conf

dnsmasq_conf_ipxe=$(cat << EOF
port=5353
interface=$manager_nic
bind-interfaces
dhcp-range=${dhcp_s},${dhcp_e},255.255.0.0,12h
dhcp-match=set:bios,option:client-arch,0
dhcp-match=set:x64-uefi,option:client-arch,7
dhcp-match=set:x64-uefi,option:client-arch,9
dhcp-match=set:ipxe,175
dhcp-boot=tag:bios,undionly.kpxe
dhcp-boot=tag:x64-uefi,snponly.efi
dhcp-boot=tag:ipxe,ipxe.cfg
enable-tftp
tftp-root=/tftp
log-facility=/workspace/log/dnsmasq.log
log-queries
log-dhcp
EOF
)

ipxe_cfg=$(cat << EOF
#!ipxe
set product-name ubuntu
set os-name ${iso}

set menu-timeout 1000
set submenu-timeout \${menu-timeout}
set menu-default exit

:start
menu boot from iPXE server
item --gap --             --------------------------------------------
item --gap -- serial:\${serial}
item --gap -- mac:\${mac}
item --gap -- ip:\${ip}
item --gap -- netmask:\${netmask}
item --gap -- gateway:\${gateway}
item --gap -- dns:\${dns}
item
item --gap --             --------------------------------------------
item install-os \${product-name}
choose --timeout \${menu-timeout} --default \${menu-default} selected || goto cancel
goto \${selected}

:install-os
set server http://${manager_ip}:5000/
initrd \${server}/initrd
kernel \${server}/vmlinuz initrd=initrd ip=dhcp url=\${server}workspace/${iso} autoinstall ds=nocloud-net;s=\${server}user-data/ root=/dev/ram0 cloud-config-url=/dev/null
boot
EOF
)


################################### get user-data
userdata=$(cat << EOF
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
)

echo "$dnsmasq_conf_ipxe" > /etc/dnsmasq.conf
echo "$ipxe_cfg" > /tftp/ipxe.cfg

if [ -s /workspace/mac_ip.txt ]; then
    echo "dhcp-ignore=tag:!known" >> /etc/dnsmasq.conf
    echo "dhcp-hostsfile=/workspace/mac_ip.txt" >> /etc/dnsmasq.conf
fi
echo -e "$userdata" >> /user-data/user-data

########################################start server
echo
sleep 1
echo "starting services: "
service dnsmasq start
echo
sleep 1
echo "checking services: "
service dnsmasq status
echo
chmod 755 -R /workspace/log
nohup  /root/podsys-lite-core  > /dev/null 2>&1 &