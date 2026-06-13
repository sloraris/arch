# Arch
My personal helper scripts for installing Arch, btw.
*Definitely written by Gemini with some help.*

## Post-installation but pre-boot
Takes your username as an argument for dealing with commands that cannot be run as root or that deal with the user's home directory.
```bash
curl -fsSL https://raw.githubusercontent.com/sloraris/arch/refs/heads/main/post-archinstall.sh | bash -s -- <username>
```
## Post-installation and post-boot
### Plymouth only
The following will make your bootup screen look a little nice without installing my personal dotfiles/configs.
```bash
curl -fsSL https://raw.githubusercontent.com/sloraris/arch/refs/heads/main/plymouth.sh | bash
```
### Everything
```bash
curl -fsSL https://raw.githubusercontent.com/sloraris/arch/refs/heads/main/desktop.sh | bash
```
This will replicate my personal PC setup with the following:
- DankLinux (interactive install, can use `ctrl+c` to exit and skip it)
- Apps
  - Spotify
  - Obsidian
  - Steam
  - Equibop
  - Helium Browser
  - Modrinth (Minecraft mod client)
- Bibata Cursor theme
