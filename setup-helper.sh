#!/bin/bash
set -e

echo "[+] Installing dependencies..."
apt install -y \
  chromium \
  xserver-xorg xinit x11-xserver-utils x11-utils \
  mesa-utils libva2 libva-drm2 libva-x11-2 \
  intel-media-va-driver \
  fonts-freefont-ttf \
  unclutter \
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

echo "[+] Enabling autologin on TTY1..."
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOF > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin signage --noclear %I $TERM
EOF
systemctl daemon-reexec
echo "[!] TTY1 autologin will take effect after reboot."

echo "[+] Creating systemd user service for DSN Player..."
runuser -u signage -- mkdir -p /home/signage/.config/systemd/user
cat <<EOF > /home/signage/.config/systemd/user/dsn-player.service
[Unit]
Description=Start X and DSN Player
After=graphical.target

[Service]
ExecStart=/bin/bash -c '
  export XDG_RUNTIME_DIR=/run/user/$(id -u);
  export DISPLAY=:0;
  startx /usr/local/bin/dsn-x-session
'
Restart=always

[Install]
WantedBy=default.target
EOF

echo "[+] Creating X session script..."
cat <<EOF > /usr/local/bin/dsn-x-session
#!/bin/bash
unclutter --timeout 0 &
xset s off
xset -dpms
xset s noblank
soar run remote &
soar run transcend
EOF

chmod +x /usr/local/bin/dsn-x-session

echo "[+] Enabling systemd user service..."
loginctl enable-linger signage
runuser -u signage -- systemctl --user daemon-reexec
runuser -u signage -- systemctl --user enable dsn-player.service

echo "[✓] Setup complete."
