# Dead Zone: Survival

A lightweight, fully offline 3D survival prototype for Android, built with Godot 4 and procedural low-poly assets.

## Current playable systems
- First-person movement and touch look controls
- Procedural low-poly forest and abandoned outpost
- Mutant enemies with chase and attack behavior
- Rifle firing, ammo, hit detection and enemy drops
- Resource pickups, inventory, medkits and basic crafting
- Local save/load; pause/close attempts to save
- Android-friendly GL Compatibility renderer and no network permissions

## Controls
- Touch: drag on the left side to move, drag on the right side to look
- FIRE: shoot; USE: collect nearby resources
- BAG: inventory; CRAFT: craft a medkit; MEDKIT: heal; SAVE: save locally
- Desktop testing: WASD, mouse look (right-click to capture), F shoot, E collect, I inventory, C craft, H heal, F5 save, Shift sprint

## Build
Push to the main branch or manually run Actions → Android APK. The workflow validates the project, exports an ARM64 Android APK, tests the APK ZIP archive, and uploads the artifact only after every validation step passes.

This is an early playable prototype, not a finished commercial game. Visuals are generated from primitives to keep the build small; more detailed models, sound, animation, and device testing remain future work.
