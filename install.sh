#!/bin/sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)

sudo visudo -cqf "$here/sudoers/axb35-power"
sudo install -D -m 0755 -o root -g root "$here/bin/axb35-power" /usr/local/bin/axb35-power
sudo install -D -m 0644 -o root -g root "$here/systemd/axb35-power.service" /etc/systemd/system/axb35-power.service
sudo install -D -m 0440 -o root -g root "$here/sudoers/axb35-power" /etc/sudoers.d/axb35-power
sudo systemctl daemon-reload
sudo systemctl enable axb35-power.service

mkdir -p "$HOME/.config/omarchy/plugins"
ln -sfn "$here/plugin/axb35.power" "$HOME/.config/omarchy/plugins/axb35.power"
omarchy-shell shell rescanPlugins
omarchy plugin enable axb35.power
omarchy bar move axb35.power --section right

echo "Installed. Current state:"
/usr/local/bin/axb35-power status
