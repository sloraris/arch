#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e 

echo "Starting Generic Plymouth Setup & Bootloader Configuration..."

# 1. Install standard Plymouth (No AUR required for base functionality)
echo "Installing Plymouth..."
sudo pacman -S --needed --noconfirm plymouth

# 2. mkinitcpio Configuration
echo "Configuring mkinitcpio for Plymouth..."
if ! grep -q 'plymouth' /etc/mkinitcpio.conf; then
  sudo sed -i 's/\(base udev\)/\1 plymouth/' /etc/mkinitcpio.conf
  sudo sed -i 's/\(base systemd\)/\1 plymouth/' /etc/mkinitcpio.conf
fi

# 3. Apply the Stock Theme
echo "Applying the stock BGRT theme..."
sudo plymouth-set-default-theme -R bgrt

# 4. Bootloader Detection & Injection
echo "Hunting for bootloader configurations..."
BOOTLOADER_FOUND=false

# --- systemd-boot ---
if [ -d /boot/loader/entries ]; then
  echo "Detected systemd-boot. Injecting kernel parameters..."
  for conf in /boot/loader/entries/*.conf; do
    if ! grep -q "splash" "$conf"; then
      sudo sed -i 's/^options.*/& quiet splash/' "$conf"
      echo " -> Updated $conf"
    fi
  done
  BOOTLOADER_FOUND=true
fi

# --- GRUB ---
if [ -f /etc/default/grub ]; then
  echo "Detected GRUB. Injecting kernel parameters..."
  if ! grep -q "splash" /etc/default/grub; then
    sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 quiet splash"/' /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg
  fi
  BOOTLOADER_FOUND=true
fi

# --- Limine ---
# Limine configs can live in a few places depending on the install method
LIMINE_CONF=""
[ -f /boot/limine.conf ] && LIMINE_CONF="/boot/limine.conf"
[ -f /boot/efi/limine.conf ] && LIMINE_CONF="/boot/efi/limine.conf"
[ -f /boot/limine/limine.conf ] && LIMINE_CONF="/boot/limine/limine.conf"

if [ -n "$LIMINE_CONF" ]; then
  echo "Detected Limine at $LIMINE_CONF. Injecting kernel parameters..."
  if ! grep -q "splash" "$LIMINE_CONF"; then
    # Appends 'quiet splash' to the end of any kernel_cmdline directive
    sudo sed -i '/cmdline/ s/$/ quiet splash/' "$LIMINE_CONF"
    echo " -> Updated $LIMINE_CONF"
  fi
  BOOTLOADER_FOUND=true
fi

# --- rEFInd ---
if [ -f /boot/refind_linux.conf ]; then
  echo "Detected rEFInd. Injecting kernel parameters..."
  if ! grep -q "splash" /boot/refind_linux.conf; then
    # Appends 'quiet splash' inside the quotes of the boot options
    sudo sed -i 's/"$/ quiet splash"/' /boot/refind_linux.conf
    echo " -> Updated /boot/refind_linux.conf"
  fi
  BOOTLOADER_FOUND=true
fi

if [ "$BOOTLOADER_FOUND" = false ]; then
  echo "WARNING: No supported bootloader found. You will need to manually add 'quiet splash' to your kernel parameters."
else
  echo "Bootloader configuration successful."
fi

echo "========================================="
echo "Core Plymouth installation complete!"
echo "========================================="
