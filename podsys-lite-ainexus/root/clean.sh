cd $(dirname $0)
service dnsmasq stop
rm -f /etc/dnsmasq.conf
rm /workspace/log/dnsmasq.log

rm -f /tftp/ipxe.cfg
rm -f /user-data/user-data

rm -f /var/log/dpkg.log
rm -f /var/log/apt/eipp.log.xz
rm -f /var/log/apt/history.log
rm -f /var/log/apt/term.log
rm .viminfo
rm -rf /tmp/*
cat /dev/null > ~/.bash_history

ps aux | grep podsys-lite-core