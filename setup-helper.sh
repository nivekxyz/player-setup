#!/bin/bash
set -e

echo "[+] Creating 'signage' user..."
id signage &>/dev/null || useradd -m -s /bin/bash signage

echo "[+] Installing dependencies..."
apt update
apt install -y \
  chromium \
  xserver-xorg xinit x11-xserver-utils x11-utils \
  mesa-utils libva2 libva-drm2 libva-x11-2 \
  intel-media-va-driver \
  fonts-freefont-ttf \
  unclutter \
  wget curl bash nano p7zip-full dbus-x11 ca-certificates sudo

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

echo "[+] Enabling autologin for signage on TTY1..."
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOF > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin signage --noclear %I \$TERM
EOF

systemctl daemon-reexec

echo "[+] Setting up .xinitrc for signage..."
cat <<EOF > /home/signage/.xinitrc
#!/bin/bash
export DISPLAY=:0
unclutter --timeout 0 &
xset s off
xset -dpms
xset s noblank
# Leave X running; player starts separately
while true; do sleep 60; done
EOF
chown signage:signage /home/signage/.xinitrc
chmod +x /home/signage/.xinitrc

echo "[+] Creating user-level systemd service to start X..."
mkdir -p /home/signage/.config/systemd/user
cat <<EOF > /home/signage/.config/systemd/user/x.service
[Unit]
Description=Start X session on TTY1
After=graphical.target

[Service]
ExecStart=/usr/bin/startx
Restart=always

[Install]
WantedBy=default.target
EOF
chown -R signage:signage /home/signage/.config

echo "[+] Enabling user linger for signage..."
loginctl enable-linger signage

echo "[+] Creating user service for SOAR Remote..."
cat <<EOF > /home/signage/.config/systemd/user/remote.service
[Unit]
Description=SOAR Remote
After=network.target

[Service]
ExecStart=/usr/local/bin/soar run remote
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

echo "[+] Creating user service for SOAR Transcend..."
cat <<EOF > /home/signage/.config/systemd/user/player.service
[Unit]
Description=SOAR Transcend Player
After=x.service remote.service
Requires=x.service remote.service

[Service]
Environment=DISPLAY=:0
ExecStartPre=/bin/bash -c 'for i in {1..20}; do xset q >/dev/null 2>&1 && exit 0 || sleep 0.5; done; exit 1'
ExecStart=/usr/local/bin/soar run transcend
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

chown -R signage:signage /home/signage/.config

echo "[+] Enabling user services..."
su - signage -c "systemctl --user daemon-reexec"
su - signage -c "systemctl --user daemon-reload"
su - signage -c "systemctl --user enable x.service"
su - signage -c "systemctl --user enable remote.service"
su - signage -c "systemctl --user enable player.service"

echo "[✓] Setup complete. Rebooting to launch full stack..."
systemctl reboot now