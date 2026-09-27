# Store readiness checklist (brief)

Cycle Quest is a Godot 4 project. This is **not** store approval — just realistic next steps before shipping.

## All platforms
- [ ] App icon set (1024² master + platform sizes)
- [ ] Splash / launch image
- [ ] Privacy policy URL (ads, analytics, or account = required)
- [ ] Age rating questionnaire (ESRB / IARC / PEGI)
- [ ] Remove debug UI; confirm pause + game-over + restart
- [ ] Touch + gamepad + keyboard smoke-tested on device

## Android (Play Store)
- [ ] Export preset: Android, arm64-v8a
- [ ] Package name, version code/name
- [ ] Signed release AAB (Play App Signing)
- [ ] Target API per current Play requirements
- [ ] Data safety form + content rating

## iOS (App Store)
- [ ] Export preset: iOS (macOS + Xcode required)
- [ ] Bundle ID, signing team, capabilities
- [ ] Privacy Nutrition Labels; ATT only if tracking
- [ ] TestFlight build before review

## Steam
- [ ] Export presets: Windows / macOS / Linux
- [ ] Steamworks app ID, depot, achievements (optional)
- [ ] Controller config + Big Picture smoke test
- [ ] Store page: capsules, trailers, build branches

## Nintendo Switch
- [ ] Requires Nintendo developer license / NDAs
- [ ] Official Switch export needs Nintendo-approved Godot / middleware builds — not the public editor alone
- [ ] Plan partner support early; do not claim Switch-ready without that pipeline

## Godot export hygiene
- [ ] Project → Export: fill presets; enable only needed features
- [ ] Strip unused languages/assets; measure install size
- [ ] Headless smoke: `godot --path . --quit-after 2 res://scenes/Main.tscn`
