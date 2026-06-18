#!/bin/bash

# --- PACMAN PACKAGE LIST ---
PACKAGES=(
    # System Core & Dev Tools
    base-devel
    git
    nano
    stow
    fastfetch
    reflector
    bash-completion
    man-pages
    man-db

    # Graphics & Drivers
    nvidia-open
    nvidia-utils
    vulkan-headers

    # Firmware & Networking
    sof-firmware
    networkmanager

    # File Systems & Drive Management
    ntfs-3g
    dosfstools
    exfatprogs
    udiskie
    nfs-utils
    samba

    # File Manager (Thunar)
    thunar
    thunar-archive-plugin
    thunar-volman
    gvfs
    gvfs-smb
    gvfs-nfs
    tumbler

    # Wayland, Portals & Theming
    xdg-desktop-portal-wlr
    xdg-desktop-portal-gtk
    adw-gtk-theme
    gnome-keyring
    libfido2

    # Media & Archives
    7zip
    ffmpeg
    imv
    wiremix
)

# --- ARGUMENT & SYSTEM VALIDATION ---
USERNAME="$1"

if [ -z "$USERNAME" ]; then
  echo "Error: No username provided."
  echo "Usage: ./post_install.sh <username>"
  echo "Via curl: curl -fsSL <url> | bash -s -- <username>"
  exit 1
fi

# Ensure the user actually exists on the system before proceeding
if ! id "$USERNAME" &>/dev/null; then
  echo "Error: User '$USERNAME' does not exist on this system."
  echo "Make sure you created the user during archinstall."
  exit 1
fi

# Exit immediately if a command exits with a non-zero status
set -e 

echo "Starting Post-Installation Configuration for user: $USERNAME..."

# 1. System Settings & Personalization
echo "Configuring pacman, nano, and bash..."
sed -i 's/^#Color/Color\nILoveCandy/' /etc/pacman.conf
sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
pacman -Sy

# Idempotent Appends: Only add if the line doesn't already exist
touch /home/"$USERNAME"/.bashrc /home/"$USERNAME"/.nanorc
grep -qxF 'fastfetch' /home/"$USERNAME"/.bashrc || echo "fastfetch" >> /home/"$USERNAME"/.bashrc
grep -qxF 'set tabsize 4' /home/"$USERNAME"/.nanorc || echo "set tabsize 4" >> /home/"$USERNAME"/.nanorc

chown "$USERNAME":"$USERNAME" /home/"$USERNAME"/.bashrc /home/"$USERNAME"/.nanorc

# 2. Additional Packages
echo "Installing pacman packages..."
pacman -S --needed --noconfirm "${PACKAGES[@]}"

# 3. Reflector Setup
echo "Configuring Reflector..."
MAX_RETRIES=3
RETRY_COUNT=0
REFLECTOR_SUCCESS=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
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
  echo "Warning: Reflector failed after $MAX_RETRIES attempts. Keeping existing mirrorlist."
fi

mkdir -p /etc/xdg/reflector/
cat << 'EOF' > /etc/xdg/reflector/reflector.conf
--save /etc/pacman.d/mirrorlist
--country "United States,Canada,Mexico"
--protocol https
--latest 10
--sort age
EOF

systemctl enable reflector.timer

# 4. Gigabyte Motherboard Sleep Fix
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

# 5. NVIDIA GPU - Initial Boot (mkinitcpio)
echo "Configuring mkinitcpio for NVIDIA..."
sed -i 's/^MODULES=.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
mkinitcpio -P

# 6. NVIDIA GPU - Sleep/Wake Script
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

# 7. GNOME Keyring Configuration
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

# 8. AUR Helper (Paru)
echo "Checking for Paru..."

# Check if paru is already installed for this user
if ! su - "$USERNAME" -c "command -v paru" &> /dev/null; then
  echo "Building and installing Paru..."
  
  echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/temp_script_sudo
  
  su - "$USERNAME" -c "
    cd /tmp
    rm -rf paru
    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg -si --noconfirm
  "
  
  rm /etc/sudoers.d/temp_script_sudo
else
  echo "Paru is already installed. Skipping build."
fi

echo "Configuring Paru..."
# Create paru config dir if it doesn't exist (paru might not have run yet)
mkdir -p /etc/
# If paru.conf doesn't exist, create a basic one so sed doesn't fail
if [ ! -f /etc/paru.conf ]; then
  echo -e "[options]\n#BottomUp\n#CleanAfter" > /etc/paru.conf
fi

sed -i 's/^#BottomUp/BottomUp/' /etc/paru.conf
sed -i 's/^#CleanAfter/CleanAfter/' /etc/paru.conf

# 9. Enable NetworkManager
systemctl enable NetworkManager

echo "========================================="
echo "Post-installation script complete for user: $USERNAME"
echo "========================================="
