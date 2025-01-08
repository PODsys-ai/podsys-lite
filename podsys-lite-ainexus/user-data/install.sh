#!/bin/bash
cd $(dirname $0)

conf_ip() {
    if [ "$http_code" -eq 200 ]; then

        h=$(cat /etc/netplan/00-installer-config.yaml | grep -n dhcp | awk -F ":" '{print $1}' | awk 'NR==1 {print}')
        sed -i ${h}s/true/false/ /etc/netplan/00-installer-config.yaml
        h=$(($h + 1))
        sed -i "${h}i \      addresses: [$IP]" /etc/netplan/00-installer-config.yaml

        if [ -n "$GATEWAY" ] && [ "$GATEWAY" != "none" ]; then
            h=$(($h + 1))
            sed -i "${h}i \      routes:" /etc/netplan/00-installer-config.yaml
            h=$(($h + 1))
            sed -i "${h}i \        - to: default" /etc/netplan/00-installer-config.yaml
            h=$(($h + 1))
            sed -i "${h}i \          via: $GATEWAY" /etc/netplan/00-installer-config.yaml
        fi

        if [ -n "$DNS" ] && [ "$DNS" != "none" ]; then
            h=$(($h + 1))
            sed -i "${h}i \      nameservers:" /etc/netplan/00-installer-config.yaml
            h=$(($h + 1))
            sed -i "${h}i \        addresses: [${DNS}]" /etc/netplan/00-installer-config.yaml
        fi

    else
        network_interface=$(ip route | grep default | awk 'NR==1 {print $5}')
        DHCP_IP=$(ip addr show $network_interface | grep 'inet\b' | awk '{print $2}' | cut -d/ -f1)
        SUBNET_MASK=$(ip addr show $network_interface | grep 'inet\b' | awk '{print $2}' | cut -d/ -f2)
        h=$(cat /etc/netplan/00-installer-config.yaml | grep -n dhcp | awk -F ":" '{print $1}' | awk 'NR==1 {print}')
        sed -i ${h}s/true/false/ /etc/netplan/00-installer-config.yaml
        h=$(($h + 1))
        sed -i "${h}i \      addresses: [$DHCP_IP/$SUBNET_MASK]" /etc/netplan/00-installer-config.yaml
        curl -X POST -d "serial=$SN" http://"$1":5000/receive_serial_ip
       
    fi
    # disable cloud init networkconfig
    echo "network: {config: disabled}" >>/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
    netplan apply
}

install_compute() {

    # purge unattended-upgrades
    apt purge -y unattended-upgrades
    # install MLNX
    if lspci | grep -i "Mellanox"; then
        curl -X POST -d "serial=$SN&ibstate=ok" "http://$1:5000/ibstate"
    else
        curl -X POST -d "serial=$SN&ibstate=0" "http://$1:5000/ibstate"
    fi

    if lspci | grep -i nvidia; then
        curl -X POST -d "serial=$SN&gpustate=ok" "http://$1:5000/gpustate"
    else
        curl -X POST -d "serial=$SN&gpustate=0" "http://$1:5000/gpustate"
    fi
}

SN=$(dmidecode -t 1 | grep Serial | awk -F : '{print $2}' | awk -F ' ' '{print $1}')
response=$(curl -s -w "\n%{http_code}" -X POST -d "serial=$SN" http://$1:5000/request_iplist)

http_code=$(echo "$response" | tail -n 1)
json_response=$(echo "$response" | sed '$d')
if [ "$http_code" -eq 200 ]; then
    HOSTNAME=$(echo "$json_response" | grep -oP '"hostname":\s*"\K[^"]+')
    IP=$(echo "$response" | grep -oP '"ip":\s*"\K[^"]+')
    GATEWAY=$(echo "$response" | grep -oP '"gateway":\s*"\K[^"]+')
    DNS=$(echo "$json_response" | grep -oP '"dns":\s*"\K[^"]+')
else
    HOSTNAME="node${SN}"
fi

install_compute "$1" 
curl -X POST -d "serial=$SN" http://"$1":5000/receive_serial_e

# conf_ip
conf_ip "$1"

if [ "$2" = "yes" ]; then
   echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
   echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
fi