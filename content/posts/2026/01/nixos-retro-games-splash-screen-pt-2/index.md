+++
date = '2026-01-10T08:20:08+01:00'
draft = false
title = 'NixOS + Retro Games - Splash Screen pt.2'
tags = ["retro", "plymouth"]
+++

Recently, I created a Python script that generates frames for a splash screen.
The motivation was simple: limit visual noise and provide a better experience for non-technical users.

In this post, I want to focus on finishing that work. The remaining task is preparing the Plymouth scripts. Additionally, I want to pack everything as a NixOS package that can be used as a standard plymouth theme package.

<!--more-->

## Plymouth implementation
Creating a Plymouth theme itself is relatively simple.

I will start with creation of main configuration file `retro.plymouth`, where the theme name and startup script are defined.

```toml
[Plymouth Theme]
Name=retro
Description=Retro console theme for plymouth
ModuleName=script

[script]
ImageDir=@BASEDIR@
ScriptFile=@BASEDIR@/retro.script
```

Next, we need a script that will render our animation.
This part turned out to be a bit more problematic. To be honest, I couldn't find sufficiently good documentation. I mostly relied on existing themes found on github.

For context, these repositories were specifically helpful:
- [minecraft-plymouth-theme](https://github.com/nikp123/minecraft-plymouth-theme/blob/9b3abe7e84ba8ef869a1a9483b5b64ab4321f8ce/plymouth/mc.script)
- [onePiece-plymouth](https://github.com/Anxhul10/onePiece-plymouth/blob/develop/onePiece-plymouth.script)

Moving on to my own script, I started with loading the animation frames. All frames are loaded once at startup then used during rendering, avoiding any I/O lag in the refresh loop.
```kotlin
FRAMES_COUNT = 24;

for (i = 0; i < FRAMES_COUNT; ++i) {
  file_path = "frame_" + i + ".png";
  animation_frames[i].image = Image(file_path);
}

```

At this point, all frames are loaded into memory. 

In this step I create a sprite that will be used to render the animation.

```kotlin
frame_sprite = Sprite();
frame_sprite.SetX(Window.GetWidth() / 2 - animation_frames[0].image.GetWidth() / 2);
frame_sprite.SetY(Window.GetHeight() / 2 - animation_frames[0].image.GetHeight() / 2);
frame_sprite.SetZ(15);
```
Here I use the screen dimensions and the size of the first frame to calculate the sprite position.
I assume that all frames have the same size, which makes calculations easier, as there is no need to recalculate sprite position in each frame.

My theme currently handles only the simplest case, without support for any more complex operations, such as asking for a password or displaying messages from the boot process.

The only thing left to do is to render the animation.
```kotlin
// Split point between the intro sequence and the idle loop
FRAME_RESET = 16;

current_frame = 0;

fun Update() {
  frame_sprite.SetImage(animation_frames[current_frame].image);

  current_frame = (current_frame + 1);
  if (current_frame == FRAMES_COUNT) {
    current_frame = FRAME_RESET;
  }
}

Window.SetBackgroundTopColor(0.0549, 0.0862, 0.1411);
Window.SetBackgroundBottomColor(0.0549, 0.0862, 0.1411);

Plymouth.SetRefreshFunction(Update);
Plymouth.SetRefreshRate(10);
```
10 FPS is enough for this animation and avoids unnecessary redraws during boot.

After reaching the last frame, the animation jumps back to FRAME_RESET.
This allows skipping the initial intro sequence and looping only the idle part of the animation.

## NixOS package

While having a working script, it's time to pack everything into a NixOS package.
The goal is to make the package usable as a `boot.plymouth.themePackages`.

```nix
{ pyproject-nix, pkgs, lib, ... }:
let
  python = pkgs.python3;
  frameGeneratorProject =
    pyproject-nix.lib.project.loadPyproject { projectRoot = ./frames; };
  frameGenerator = python.pkgs.buildPythonPackage
    (frameGeneratorProject.renderers.buildPythonPackage { inherit python; });

  fs = pkgs.lib.fileset;
  baseSrc = fs.unions [ ./retro.plymouth ./retro.script ./frames/computer.png ];
in pkgs.stdenv.mkDerivation {
  pname = "plymouth-theme-retro";
  version = "1.0";
  srcs = [
    (fs.toSource {
      root = ./.;
      fileset = baseSrc;
    })
  ];

  buildInputs = [ frameGenerator ];

  buildPhase = ''
    cd frames
    generate-frames
    cd ..
  '';

  installPhase = ''
    mkdir -p $out/share/plymouth/themes/retro
    cp frames/out/* $out/share/plymouth/themes/retro
    cp retro.plymouth retro.script $out/share/plymouth/themes/retro

    substituteInPlace $out/share/plymouth/themes/retro/*.plymouth --replace '@BASEDIR@' "$out/share/plymouth/themes/retro"

    runHook postInstall
  '';

  meta = { platforms = lib.platforms.all; };
}
```

The main mkDerivation uses an internal package responsible for generating the animation frames at build time, ensuring that no frame generation logic or tooling is required during boot. Other than that, the derivation simply copies the required files (*.plymouth, *.script, and animation frames) into the correct directory.

Finally, this package can be used as a theme package.
```nix
boot.plymouth.themePackages = [ plymouth-theme-retro ];
boot.plymouth.theme = "retro";
```

## Results

{{< video src="splash.webm">}}

With this setup, the user is no longer greeted by a wall of boot-time text, but instead by a more user-friendly animation.