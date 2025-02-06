generate_ipxe_cfg_ubuntu() {
    local manager_ip==$1
    local iso=$2
    cat <<EOF
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
initrd \${server}/iso/casper/initrd
kernel \${server}/iso/casper/vmlinuz initrd=initrd ip=dhcp url=\${server}workspace/${iso} autoinstall ds=nocloud-net;s=\${server}user-data/ root=/dev/ram0 cloud-config-url=/dev/null
boot
EOF
}

generate_ipxe_cfg_rocky() {
    local manager_nic=$1
    local iso=$2
    cat <<EOF
#!ipxe
set product-name Linux
set os-name ${iso}

set menu-timeout 3000
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
initrd \${server}/iso/images/pxeboot/initrd.img
kernel \${server}/iso/images/pxeboot/vmlinuz
imgargs vmlinuz initrd=initrd.img  inst.repo=\${server}/iso
boot
EOF
}