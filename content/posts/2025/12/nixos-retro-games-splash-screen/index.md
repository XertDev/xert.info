+++
date = '2025-12-09T00:13:46+01:00'
title = 'Nixos + Retro Games - Splash Screen pt.1'
[build]
    list='always'
    render = "always"
+++

Last time, I've already reached the greater stage. However, before working on launcher, I want to focus on a part that is the earliest - boot splash screen. 
I've tried to create a Plymouth configuration several times before, but something always stopped me. This time, I will not surrender :).

<!--more-->

# System splash screen

Typically, a Linux boot process appears as system logs and service startup messages scrolling by. 
It gives plain technical vibes, but for the average user, it can look confusing or intimidating.
Standard Debian or NixOS installations behave this way. Screens show textual info and then proceed to greeter.

Some distributions (more user-friendly), like Ubuntu, hide this process behing splash screen with the distribution logo.
This is exactly the effect I aim for. It will be consistent with the pixel theme that drives the whole project. 

# Plymouth
Plymouth is used to display the splash screen. It consists of two executables[^plymouth-docs]:
* plymouthd - process which is responsible for rendering the animation,
* plymouth - tool controlling the plymouthd state.

There are many publicly available themes. If someone does not want to create something from scratch, they can use pre-made themes from sites like [gnome-look.org](https://www.gnome-look.org/browse?cat=108&ord=latest).
I want a custom theme, which will blend with the artistic vision of the system. Therefore, I will create the animation from scratch.

# Animation concept
{{< image alt="computer pixel art" src="computer.png" caption="Project \"logo\"" fit="400x400">}}

In the first post of this series, I've showed an image with pixel arto of a computer. It's used as a logo for the whole project. 
I will also use it here.  I will use it here as well. However, I will go a little crazy and turn this static image into a simple animation.

The goal is to simulate the startup of an old CRT monitor: first a dark screen, then a central flash. Additionally, blinking LED on the case will indicate that something is happening in the background. The plan is simple, but the overall effect should be quite impressive. I.

# Generating frames
To simplify Plymouth scripting, I will prepare the animation in advance as a set of PNG frames. I will create both the monitor ignition sequence and a series of frames intended for looping till booting is completed.

## Animation as a code

In line with my approach to repetitive work, it was immediately obvious that I would also write the animation as code.
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

Finally, I prepare a bunch of frames that will loop until the boot process is complete.
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

The full code can be found [here](./snippet).

In the next post, I will show the Plymouth configuration for NixOS and how to combine these generated frames into a working splash screen. 


[^plymouth-docs]: [Plymouth readme](https://cgit.freedesktop.org/plymouth/tree/README)