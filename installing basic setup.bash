#!/bin/bash

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
	echo "%LinuxAdm@gruppe6.dk ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers
else
    echo "Sudo is already installed."
fi

# Install required packages for joining a Windows Domain
echo "Installing required packages for joining a Windows Domain..."
apt install -qq -y realmd sssd samba-common krb5-user krb5-config samba-common-bin sssd-tools libnss-sss libpam-sss adcli 

# Discover the domain
DOMAIN="gruppe6.dk"
USER="frol"
echo "Discovering domain $DOMAIN..."
realm discover $DOMAIN

# Join the domain
echo "Joining the domain $DOMAIN..."
realm join --user=$USER $DOMAIN --Install=/

# File to check
SSSD_CONF="/etc/sssd/sssd.conf"

# Check for both lines in a single statement
if grep -q "chpass_provider = ad" "$SSSD_CONF" && grep -q "auth_provider = ad" "$SSSD_CONF"; then
    echo "Both 'chpass_provider = ad' and 'auth_provider = ad' are present in $SSSD_CONF"
else
    echo "chpass_provider = ad" | sudo tee -a /etc/sssd/sssd.conf
	echo "auth_provider = ad" | sudo tee -a /etc/sssd/sssd.conf
fi

# File to check for pam_mkhomedir.so
PAM_SESSION_CONF="/etc/pam.d/common-session"
PAM_LINE="session required pam_mkhomedir.so skel=/etc/skel/ umask=0022"

# Check for both lines in a single statement
if grep -q "session required pam_mkhomedir.so skel=/etc/skel/ umask=0022"; then
    echo "Both 'chpass_provider = ad' and 'auth_provider = ad' are present in $SSSD_CONF"
else
    # Check if the pam_mkhomedir.so line is present, and add it if not
	echo "$PAM_LINE" | sudo tee -a "$PAM_SESSION_CONF"
fi

# Check if the pam_mkhomedir.so line is present, and add it if not
grep -qF "$PAM_LINE" "$PAM_SESSION_CONF" || echo "$PAM_LINE" | sudo tee -a "$PAM_SESSION_CONF"


# Enable and start SSSD service
echo "Enabling and starting SSSD service..."
systemctl enable sssd
systemctl start sssd

# Variables
DOMAIN="example.com"
DOMAIN_IP="domain_ip"
AD_OU="ad_ou"

# Check /etc/resolv.conf
if grep -q "search $DOMAIN" /etc/resolv.conf && grep -q "nameserver $DOMAIN_IP" /etc/resolv.conf; then
    echo "Found 'search $DOMAIN' and 'nameserver $DOMAIN_IP' in /etc/resolv.conf."
else
    echo "Missing 'search $DOMAIN' or 'nameserver $DOMAIN_IP' in /etc/resolv.conf."
    FILE_NOT_FOUND="/etc/resolv.conf"
fi

# Check /etc/network/interfaces
if grep -q "den-nameservers $DOMAIN_IP" /etc/network/interfaces && grep -q "dns-search $DOMAIN" /etc/network/interfaces; then
    echo "Found 'den-nameservers $DOMAIN_IP' and 'dns-search $DOMAIN' in /etc/network/interfaces."
else
    echo "Missing 'den-nameservers $DOMAIN_IP' or 'dns-search $DOMAIN' in /etc/network/interfaces."
    FILE_NOT_FOUND="/etc/network/interfaces"
fi

# Check /etc/sudoers
if grep -q "%$AD_OU@$DOMAIN ALL=(ALL:ALL) ALL" /etc/sudoers; then
    echo "Found '%$AD_OU@$DOMAIN ALL=(ALL:ALL) ALL' in /etc/sudoers."
else
    echo "Missing '%$AD_OU@$DOMAIN ALL=(ALL:ALL) ALL' in /etc/sudoers."
    FILE_NOT_FOUND="/etc/sudoers"
fi

# Check /etc/sssd/ssd.conf
if grep -q "chpass_provider = ad" /etc/sssd/ssd.conf && grep -q "auth_provider = ad" /etc/sssd/ssd.conf; then
    echo "Found 'chpass_provider = ad' and 'auth_provider = ad' in /etc/sssd/ssd.conf."
else
    echo "Missing 'chpass_provider = ad' or 'auth_provider = ad' in /etc/sssd/ssd.conf."
    FILE_NOT_FOUND="/etc/sssd/ssd.conf"
fi

# Check /etc/pam.d/common.session
if grep -q "pam_mkhomedir.so skel=/etc/skel/ umask=0022" /etc/pam.d/common-session; then
    echo "Found 'pam_mkhomedir.so skel=/etc/skel/ umask=0022' in /etc/pam.d/common-session."
else
    echo "Missing 'pam_mkhomedir.so skel=/etc/skel/ umask=0022' in /etc/pam.d/common-session."
    FILE_NOT_FOUND="/etc/pam.d/common-session"
fi

if [ -z "$FILE_NOT_FOUND" ]; then
    echo "Realm joined correctly"
else
    echo "Realm not joined correctly, missing string in $FILE_NOT_FOUND"
fi

# Check if OpenSSH server is installed, and install it if not
if ! dpkg -l | grep -qw openssh-server; then
    echo "OpenSSH server is not installed. Installing it..."
    apt install -y openssh-server
else
    echo "OpenSSH server is already installed."
fi

# Configure SSH to use the domain for authentication
echo "Configuring SSH for domain authentication..."
cat <<EOT >> /etc/ssh/sshd_config

# Use domain for authentication
UsePAM yes
EOT

# Restart SSH service to apply changes
echo "Restarting SSH service..."
systemctl restart ssh

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

# Confirm the script execution is complete
echo "Script execution complete. The system should now be able to connect to the Windows DC and support SSH connectivity."
