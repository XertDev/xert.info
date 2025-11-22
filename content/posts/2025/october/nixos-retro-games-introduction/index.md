+++
date = '2025-10-29T21:01:31+01:00'
draft = false
title = 'NixOS + Retro Games - Introduction'
tags = ["retro", "nixos", "games", "homelab"]
summary ="This is the first post on this blog and also the first post of a series where I'll try to develop a NixOs-based distribution packed with all the goodies required to play some older games on TV without any hassle."
+++

## Introduction
This is the first post on this blog and also the first post of a series where I'll try to develop a NixOs-based distribution packed with all the goodies required to play some older games on TV without any hassle.

Let me start with a few words about myself. I'm a software developer who began his career as a C++ GUI programmer.
Over time, I moved toward more architectural/infrastructural work. My toolset also evolved. I became familiar with Kubernetes, Helm and Terraform.


I'm rather a guy which instead of doing something in 10 minutes, spends 2 days to make task fully automated.

## Starting with NixOs

Some time ago, I discovered Nix thanks to a colleague from my CTF Team, who used it to set up VMs for competition challenges. I started using it in more and more projects. Firstly, used it as a tool to build programs for my Master's thesis, then at work to create predefined environments so that the new team members didn't have to install every library or tool manually.

My biggest NixOs project was inspired by my another colleague, who told me about his homelab setup (a simple Home Assistant setup on an old thin client). To be honest, it triggered my ambitions.

## Homelab adventure

I built a tool in Rust to simplify NixOs deployments, then started collecting random hardware parts and gluing them together to create my own setup.

My main goal was: **everything must be easily repairable**. No manual configuration, no random scripts. Everything is version-controlled in a single repository. If something breaks, I can just buy a replacement, put a USB stick with preconfigured iso, and the system should be redy to work.

{{< image alt="homelab in 3d printed rack" src="homelab.jpg" caption="My 3D-printed mini rack - the core of my homelab setup." fit="256x400" >}}

Well, It takes more time to configure, but now I no longer fear that some drive will fail, or I will accidentally delete something.
And yes, in the early days it broke a lot. But switching to the latest working version becomes easy, just selecting the last working version from a GRUB menu. 

## Project goal
There are already some distributions that simplify playing retro games, for example, RetroPie[^retropie], which is very popular on Raspberry Pi devices and makes DIY console projects accessible even to non-technical users.
{{< image alt="system launcher project mockup" src="retro_launcher.png" caption="Early mockup of the system menu – simple, pixel-style interface for launching retro games." fit="400x600" >}}

However, I haven't seen anything similar based on NixOs. That's why I decided to create a configurable NixOs module which automates the whole setup process and integrates nicely with my existing homelab orchestration system.

The whole solution will be based on the same idea that I use in other systems. I don't want to do anything on the target machine manually. Every configuration/action should be done by invoking a deployment script for NixOs System.

Let's see where this plan will take us...

[^retropie]: RetroPie officiel website https://retropie.org.uk/