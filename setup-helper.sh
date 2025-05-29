#!/bin/bash
set -e

USERNAME="signage"

echo "[+] Installing dependencies..."
apt update
apt install -y \
  chromium \
  xserver-xorg xinit openbox x11-utils x11-xserver-utils dbus-x11 \
  mesa-utils libva2 libva-drm2 libva-x11-2 intel-media-va-driver \
  fonts-freefont-ttf unclutter wget curl bash nano p7zip-full ca-certificates sudo


if ! id "$USERNAME" &>/dev/null; then
  echo "[+] Creating user $USERNAME"
  useradd -m -s /bin/bash "$USERNAME"
  echo "$USERNAME:$USERNAME" | chpasswd
fi


echo "[+] Installing Node.js 14..."
cd /tmp
wget https://nodejs.org/download/release/v14.21.3/node-v14.21.3-linux-x64.tar.gz
mkdir -p /opt
cd /opt
tar -xzf /tmp/node-v14.21.3-linux-x64.tar.gz
ln -sf /opt/node-v14.21.3-linux-x64/bin/node /usr/local/bin/node
ln -sf /opt/node-v14.21.3-linux-x64/bin/npm /usr/local/bin/npm
ln -sf /opt/node-v14.21.3-linux-x64/bin/npx /usr/local/bin/npx


echo "[+] Installing SOAR..."
npm install -g lsi-soar
ln -sf /opt/node-v14.21.3-linux-x64/bin/soar /usr/local/bin/soar


echo "[+] Configuring LightDM for autologin..."
sed -i 's/^#*autologin-user=.*/autologin-user=signage/' /etc/lightdm/lightdm.conf || true
sed -i 's/^#*autologin-user-timeout=.*/autologin-user-timeout=0/' /etc/lightdm/lightdm.conf || true
sed -i 's/^#*user-session=.*/user-session=openbox/' /etc/lightdm/lightdm.conf || echo -e "[Seat:*]\nautologin-user=signage\nautologin-user-timeout=0\nuser-session=openbox" >> /etc/lightdm/lightdm.conf


echo "[+] Setting boot options to hide output..."
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash vt.global_cursor_default=0 loglevel=0"/' /etc/default/grub
update-grub
systemctl mask getty@tty1


echo "[+] Creating .xinitrc for signage (Openbox)..."
cat <<EOF > /home/$USERNAME/.xinitrc
#!/bin/bash
export DISPLAY=:0
export XDG_RUNTIME_DIR=/run/user/\$(id -u)
unclutter --timeout 0 &
xset s off
xset -dpms
xset s noblank
exec openbox-session
EOF

chown $USERNAME:$USERNAME /home/$USERNAME/.xinitrc
chmod +x /home/$USERNAME/.xinitrc


echo "[+] Configuring Openbox autostart..."
su - $USERNAME -c "mkdir -p /home/$USERNAME/.config/openbox"
cat <<EOF > /home/$USERNAME/.config/openbox/autostart
#!/bin/bash
export DISPLAY=:0
export XDG_RUNTIME_DIR=/run/user/\$(id -u)
export HOME=/home/$USERNAME

unclutter --timeout 0 &
xset s off -dpms s noblank

systemctl --user start remote.service
systemctl --user start player.service
EOF

chown $USERNAME:$USERNAME /home/$USERNAME/.config/openbox/autostart
chmod +x /home/$USERNAME/.config/openbox/autostart


echo "[+] Creating SOAR user services..."
su - $USERNAME -c "mkdir -p /home/$USERNAME/.config/systemd/user"

cat <<EOF > /home/$USERNAME/.config/systemd/user/remote.service
[Unit]
Description=SOAR Remote
After=network.target

[Service]
ExecStart=/usr/local/bin/soar run remote
Restart=always
RestartSec=5
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/%U
Environment=HOME=/home/%u

[Install]
WantedBy=default.target
EOF

cat <<EOF > /home/$USERNAME/.config/systemd/user/player.service
[Unit]
Description=SOAR Transcend Player
After=remote.service
Requires=remote.service

[Service]
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/%U
Environment=HOME=/home/%u
ExecStartPre=/bin/bash -c 'for i in {1..30}; do xset q >/dev/null 2>&1 && exit 0 || sleep 0.5; done; exit 1'
ExecStart=/usr/local/bin/soar run transcend
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

chown -R $USERNAME:$USERNAME /home/$USERNAME/.config


echo "[+] Enabling user linger and services..."
loginctl enable-linger $USERNAME
su - $USERNAME -c "systemctl --user daemon-reexec"
su - $USERNAME -c "systemctl --user daemon-reload"
su - $USERNAME -c "systemctl --user enable remote.service"
su - $USERNAME -c "systemctl --user enable player.service"


echo "[✓] Setup complete. Rebooting..."
systemctl reboot now
