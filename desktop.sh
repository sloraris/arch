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
echo "Installing additional system packages via pacman..."
sudo pacman -S --needed --noconfirm spotify-launcher obsidian steam

# 3. AUR Packages via Paru
echo ""
echo "Installing AUR packages via paru..."
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

# 10. Configure XDG Desktop Portals
echo "Configuring XDG Desktop Portals..."

# Define the path using the USERNAME variable
PORTAL_DIR="/home/$USERNAME/.config/xdg-desktop-portal"

# Create the directory
mkdir -p "$PORTAL_DIR"

# Write the configuration (overwrites if it already exists)
cat << 'EOF' > "$PORTAL_DIR/portals.conf"
[preferred]
default=gtk
org.freedesktop.impl.portal.ScreenCast=wlr
org.freedesktop.impl.portal.Screenshot=wlr
EOF

# Transfer ownership from root back to the actual user
chown -R "$USERNAME":"$USERNAME" "$PORTAL_DIR"

echo " -> portals.conf generated successfully."

# 6. Dotfiles Configuration (GNU Stow)
echo ""
echo "-----------------------------------------"
echo "Dotfiles Configuration (GNU Stow)"
echo "-----------------------------------------"
read -p "Would you like to pull and stow your public dotfiles from GitHub? (y/N): " install_dotfiles

if [[ "$install_dotfiles" =~ ^[Yy]$ ]]; then
    read -p "Enter your GitHub username: " gh_user
    read -p "Enter your dotfiles repository name (e.g., dotfiles): " gh_repo

    if [ -n "$gh_user" ] && [ -n "$gh_repo" ]; then
        # Ensure stow is installed before proceeding
        if ! command -v stow &> /dev/null; then
            echo "Installing GNU Stow..."
            sudo pacman -S --needed --noconfirm stow
        fi

        DOTFILES_DIR="$HOME/$gh_repo"

        if [ -d "$DOTFILES_DIR" ]; then
            echo "Directory $DOTFILES_DIR already exists. Skipping clone."
        else
            echo "Cloning https://github.com/$gh_user/$gh_repo.git..."
            git clone "https://github.com/$gh_user/$gh_repo.git" "$DOTFILES_DIR"
        fi

        if [ -d "$DOTFILES_DIR" ]; then
            echo "Applying Stow configurations..."
            cd "$DOTFILES_DIR"
            
            # Loop through all directories in the repo and stow them
            for dir in */ ; do
                if [ -d "$dir" ]; then
                    pkg="${dir%/}" # Remove trailing slash for cleaner output
                    echo " -> Stowing $pkg..."
                    stow "$pkg" || echo "    [!] Failed to stow $pkg. (You may need to manually remove conflicting default files)."
                fi
            done
            echo "Dotfiles installation finished."
        fi
    else
        echo "Username or repository cannot be empty. Skipping dotfiles."
    fi
else
    echo "Skipping dotfiles installation."
fi

echo ""
echo "========================================="
echo "Desktop configuration complete."
echo "========================================="
