touch /etc/systemd/system/getty@tty1.service.d/autologin.conf

cat <<EOF > /etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noissue --autologin signage %I $TERM
EOF

sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub
update-grub

apt install curl wget cage xwayland chromium vainfo intel-media-va-driver lm-sensors nmap grim

cd /tmp
wget https://nodejs.org/download/release/v14.21.3/node-v14.21.3-linux-x64.tar.gz
mkdir -p /opt
cd /opt
tar -xzf /tmp/node-v14.21.3-linux-x64.tar.gz
ln -sf /opt/node-v14.21.3-linux-x64/bin/node /usr/local/bin/node
ln -sf /opt/node-v14.21.3-linux-x64/bin/npm /usr/local/bin/npm
ln -sf /opt/node-v14.21.3-linux-x64/bin/npx /usr/local/bin/npx

npm install -g lsi-soar

su - signage -c "soar bind deploy.lsidigital.com"
su - signage -c "soar set player vendor LSI"
su - signage -c "soar set player browser /usr/bin/chromium"
su - signage -c "soar fetch transcend remote"

cat <<EOF > /home/signage/.config/systemd/user/remote.service
[Unit]
Description=DSN Remote Service

[Service]
ExecStart=soar run remote
Environment="Home=/home/signage"

[Install]
WantedBy=default.target
EOF

cat <<EOF > /home/signage/.config/systemd/user/player.service
[Unit]
Description=DSN Player Service

[Service]
ExecStartPre=/usr/bin/sleep 1
ExecStart=/usr/bin/cage soar run transcend
Environment="Home=/home/signage"
Environment="WAYLAND=true"

[Install]
WantedBy=default.target
EOF

su - signage -c "systemctl --user daemon-reexec"
su - signage -c "systemctl --user enable remote.service"
su - signage -c "systemctl --user enable player.service"

cat <<EOF > /etc/systemd/system/hostname.service
[Unit]
Description=Set Hostname to Serial Number
After=network-online.target
Before=network.target shutdown.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/hostname.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable hostname.service

sensors-detect
/etc/init.d/kmod/start

cat <<EOF >> /etc/network/interfaces
...previous lines

# IF YOU NEEED TO SET A STATIC IP
# COMMENT OUT THE LINE ABOVE ENDING
# WITH "dhcp" AND UNCOMMNET THE FOLLOWING.

# MAKE SURE TO REPLACE THE VALUES!

#iface enp0s29f1 inet static
#address 10.1.1.2
#netmask 255.255.255.0
#gateway 10.1.1.1
#dns-nameservers 8.8.8.8 1.1.1.1 9.9.9.9
EOF

cat <<EOF >> /home/signage/.profile
alias get_temp='sensors'

alias get_serial='sudo dmidecode | grep -A6 "System Information" | grep "Serial Number" | awk "{\$1=\$2=\"\"; print \$0}"'

alias get_timezone='timedatectl'

alias get_network='echo "IP Address:" && ip addr show | awk '"'"'/inet / {split($2, a, "/"); print a[1]}'"'"' && \
echo -e "\nSubnet Mask:" && ip addr show | awk '"'"'/inet / {print $2}'"'"' | cut -d "/" -f 2 && \
echo -e "\nDefault Gateway:" && ip route | awk '"'"'/default via/ {print $3}'"'"' && \
echo -e "\nDNS Addresses:" && cat /etc/resolv.conf | awk '"'"'/nameserver / {print $2}'"'"''

alias get_update='soar fetch transcend'

alias set_network='sudo nano /etc/network/interfaces'

alias set_timezone='sudo timedatectl set-timezone'

alias set_rotation_0="sed -i 's|^ExecStart=.*$|ExecStart=/usr/bin/cage /home/signage/.nvm/versions/node/v14.21.3/bin/soar run transcend|' /home/signage/.config/systemd/user/player.service && systemctl --user daemon-reload && systemctl --user restart player.service"

alias set_rotation_90="sed -i 's|^ExecStart=.*$|ExecStart=/usr/bin/cage -r /home/signage/.nvm/versions/node/v14.21.3/bin/soar run transcend|' /home/signage/.config/systemd/user/player.service && systemctl --user daemon-reload && systemctl --user restart player.service"

alias set_rotation_180="sed -i 's|^ExecStart=.*$|ExecStart=/usr/bin/cage -r -r /home/signage/.nvm/versions/node/v14.21.3/bin/soar run transcend|' /home/signage/.config/systemd/user/player.service && systemctl --user daemon-reload && systemctl --user restart player.service"

alias set_rotation_270="sed -i 's|^ExecStart=.*$|ExecStart=/usr/bin/cage -r -r -r /home/signage/.nvm/versions/node/v14.21.3/bin/soar run transcend|' /home/signage/.config/systemd/user/player.service && systemctl --user daemon-reload && systemctl --user restart player.service"

alias restart_player='systemctl --user restart player.service'

alias reboot_player='sudo reboot'

alias get_player='soar fetch transcend -f'

alias reset_player='find ~/.soar -mindepth 1 -maxdepth 1 ! \( -name modules -o -name cache -o -name soar.json \) -exec rm -rf {} + && set_rotation_0 && systemctl --user restart remote.service'

alias ping_dsn="nping dsn.lsidigital.com"

alias ping_player="nping player.lsidigital.com"

alias ping_remote="nping remote.lsidigital.com"

alias trace_dsn="traceroute dsn.lsidigital.com"

alias trace_player="traceroute player.lsidigital.com"

alias trace_remote="traceroute remote.lsidigital.com"

alias get_help='echo -e "\n\e[0mThe following shortcuts are available\n\n\e[32mget_help\e[0m - shows this list of shortcuts.\n\e[32mget_temp\e[0m - \e[39mgets the system temperature information.\n\e[32mget_serial\e[0m - \e[39mgets the serial number.\n\e[32mget_network\e[0m - \e[39mgets the network configuration.\n\e[32mget_timezone\e[0m - \e[39mgets the timezone configuration.\n\e[32mset_timezone\e[0m - \e[39msets a new timezone. Requires an arg like US/Eastern.\n\e[32mset_network\e[0m - \e[39mopens the network configuration so you can set a static IP.\n\e[32mset_rotation_0\e[0m - \e[39msets the display rotation to 0 degrees.\n\e[32mset_rotation_90\e[0m - \e[39msets the display rotation to 90 degrees.\n\e[32mset_rotation_180\e[0m - \e[39msets the display rotation to 180 degrees.\n\e[32mset_rotation_270\e[0m - \e[39msets the display rotation to 270 degrees.\n\e[32mrestart_player\e[0m - \e[39mrestart the player service.\n\e[32mreboot_player\e[0m - \e[39mreboots the device.\n\e[32mget_update\e[0m - \e[39mgets and installs the newest player update.\n\e[32mget_player\e[0m - \e[39mforces a reinstall of the player module.\n\e[32mreset_player\e[0m - \e[39mclears all content and settings including the uid.\n\e[32mping_dsn\e[0m - \e[39muses tcp to ping dsn.lsidigital.com.\n\e[32mping_player\e[0m - \e[39muses tcp to ping player.lsidigital.com.\n\e[32mping_remote\e[0m - \e[39muses tcp to ping remote.lsidigital.com.\n\e[32mtrace_dsn\e[0m - \e[39mruns traceroute to dsn.lsidigital.com.\n\e[32mtrace_player\e[0m - \e[39mruns traceroute to player.lsidigital.com.\n\e[32mtrace_remote\e[0m - \e[39mruns traceroute to remote.lsidigital.com.\n\e[0m"'
EOF
