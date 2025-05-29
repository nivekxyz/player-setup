#!/bin/bash
set -e

echo "[+] Installing dependencies..."
apt update
apt install -y \
  chromium \
  xserver-xorg xinit x11-xserver-utils x11-utils \
  mesa-utils libva2 libva-drm2 libva-x11-2 \
  intel-media-va-driver \
  fonts-freefont-ttf \
  unclutter \
  openbox \
  wget curl bash nano p7zip-full dbus-x11 ca-certificates

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

echo "[+] Enabling root autologin on TTY1..."
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOF > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I \$TERM
EOF
systemctl daemon-reexec
echo "[!] TTY1 autologin will take effect after reboot."

echo "[+] Creating X session launcher script..."
cat <<EOF > /usr/local/bin/dsn-x-session
#!/bin/bash
export DISPLAY=:0
unclutter --timeout 0 &
xset s off
xset -dpms
xset s noblank
openbox &
EOF
chmod +x /usr/local/bin/dsn-x-session

echo "[+] Creating system X service..."
cat <<EOF > /etc/systemd/system/x.service
[Unit]
Description=Start X session on boot
After=multi-user.target

[Service]
ExecStart=/usr/bin/startx /usr/local/bin/dsn-x-session -- :0 vt01 -keeptty
Restart=always
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/tmp
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Creating system service for SOAR Remote..."
cat <<EOF > /etc/systemd/system/remote.service
[Unit]
Description=SOAR Remote App
After=network.target

[Service]
ExecStart=/usr/local/bin/soar run remote
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Creating system service for SOAR Transcend (Player)..."
cat <<EOF > /etc/systemd/system/player.service
[Unit]
Description=SOAR Transcend Player
After=remote.service x.service
Requires=remote.service x.service

[Service]
Environment=DISPLAY=:0
ExecStartPre=/bin/bash -c 'for i in {1..20}; do xset q > /dev/null 2>&1 && exit 0 || sleep 0.5; done; exit 1'
ExecStart=/usr/local/bin/soar run transcend
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Enabling system services..."
systemctl enable x.service
systemctl enable remote.service
systemctl enable player.service

echo "[✓] Setup complete. Reboot to launch full stack."