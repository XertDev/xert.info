+++
date = '2025-11-22T21:13:42+01:00'
draft = false
title = 'NixOS + Retro Games - Greetd & Kiosk'
tags = ["retro", "nixos", "kiosk", "wayland"]
+++

I ended the previous post with a simple declarative config for NixOS-based VM. Now it's time to start customizing it.


Normally, a system boots into some kind of login prompt, which could be a simple text interface or a fancy graphical one.
For my project, skipping the login step makes the most sense. The system should directly boot into the custom launcher, skipping the authorization process (I might revisit this later to provide user profiles).

<!--more-->

## Login manager
A login manager is a daemon responsible for ensuring that a newly started process for a logged-in user runs in the correct context.
Simply put, it starts a user session.

The simplest approach for this design is to use a minimal login manager. For now, it is enough to configure it to automatically log in as a specific user.

I've used greetd for this purpose. It's simple but highly configurable. Since we don't need a graphical layer for login, we can set it to directly execute our custom launcher.

{{< puml src="diagram-without-compositor.puml" alt="Launcher start flow" caption="System startup flow" fit="800x500" >}}

Greetd handles autologin and starting our launcher.

## Greetd configuration
The configuration of the greetd daemon is rather simple:
```nix
{ lib, pkgs, config, ... }:
let
  cfg = config.blueprint.retro.launcher;
  launcherWrapperCmd = "echo 'Hello world!'";
...

in {
  options.blueprint.retro.launcher = {
    enable = lib.mkEnableOption ("Enable the retro launcher session via greetd");

    autologinUser = lib.mkOption {
      type = lib.types.str;
      default = "retro";
      description = "User used by greetd to run the launcher session";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.graphics.enable = true;
    ...

    services.greetd = {
      enable = true;
      settings = rec {
        initial_session = {
          command = launcherWrapperCmd;
          user = cfg.autologinUser;
        };
        default_session = initial_session;
      };
    };
  };
}
```

I've created a new NixOS module for this purpose. It accepts a username for the user that will be automatically logged in. 

{{< image alt="hello-world virtual machine" src="bare-greetd.png" caption="Greetd configuration test."  fit="500x500">}}

After adding this module to the NixOS configuration, I was able to boot and verify that greetd works correctly.

## Wrapping the launcher

Before moving to the actual launcher, I still need to provide a compositor[^wayland] to run the launcher app.
On a normal desktop system, this role is covered by KDE (kwin[^kwin]) or GNOME (mutter[^mutter]), but I don't need the full desktop environment. 

{{< puml src="diagram-with-compositor.puml" alt="Launcher start flow" caption="System startup flow with compositor" fit="800x700" >}}


I aim for a kiosk-like experience to avoid unnecessary overhead and dependencies.
The compositor needs to handle:
* creating a Wayland session to render a fullscreen window,
* managing input devices,
* managing display output,
* controlling focus.

For this project I chose [Cage](https://github.com/cage-kiosk/cage). 
It is a small compositor designed exactly for running a single application in kiosk mode.
Cage supports a minimal set of protocols required to run applications that don’t rely on advanced Wayland features. In this case, it will host my launcher.

It can run multiple apps, but switching between them is impossible. The last launched app is placed on top and gets input. 
This isn't a problem for now because this limitation fits my requirements anyway. :)

I can now update my greetd config to run Cage with an example app.

```nix
#  launcherWrapperCmd = "echo 'Hello world!'";
   launcherWrapperCmd = "${pkgs.cage}/bin/cage -s -- ${pkgs.mesa-demos}/bin/vkgears";
```

After restarting the VM with the updated NixOS configuration, I see that the vkgears demo runs correctly.
{{< image alt="vkgears demo in virtual machine" src="cage.png" caption="VM with vkgears demo running in Cage." fit="500x500">}}
 

[^wayland]: Description of Wayland architecture: https://wayland.freedesktop.org/architecture.html
[^kwin]: Wayland Compositor used by KDE: https://github.com/KDE/kwin
[^mutter]: Wayland Compositor used by GNOME: https://gitlab.gnome.org/GNOME/mutter