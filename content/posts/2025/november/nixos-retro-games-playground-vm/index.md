+++
date = '2025-11-10T22:31:22+01:00'
draft = false
title = 'NixOS + Retro Games - Testing Playground with QEMU'
tags = ["retro", "nixos", "games"]
+++
In my previous post I mentioned the idea of turning NixOS into a minimal retro gaming console. The system should boot straight into a simple menu instead of a traditional desktop. From there, the user can configure the network, pair new gamepads, adjust audio settings and finally launch emulators.

I’ll stick with a simple design, as the target hardware probably won’t be very powerful. I will choose one of the thin clients that I have in my collection.

<!--more-->

## Virtual test environment
However, before I start working on the real hardware, it’s better to test changes on a virtual machine. NixOS can easily be configured to run in a virtual machine, which should make testing easier and faster. Each iteration is simply a new run of the virtual machine.

I decided to use QEMU for this. It's fairly straightforward to write a simple script that will glue together the process of building NixOS image and running a virtual machine. This approach will also allow me to use [NixOS Testing library](https://nixos.wiki/wiki/NixOS_Testing_library), so that I can add automated tests in the future.

## Testing with QEMU

To start testing my custom NixOS module, I need to create a basic live CD image. Let me start with the configuration file:
```nix
{ pkgs, lib, modulesPath, config, ... }: {
  system.stateVersion = "25.05";

  imports = [
		(modulesPath + "/profiles/qemu-guest.nix")
	];

  networking.hostName = "retro-test-vm";

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoResize = true;
  };
  boot.loader.grub.device = lib.mkDefault "/dev/vda";

  system.build.qcow2 = import "${modulesPath}/../lib/make-disk-image.nix" {
    inherit lib config pkgs;
    diskSize = 10240;
    format = "qcow2";
    partitionTableType = "hybrid";
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true; # test-only; do not use in production
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
    };
  };

  users.users.tester = {
    isNormalUser = true;
    extraGroups = [ "wheel" "audio" "video" ];
    initialPassword = "test";
  };
  security.sudo.wheelNeedsPassword = false;

  services.qemuGuest.enable = true;

  networking.useDHCP = lib.mkDefault true;

  boot = {
    initrd.systemd.enable = true;
    initrd.kernelModules = [ "drm" "virtio_gpu" ];
    kernelParams =
      [ "quiet" "splash" "panic=1" "boot.panic_on_fail" ];
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  environment.systemPackages = with pkgs; [
    curl wget vim git htop
    usbutils

    iproute2 iputils bind.host
    
    alsa-utils pulseaudio pipewire wireplumber
  ];
}

```
This configuration produces an image with a minimal set of packages and services. SSH server is enabled and a `tester` user is created with the default password: `test`. Audio support is also enabled.

### Building the image
In order to create `.qcow2` image, I need to adjust the `flake.nix` file. I'm using [flake-parts](https://github.com/nix-community/flake-parts) more out of habit than necessity.
Here's how the image is exposed from the flake:
```nix
{
# ...
  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      flake.nixosConfigurations = {
        retro = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./test-vm.nix ];
        };
      };
    };
# ...
}
```
To make the build process a bit more convenient, I also add a simple app definition:
```nix
{
# ...
  outputs = inputs@{ self, nixpkgs, flake-parts, rust-overlay, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
# ...
      perSystem = { config, system, pkgs, ... }: {
        apps = {
          build-qcow = {
            type = "app";
            program = (pkgs.writeShellScript ""
              "nix build .#nixosConfigurations.retro.config.system.build.qcow2").outPath;
          };
        };
      };
    };
# ...
}
```
I can now test whether the image is configured correctly. Running the build looks like this:
```bash
nix run .#build-qcow  --show-trace
ls result
#nixos.qcow2  nix-support
```
After the build is finished, I can find the image in the `./result` directory.

### Booting the VM
With that done, I can move on to running the VM. Here's a simple script that rebuilds the image (if needed) and starts the VM with SSH forwarding enabled:
```bash
#!/usr/bin/env bash
set -euo pipefail

nix run .#build-qcow

IMG_PATH="./result/nixos.qcow2"
if [ ! -f "$IMG_PATH" ]; then
  echo "Could not find qcow image" >&2
  exit 1
fi

TMPDIR="./tmp"
mkdir -p "${TMPDIR}"
IMAGE="${TMPDIR}/nixos.qcow2"
cp $IMG_PATH $IMAGE
chmod 640 $IMAGE

: "''${QEMU_CPUS:=2}"
: "''${QEMU_RAM_MB:=2048}"
: "''${SSH_HOST_PORT:=2222}"

exec qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp "$QEMU_CPUS" \
  -m "$QEMU_RAM_MB" \
  -audiodev pa,id=snd0 \
  -device virtio-vga-gl,blob=true,venus=true,hostmem=4G \
  -display gtk,gl=on,show-cursor=off \
  -vga none \
  -device ich9-intel-hda \
  -device hda-output,audiodev=snd0 \
  -device qemu-xhci \
  -usb \
  -drive cache=writeback,file=$IMAGE,id=drive1,if=none,index=1,werror=report \
  -device virtio-blk-pci,bootindex=1,drive=drive1 \
  -netdev user,id=n1,hostfwd=tcp::"$SSH_HOST_PORT"-:22 \
  -device virtio-net-pci,netdev=n1
```
Each time it runs, the script copies the image into `./tmp` and starts a clean instance. Audio from the host machine is forwarded to the VM, and graphics acceleration is enabled too.

It can be run as simply as:
```bash
./run-test-vm.sh
```

The result should be a VM that boots into the NixOS image:

{{< image alt="qemu showing login prompt" src="vm-running.png" caption="QEMU with custom NixOS image" fit="640x640" >}}

This setup lets me test changes quickly while keeping everything reproducible and portable. That's exactly what I need before I start working with real hardware. 

In the next post, I'll focus on the app that will serve as the main menu for this machine.


