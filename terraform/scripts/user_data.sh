#!/bin/bash
sudo apt-get update
sudo apt install samba -y
whereis samba
sudo systemctl status smbd
sudo mkdir shared
cat >> /etc/samba/smb.conf <<EOF

[public]
    comment = Public Share
    path = /home/admin/shared
    browsable = yes
    guest ok = yes
    read only = no
    create mask = 0775
EOF