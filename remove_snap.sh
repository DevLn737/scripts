#!/bin/bash

echo "Stopping daemon snapd..."
systemctl stop snapd
systemctl disable snapd

echo "Uninstalling all snap packages..."
snap list | awk '{print $1}' | grep -v "Name" | while read -r snapname; do
  snap remove --purge "$snapname"
done

echo "Uninstalling snapd and linked packages..."
apt-get purge -y snapd
apt-get autoremove -y

echo "Deleting residual files ..."
rm -rf ~/snap
rm -rf /snap
rm -rf /var/snap
rm -rf /var/lib/snapd

echo "The cleaning is complete. Snapd has been completely removed."