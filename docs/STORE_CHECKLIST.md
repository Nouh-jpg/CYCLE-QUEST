# Store readiness checklist (this pass)

Cycle Quest is a Godot 4 project. This is **not** store approval.

**Ship targets right now: Steam (Windows) and Google Play (Android).** App Store and Nintendo Switch are not part of this pass — do not cut iOS or Switch builds, capsules, or export presets for it.

`export_presets.cfg` is in the repo as two unsigned stubs (Windows x86_64, Android arm64 AAB). No keystore, Steam depot, or SDK path. Keystores (`*.keystore`, `*.jks`) stay gitignored. `tests/*` is excluded from the package. Gameplay still outranks packaging.

## Shared
- [ ] App icon (1024² master, then Windows .ico and Android launcher sizes)
- [ ] Privacy policy URL if the build has ads, analytics, or accounts (this build has none)
- [ ] Age rating questionnaire (IARC on Play, Steam survey)
- [ ] Capture set: chaser close-up with the danger vignette, a magenta gate with the slide chevrons, a boost with the wide FOV and **AWAY!** popup

## Windows (Steam)
- [ ] Export preset "Windows Desktop" — x86_64, embed pck, S3TC/BPTC
- [ ] Steamworks app ID and a depot when the store page exists (not wired yet)
- [ ] Keyboard and gamepad pass. On-screen pads stay hidden unless the device is touch or `cycle_quest/always_show_touch_controls` is turned on
- [ ] Store page: wishlist capsule, short trailer. Cut on the chase, the slide, and the boost escape

## Android (Google Play)
- [ ] Export preset "Android" — arm64-v8a only, AAB (`gradle_build/export_format=1`), unsigned
- [ ] Replace the placeholder package id `com.cyclequest.game` before upload
- [ ] Play App Signing, target API, data safety, content rating
- [ ] Device pass: touch SLIDE clears a magenta gate, JUMP clears a red block, boost pulls the chaser back

## Not this pass
- iOS / App Store
- Nintendo Switch

## Smoke
- [ ] `godot --headless --path . -s res://tests/smoke_chaser_slide.gd`
