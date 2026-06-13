#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e 

echo "========================================="
echo "Starting Desktop Configuration"
echo "========================================="

# Additional setup script calls
curl -fsSL https://raw.githubusercontent.com/sloraris/arch/refs/heads/main/plymouth.sh | bash

# 1. Dank Linux Installation
echo ""
echo "-----------------------------------------"
echo "ATTENTION: Dank Linux Installer launching."
echo "When the menu appears, MAKE SURE to select 'dms-greeter'!"
echo "-----------------------------------------"
read -p "Press Enter to acknowledge and continue..."

# Temporarily disable set -e to allow exiting Dank installer without cancelling script
set +e
curl -fsSL https://install.danklinux.com | sh
set -e

# 2. Standard Pacman Packages
echo ""
echo "Installing standard system packages via pacman..."
sudo pacman -S --needed --noconfirm spotify-launcher obsidian steam

# 3. AUR Packages via Paru
echo ""
echo "Installing custom AUR packages via paru..."
paru -S --needed --noconfirm bibata-cursor-theme popsicle-bin helium-browser-bin equibop-bin modrinth-app visual-studio-code-bin

# 4. Audio Profile Configuration
echo ""
echo "Configuring Audio Profiles for Razer and SteelSeries hardware..."

CARDS=$(pactl list cards short | grep -iE 'razer|steel' | awk '{print $2}')

if [ -z "$CARDS" ]; then
    echo " -> No Razer or SteelSeries audio cards detected currently. Skipping profile assignment."
else
    for card in $CARDS; do
        echo " -> Setting profile for: $card"
        pactl set-card-profile "$card" output:iec958-stereo
    done
    echo " -> Audio profiles applied successfully."
fi

echo ""
echo "========================================="
echo "Desktop configuration complete."
echo "========================================="
