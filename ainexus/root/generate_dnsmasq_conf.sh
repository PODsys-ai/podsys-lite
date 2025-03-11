
generate_dnsmasq_conf() {
    local manager_nic=$1
    local dhcp_s=$2
    local dhcp_e=$3
    cat <<EOF
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
}