
generate_kickstart() {
    local manager_nic=$1
    local nexus_encrypted_password=$2
    local PermitRootLogin=$3
    local compute_storage=$4 
    cat <<EOF
# Keyboard layouts
keyboard 'us'



%pre
#!/bin/sh
SN=\`dmidecode -t 1|grep Serial|awk -F : '{print \$2}'|awk -F ' ' '{print \$1}'\`
curl -X POST -d "serial=\$SN" http://${manager_ip}:5000/receive_serial_s
if lspci | grep -i "Mellanox"; then
        curl -X POST -d "serial=\$SN&ibstate=ok" http://${manager_ip}:5000/ibstate
else
        curl -X POST -d "serial=\$SN&ibstate=0" http://${manager_ip}:5000/ibstate
fi
if lspci | grep -i nvidia; then
        curl -X POST -d "serial=\$SN&gpustate=ok" http://${manager_ip}:5000/gpustate
else
        curl -X POST -d "serial=\$SN&gpustate=0" http://${manager_ip}:5000/gpustate
fi

%post
curl -X POST -d "serial=\$SN" http://${manager_ip}:5000/receive_serial_e

%end

EOF
}