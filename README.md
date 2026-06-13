# Arch
My personal helper scripts for install Arch, btw.
*Definitely written by Gemini with some help.*

## Post-installation but pre-boot
Takes your username as an argument for dealing with commands that cannot be run as root or that deal with the user's home directory.
```bash
curl -fsSL https://raw.githubusercontent.com/your-username/repo/main/post_archinstall.sh | bash -s -- <username>
```
