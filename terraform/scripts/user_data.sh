#!/bin/bash
set -e

# Update and install Samba server and SMB client utilities
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y samba smbclient cifs-utils

# Create shared directory with open permissions
mkdir -p /home/admin/shared
mkdir -p /srv/samba/shared
chmod -R 0777 /home/admin/shared
chmod -R 0777 /srv/samba/shared

# Create a sample test file
echo "Hello from GCP Simulated On-Premise VM ($(hostname))" > /home/admin/shared/test-file.txt

# Configure Samba share
cat >> /etc/samba/smb.conf << 'EOF'

[public]
    comment = Public Share (Simulated On-Premise)
    path = /home/admin/shared
    browsable = yes
    guest ok = yes
    read only = no
    create mask = 0775
    directory mask = 0775
EOF

# Restart and enable Samba service
systemctl restart smbd
systemctl enable smbd

# Create a helper script to easily mount AWS Storage Gateway SMB share from this VM
cat > /home/admin/mount-aws-storage-gateway.sh << 'EOF'
#!/bin/bash
# Usage: sudo ./mount-aws-storage-gateway.sh <GATEWAY_IP> <SHARE_NAME> [PASSWORD]
GATEWAY_IP=$1
SHARE_NAME=$2
PASSWORD=${3:-GuestPass123!}
MOUNT_POINT=/mnt/aws-storage-gateway

if [ -z "$GATEWAY_IP" ] || [ -z "$SHARE_NAME" ]; then
    echo "Usage: sudo $0 <GATEWAY_IP> <SHARE_NAME> [PASSWORD]"
    exit 1
fi

mkdir -p "$MOUNT_POINT"
# AWS Storage Gateway guest account is 'smbguest' and requires 'seal' for MandatoryEncryption
mount -t cifs "//$GATEWAY_IP/$SHARE_NAME" "$MOUNT_POINT" -o username=smbguest,password="$PASSWORD",vers=3.0,seal

if [ $? -eq 0 ]; then
    echo "Successfully mounted AWS Storage Gateway SMB share at $MOUNT_POINT"
else
    echo "Failed to mount SMB share"
fi
EOF

chmod +x /home/admin/mount-aws-storage-gateway.sh
