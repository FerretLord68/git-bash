#!/bin/bash

# Variables
read DOMAIN
read DOMAIN_I
read AD_OU
read USER
read PASSWORD

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Use sudo to run it."
    exit 1
fi

# Update package list and upgrade packages
echo "Updating package list and upgrading packages..."
apt update -qq && apt upgrade -qq -y

# Install sudo if not already installed
if ! command -v sudo &> /dev/null; then
    echo "Installing sudo..."
    apt install -qq -y sudo
	echo "%$AD_OU@$DOMAIN ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers
else
    echo "Sudo is already installed."
fi

# Check /etc/sudoers
if grep -q "%$AD_OU@$DOMAIN ALL=(ALL:ALL) ALL" /etc/sudoers; then
    echo "Found '%$AD_OU@$DOMAIN ALL=(ALL:ALL) ALL' in /etc/sudoers."
else
    echo "Missing '%$AD_OU@$DOMAIN ALL=(ALL:ALL) ALL' in /etc/sudoers."
    FILE_NOT_FOUND="/etc/sudoers"
fi

# Install OpenSSH server if not already installed
if ! command -v ssh &> /dev/null; then
    echo "Installing OpenSSH server..."
    apt install -y openssh-server
else
    echo "OpenSSH server is already installed."
fi

# Ensure SSH is enabled and started
echo "Enabling and starting SSH service..."
systemctl enable ssh
systemctl start ssh

echo "Installing required packages for joining a Windows Domain..."
sudo apt install -qq -y realmd sssd samba-common krb5-user krb5-config samba-common-bin sssd-tools libnss-sss libpam-sss adcli 

# Edit /etc/krb5.conf to insert dns_lookup_realm and dns_lookup_kdc
echo "Editing /etc/krb5.conf to insert dns_lookup_realm and dns_lookup_kdc..."
sed -i 's/^\(\[libdefaults\]\)/\1\n  dns_lookup_realm = true\n  dns_lookup_kdc = true/' /etc/krb5.conf


# Discover the domain
echo "Discovering domain $DOMAIN..."
realm discover $DOMAIN

# Join the domain
echo "Joining the domain $DOMAIN..."
sudo printf '%s\n' "PASSWORD" | sudo realm join --user="USER" "DOMAIN" --install=/


# Check /etc/sssd/ssd.conf
if grep -q "chpass_provider = ad" /etc/sssd/ssd.conf && grep -q "auth_provider = ad" /etc/sssd/ssd.conf; then
    echo "Found 'chpass_provider = ad' and 'auth_provider = ad' in /etc/sssd/ssd.conf."
else
    echo "Missing 'chpass_provider = ad' or 'auth_provider = ad' in /etc/sssd/ssd.conf."
    FILE_NOT_FOUND="/etc/sssd/ssd.conf"
fi
if [ -z "$FILE_NOT_FOUND" ]; then
    echo "Realm joined correctly"
else
    echo "Realm not joined correctly, missing string in $FILE_NOT_FOUND"
fi
# Check /etc/pam.d/common.session
if grep -q "pam_mkhomedir.so skel=/etc/skel/ umask=0022" /etc/pam.d/common-session; then
    echo "Found 'pam_mkhomedir.so skel=/etc/skel/ umask=0022' in /etc/pam.d/common-session."
else
    echo "Missing 'pam_mkhomedir.so skel=/etc/skel/ umask=0022' in /etc/pam.d/common-session."
    FILE_NOT_FOUND="/etc/pam.d/common-session"
fi

sudo systemctl restart sssd



