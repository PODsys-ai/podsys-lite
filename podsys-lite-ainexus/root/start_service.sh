#!/bin/bash
cd $(dirname $0)

source /root/generate_dnsmasq_conf.sh
source /root/generate_ipxe_cfg.sh
source /root/generate_userdata.sh
source /root/generate_kickstart.sh

echo -e "\033[43;31m "Welcome to the podsys-lite"\033[0m"
echo "  ____     ___    ____    ____   __   __  ____  "
echo " |  _ \   / _ \  |  _ \  / ___|  \ \ / / / ___| "
echo " | |_) | | | | | | | | | \___ \   \ V /  \___ \ "
echo " |  __/  | |_| | | |_| |  ___) |   | |    ___) |"
echo " |_|      \___/  |____/  |____/    |_|   |____/ (lite)"
echo

echo -e "\033[31mdhcp-config : /etc/dnsmasq.conf\033[0m"

manager_ip=$(grep "manager_ip" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')
manager_nic=$(grep "manager_nic" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')
compute_storage=$(grep "compute_storage" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')
nexus_passwd=$(grep "nexus_passwd" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')
PermitRootLogin=$(grep "PermitRootLogin" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')
dhcp_s=$(grep "dhcp_s" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')
dhcp_e=$(grep "dhcp_e" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')
nexus_encrypted_password=$(printf "${nexus_passwd}" | openssl passwd -6 -salt 'FhcddHFVZ7ABA4Gi' -stdin)
iso=$(grep "iso" /workspace/config.yaml | cut -d ":" -f 2 | tr -d '[:space:]')

if [ ! -f "/workspace/${iso}" ]; then
  echo "ISO not exist : /workspace/${iso}"
  exit 1
fi

chmod 755 /workspace/${iso}
mount /workspace/${iso} /iso >/dev/null 2>&1

if [[ "${iso}" == ubuntu* ]]; then
  ipxe_cfg=$(generate_ipxe_cfg_ubuntu "$manager_ip" "$iso")
  userdata=$(generate_userdata "$manager_nic" "$nexus_encrypted_password" "$PermitRootLogin" "$compute_storage")
  echo -e "$userdata" >>/user-data/user-data
  echo -e "\033[31muser-data   : /user-data/user-data\033[0m"
elif [[ "${iso}" == Rocky* || "${iso}" == CentOS* ]]; then
  ipxe_cfg=$(generate_ipxe_cfg_rocky "$manager_ip" "$iso")
  kickstart=$(generate_kickstart "$manager_nic" "$nexus_encrypted_password" "$PermitRootLogin" "$compute_storage")
  echo -e "$kickstart" >>/kickstart/kickstart.cfg
  echo -e "\033[31mkickstart  : /kickstart/kickstart.cfg\033[0m"
else
  echo "unsupport ISO: ${iso}"
  umount /iso
  exit 1
fi


dnsmasq_conf=$(generate_dnsmasq_conf "$manager_nic" "$dhcp_s" "$dhcp_e")
echo "$dnsmasq_conf" >/etc/dnsmasq.conf
echo "$ipxe_cfg" >/tftp/ipxe.cfg

# start server
echo
service dnsmasq start
sleep 1
service dnsmasq status
echo
chmod 755 -R /workspace/log
nohup /root/podsys-lite-core >/dev/null 2>&1 &
