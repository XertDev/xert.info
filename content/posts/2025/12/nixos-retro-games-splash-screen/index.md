+++
date = '2025-12-09T00:13:46+01:00'
title = 'Nixos + Retro Games - Splash Screen pt.1'
tags = ["retro", "plymouth", "python"]
[build]
    list='always'
    render = "always"
+++

Before moving on to the launcher, I want to take care of something that appears even earlier in the boot sequence - the splash screen. 

I've tried to create a Plymouth configuration several times before, but something always stopped me. This time, I'm not giving up :).

<!--more-->

# System splash screen

Normally, when Linux boots, you just see service messages scrolling by. 
It works and gives strong technical vibes, but for the average user, it can look confusing or even intimidating.
Standard Debian or NixOS installations behave this way: text first, greeter later.

Some more user-friendly distributions, like Ubuntu, hide all of that behind the splash screen with the distro logo.
This is exactly the effect I want. It will be consistent with the pixel theme that drives the whole project. 

# Plymouth
Plymouth handles the splash screen. It’s made of two components[^plymouth-docs]:
* plymouthd - process which is responsible for rendering the animation,
* plymouth - tool controlling the plymouthd state.

There are many publicly available themes. If someone does not want to create something from scratch, they can use pre-made themes from sites like [gnome-look.org](https://www.gnome-look.org/browse?cat=108&ord=latest).
But for this project I want something custom that will blend with the artistic direction.

# Animation concept
{{< image alt="computer pixel art" src="computer.png" caption="Project \"logo\"" fit="400x400">}}

In the first post of this series, I showed a pixel-art computer. It's used as a logo for the project. 
I’m reusing it here as well, but this time I’m taking it a step further and turning the static image into an animation.

The idea is to simulate the startup of an old CRT monitor: first a dark screen, then a central flash. Additionally, a blinking LED on the case will indicate that something is happening in the background. The idea is simple, but the final effect should be pretty striking.

# Generating frames
To simplify Plymouth scripting, I'll prepare the animation in advance as a set of PNG frames. I’ll generate all frames up front: the ignition sequence and a short loop that plays until the system finishes booting.

## Animation as a code

Since I automate anything repetitive, generating the animation via code was the obvious approach.
First, I will prepare a few blank frames as a starting point.

```python
def save_frame(img, idx):
    img = img.resize((400, 400), Image.Resampling.LANCZOS)
    img.save(f"{OUTPUT_DIR}/frame_{idx}.png")

for _ in range(3):
    img = Image.new("RGBA", base.size, (14, 22, 36))
    save_frame(img, frame)
    frame += 1
```

### CRT illumination phase

{{< image_row caption="CRT illumination phase" >}}
    {{< image alt="CRT illumination phase 0" src="crt_1.png" fit="300x300">}}
    {{< image alt="CRT illumination phase 1" src="crt_2.png" fit="300x300">}}
{{< /image_row >}}

In the next few frames, I simulate the characteristic “lighting up” of the screen:

```python
    # --------------------
    # PHASE 2: CRT IGNITION
    # --------------------
    # Frame 4: monitor but dark screen
    img = base.copy()
    fill_screen(img, FLICKER_SCREEN_BOX, BLUE_DARK)
    save_frame(img, frame)
    frame += 1

    # Frame 5: small glow
    img = base.copy()
    fill_screen(img, FLICKER_SCREEN_BOX, BLUE_DARK)
    draw_center_glow(img, SCREEN_BOX, radius=6, color=BLUE_FLASH)
    apply_global_effects(img, frame)
    save_frame(img, frame)
    frame += 1

    # Frame 6: bigger glow
    img = base.copy()
    fill_screen(img, FLICKER_SCREEN_BOX, BLUE_DARK)
    draw_center_glow(img, SCREEN_BOX, radius=20, color=BLUE_FLASH)
    apply_global_effects(img, frame)
    save_frame(img, frame)
    frame += 1
```
### Flicker effect
{{< image_row caption="CRT stabilization phase" >}}
    {{< image alt="CRT stabilization phase 0" src="stabilization_1.png" fit="200x200">}}
    {{< image alt="CRT stabilization phase 1" src="stabilization_2.png" fit="200x200">}}
    {{< image alt="CRT stabilization phase 2" src="stabilization_3.png" fit="200x200">}}
{{< /image_row >}}

At the end of the sequence, I add brief flashes and a flicker effect before transitioning to the stabilized image.

```python
    # --------------------
    # PHASE 3: FULL LIGHT + FLICKER
    # --------------------
    # Frame 8 – bright fill
    img = base.copy()
    fill_screen(img, SCREEN_BOX, BLUE_FLASH)
    apply_global_effects(img, frame)
    save_frame(img, frame)
    frame += 1

    # Frame 9 – normal
    img = base.copy()
    fill_screen(img, SCREEN_BOX, BLUE_NORMAL)
    apply_global_effects(img, frame)
    save_frame(img, frame)
    frame += 1

    # # Frame 10 – flicker
    img = base.copy()
    fill_screen(img, SCREEN_BOX, BLUE_FLASH)
    apply_global_effects(img, frame)
    save_frame(img, frame)
    frame += 1
```

### Looping frames

Finally, I generate a set of frames that will loop until the system finishes booting.
```python
    # --------------------
    # PHASE 4: CURSOR LOOP (15 frames)
    # --------------------
    for i in range(15):
        img = base.copy()
        apply_global_effects(img, frame)
        save_frame(img, frame)
        frame += 1
```

The complete animation looks like this: 
{{< image alt="plymouth animation" src="animation.webp" caption="Splash screen animation">}}

The full script is available [here](https://gist.github.com/XertDev/e0c416a3faf8b0d1eb709ed9c1b515ed).

In the next post, I will show the Plymouth configuration for NixOS and how to combine these generated frames into a working splash screen. 


[^plymouth-docs]: [Plymouth readme](https://cgit.freedesktop.org/plymouth/tree/README)