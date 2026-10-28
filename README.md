# Dead Zone: Survival

A fully offline low-poly 3D survival prototype for Android, built with Godot 4. The environment is generated procedurally so the first build stays compact and does not need a network connection.

## Gameplay in this prototype
- First-person movement and touch look controls
- Procedural pine forest, fog, an abandoned checkpoint and salvage yard
- Mutants that approach the player; use sprint and dash to escape
- Resource pickups: wood, stone, scrap and food
- Inventory, food healing, medkits and a simple crafting recipe
- Local save/load stored on the device
- Mobile GL Compatibility renderer; no internet permission

## Controls
- Touch: drag on the left side to move; drag on the right side to look
- DASH: quick escape; COLLECT: pick up nearby supplies
- BAG: inventory; CRAFT: create a medkit; EAT: restore health; SAVE: save locally
- Desktop: WASD, mouse look (right-click to capture), E collect, I inventory, C craft, H eat/use medkit, F5 save, Shift dash

## Build
Push to the main branch or manually run Actions → Android APK. The workflow checks script parsing and runtime startup, exports an ARM64 Android APK, validates the archive, and uploads the APK only if all checks pass.

This is an early playable prototype, not a finished commercial game. Models are procedural primitives; detailed character animation, sound, additional locations, and real-device performance testing remain future work.
