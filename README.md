# webserver (deprecated)

⚠️ This repository has been merged with [my website](https://github.com/bossley9/website).

My website server NixOS configuration

## Setup (Vultr)

1. Go to [https://channels.nixos.org](https://channels.nixos.org) to find the latest stable minimal x86_64 ISO url.
2. Deploy a server in Vultr using the custom ISO link from earlier. I chose a plan with 1 GB RAM.
3. Log into the web console and copy over ssh keys to perform the rest of the installation via ssh.
    ```sh
    mkdir ~/.ssh
    curl -L https://github.com/YOUR_USERNAME.keys > ~/.ssh/authorized_keys
    cat ~/.ssh/authorized_keys # sanity check
    ```
    The following steps can now be performed via SSH (`ssh nixos@MY_IP_ADDRESS`).
4. Log into root and set up packages.
    ```sh
    sudo -i
    nix-shell -p git
    set -o vi
5. Partition the disk, where the swap is the same size as allocated RAM. MBR partitioning is required or the VPS may not recognize any bootable partitions.
    ```sh
    fdisk -l # sanity check
    parted /dev/vda -- mklabel msdos
    parted /dev/vda -- mkpart primary 1MB -2GB
    parted /dev/vda -- mkpart primary linux-swap -2GB 100%
    ```
6. Format each partition. I recommend ext4 over btrfs because a VPS generally doesn't need CoW or snapshot features, and ext4 is slightly faster and uses less storage.
    ```sh
    mkfs.ext4 -L root /dev/vda1
    mkswap -L swap /dev/vda2
    swapon /dev/vda2
    mount /dev/disk/by-label/root /mnt
    ```
7. Generate a configuration derived from hardware.
    ```sh
    nixos-generate-config --root /mnt
    ```
8. Copy this configuration and move files into the appropriate locations. Be sure to double check the hardware configuration for discrepancies.
9. Copy SSH public keys for server access. **If you do not do this, you will be locked out of the server.**
    ```sh
    cp /home/nixos/.ssh/authorized_keys /mnt/etc/nixos/keys.pub
    ```
10. Install the operating system.
    ```sh
    nixos-install --no-root-passwd
    ```
11. In the Vultr dashboard, remove the custom ISO. This will trigger a VPS reboot. Then verify you can access the server as `nixos@domain` or `nixos@ip` via SSH.
