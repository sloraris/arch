#!/bin/bash

# --- ARGUMENT VALIDATION ---
USERNAME="$1"

if [ -z "$USERNAME" ]; then
  echo "Error: No username provided."
  echo "Usage: ./post_install.sh <username>"
  echo "Via curl: curl -fsSL <url> | bash -s -- <username>"
  exit 1
fi

# Exit immediately if a command exits with a non-zero status
set -e 

echo "Starting Post-Installation Configuration for user: $USERNAME..."

# 1. Additional Packages
echo "Installing pacman packages..."
# Added --needed to skip already installed packages
pacman -S --needed --noconfirm nvidia-open nvidia-utils nano git base-devel thunar 7zip imv udiskie gnome-keyring fastfetch reflector man-pages man-db sof-firmware wiremix vulkan-headers ffmpeg libfido2 nfs-utils networkmanager

# 2. Reflector Setup
echo "Configuring Reflector..."
# Retry loop for network stability in chroot
MAX_RETRIES=3
RETRY_COUNT=0
REFLECTOR_SUCCESS=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  # The if statement naturally suppresses 'set -e' for the reflector command itself
  if reflector --country "United States,Canada,Mexico" --protocol https --latest 10 --sort age --save /etc/pacman.d/mirrorlist; then
    REFLECTOR_SUCCESS=true
    echo "Reflector completed successfully."
    break
  else
    echo "Reflector failed. Retrying in 5 seconds... ($((RETRY_COUNT+1))/$MAX_RETRIES)"
    sleep 5
    ((RETRY_COUNT++))
  fi
done

if [ "$REFLECTOR_SUCCESS" = false ]; then
  echo "Warning: Reflector failed after $MAX_RETRIES attempts. Keeping existing mirrorlist and continuing script..."
fi

mkdir -p /etc/xdg/reflector/
cat << 'EOF' > /etc/xdg/reflector/reflector.conf
--save /etc/pacman.d/mirrorlist
--country "United States,Canada,Mexico"
--protocol https
--latest 10
--sort age
EOF

# Enable timer (systemctl works differently in chroot, so we don't use --now)
systemctl enable reflector.timer

# 3. Gigabyte Motherboard Sleep Fix
echo "Applying Gigabyte Sleep Fix..."
cat << 'EOF' > /etc/systemd/system/gigabyte-sleep-fix.service
[Unit]
Description=Fix for the suspend issue

[Service]
Type=oneshot
ExecStart=/bin/sh -c "echo GPP0 > /proc/acpi/wakeup"

[Install]
WantedBy=multi-user.target
EOF

systemctl enable gigabyte-sleep-fix

# 4. NVIDIA GPU - Initial Boot (mkinitcpio)
echo "Configuring mkinitcpio for NVIDIA..."
# Replace the existing MODULES line with the NVIDIA modules
sed -i 's/^MODULES=.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
mkinitcpio -P

# 5. NVIDIA GPU - Sleep/Wake Script
echo "Creating NVIDIA sleep/wake script..."
mkdir -p /usr/lib/systemd/system-sleep
cat << 'EOF' > /usr/lib/systemd/system-sleep/nvidia
#!/bin/sh

# This script reloads the NVIDIA kernel modules during the suspend/resume
# cycle to fix driver state bugs, while preserving the user session.

VT_FILE="/run/nvidia-vt-number"

if [ "$1" = "pre" ]; then
  # Action to run BEFORE suspending:
  fgconsole > "${VT_FILE}"
  chvt 63
  sleep 5
  modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia

elif [ "$1" = "post" ]; then
  # Action to run AFTER resuming:
  modprobe nvidia_drm
  modprobe nvidia_modeset
  modprobe nvidia_uvm
  modprobe nvidia

  if [ -f "${VT_FILE}" ]; then
    SAVED_VT=$(cat "${VT_FILE}")
    rm "${VT_FILE}"
    chvt "${SAVED_VT}"
  fi
fi
EOF

chmod +x /usr/lib/systemd/system-sleep/nvidia

# 6. GNOME Keyring Configuration
echo "Configuring PAM for greetd and GNOME Keyring..."
cat << 'EOF' > /etc/pam.d/greetd
auth       required     pam_securetty.so
auth       requisite    pam_nologin.so
auth       include      system-local-login
auth       optional     pam_gnome_keyring.so
account    include      system-local-login
session    include      system-local-login
session    optional     pam_gnome_keyring.so auto_start
EOF

# 7. System Settings & Personalization
echo "Configuring pacman and user dotfiles..."
# Enable Color and ILoveCandy in pacman.conf
sed -i 's/^#Color/Color\nILoveCandy/' /etc/pacman.conf

# Uncomment multilib repository in pacman.conf
sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf

# Update pacman databases after enabling multilib
pacman -Sy

# Add user-specific configurations
echo "fastfetch" >> /home/"$USERNAME"/.bashrc
echo "set tabsize 4" >> /home/"$USERNAME"/.nanorc

# Ensure the user actually owns these modified files, not root
chown "$USERNAME":"$USERNAME" /home/"$USERNAME"/.bashrc /home/"$USERNAME"/.nanorc

# 8. AUR Helper (Paru)
echo "Building and installing Paru..."

# Temporarily allow passwordless sudo for this user so makepkg doesn't hang waiting for stdin
echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/temp_script_sudo

# Switch to the standard user to run makepkg
su - "$USERNAME" -c "
  cd /tmp
  rm -rf paru # Clean up any previous failed clones
  git clone https://aur.archlinux.org/paru.git
  cd paru
  makepkg -si --noconfirm
"

# Revoke temporary passwordless sudo
rm /etc/sudoers.d/temp_script_sudo

echo "Configuring Paru..."
# Uncomment BottomUp and CleanAfter in paru.conf
sed -i 's/^#BottomUp/BottomUp/' /etc/paru.conf
sed -i 's/^#CleanAfter/CleanAfter/' /etc/paru.conf

echo "========================================="
echo "Post-installation script complete for user: $USERNAME!"
echo "========================================="
