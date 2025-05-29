#!/bin/bash
set -e

echo "[+] Installing dependencies..."
apt update
apt install -y \
  chromium \
  xserver-xorg xinit openbox \
  x11-xserver-utils x11-utils mesa-utils \
  libva2 libva-drm2 libva-x11-2 intel-media-va-driver \
  fonts-freefont-ttf unclutter \
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

echo "[+] Creating .xinitrc to launch Openbox..."
cat <<EOF > /home/signage/.xinitrc
#!/bin/bash
export XDG_RUNTIME_DIR=/run/user/$(id -u signage)
export DISPLAY=:0
exec openbox-session
EOF
chown signage:signage /home/signage/.xinitrc
chmod +x /home/signage/.xinitrc

echo "[+] Adding startx to .profile..."
cat <<'EOF' >> /home/signage/.profile
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec startx
fi
EOF
chown signage:signage /home/signage/.profile

echo "[+] Creating user systemd service for SOAR Remote..."
mkdir -p /home/signage/.config/systemd/user
cat <<EOF > /home/signage/.config/systemd/user/remote.service
[Unit]
Description=SOAR Remote
After=graphical.target

[Service]
ExecStart=/usr/local/bin/soar run remote
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
EOF

echo "[+] Creating user systemd service for SOAR Transcend..."
cat <<EOF > /home/signage/.config/systemd/user/player.service
[Unit]
Description=SOAR Transcend (Chromium)
After=graphical.target remote.service
Requires=remote.service

[Service]
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/$(id -u signage)
ExecStartPre=/bin/bash -c 'for i in {1..30}; do xset q >/dev/null 2>&1 && exit 0 || sleep 0.5; done; exit 1'
ExecStart=/usr/local/bin/soar run transcend
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
EOF

chown -R signage:signage /home/signage/.config

echo "[+] Enabling user lingering..."
loginctl enable-linger signage

echo "[+] Enabling user services..."
su - signage -c "systemctl --user daemon-reexec"
su - signage -c "systemctl --user daemon-reload"
su - signage -c "systemctl --user enable remote.service"
su - signage -c "systemctl --user enable player.service"

echo "[✓] Setup complete. Rebooting to launch full stack..."
systemctl reboot now