# Cycle Quest — Anime / Cel-Shaded Look Reference

Visual overhaul from greybox to vibrant cartoon anime style for Godot 4.3–4.7 Forward+.

> **2026-09 hotfix:** Custom `light()` toon shaders that read `NORMAL`/`VIEW` can fail to
> compile on some Godot 4.5–4.7 Forward+ builds (magenta/pink materials → “pink screen”).
> `StyleKit` now builds **`StandardMaterial3D`** with vivid albedo + emission + inverted-hull
> outline `next_pass`. The fragment-only `shaders/toon.gdshader` remains as an optional
> reference but is **not** used at runtime.

## Materials (runtime)

`StyleKit.make_toon()` / `apply_to_mesh()` return a `StandardMaterial3D`:

| Property | Role |
|---|---|
| `albedo_color` | Base flat / vibrant color from `PALETTE` |
| `emission` + `emission_energy_multiplier` | Neon pop (coins, boosts, hair, bike accents) + mild `base_glow` so meshes never go black |
| `roughness` / `metallic` | Soft non-metal look (defaults ~0.72 / 0.0) |
| `next_pass` | Inverted-hull outline (`shaders/outline.gdshader`) when `outline_width > 0` |

API-compatible opts still accepted (`rim_amount`, `shade_color`, `highlight_*`) but ignored;
call sites do not need changes.

### Outline method

**Inverted-hull via `next_pass`** — unshaded, `cull_front`, `VERTEX += NORMAL * outline_width`.
Safe on Forward+ (no custom `light()`).

## Optional shader reference

`shaders/toon.gdshader` is now **fragment-only / unshaded** (fake light_dir bands + rim).
Do not reintroduce a custom `light()` path without verifying Forward+ on the target Godot version.

## WorldEnvironment (Main)


Set on `scenes/Main.tscn` → `WorldEnvironment` / sub-resource `Environment_Main`:

| Setting | Value |
|---|---|
| Background | Sky (`background_mode = 2`) with `ProceduralSkyMaterial` |
| Sky top | `(0.35, 0.45, 1.0)` |
| Sky horizon | `(0.7, 0.65, 1.0)` lavender (was hot pink) |
| Ground bottom / horizon | purple `(0.45, 0.2, 0.75)` / `(0.55, 0.4, 0.85)` |
| Ambient | Custom color `(0.85, 0.8, 1.0)`, energy `0.95` |
| Tonemap | **ACES** (`tonemap_mode = 3`), exposure `1.05` |
| SSAO | **on** — radius `1.4`, intensity `1.6`, power `1.5`, detail `0.5`, horizon `0.06`, sharpness `0.85` |
| Glow / bloom | **on** — intensity `1.35`, strength `1.1`, bloom `0.65`, HDR threshold `0.75`, HDR scale `2.0`, luminance cap `12`, normalized |
| Color adjustment | **on** — brightness `1.05`, contrast `1.08`, **saturation `1.4`** |
| Key light | warm DirectionalLight3D color `(1, 0.92, 0.78)`, energy `1.35`, shadows on |
| Fill light | cool purple `(0.65, 0.55, 1)`, energy `0.35`, no shadows |
| Fluffy clouds | `AnimeSkyDecor` — oversized soft sphere puffs that recycle ahead of the player |

### Project MSAA

In `project.godot` → `[rendering]`:

- `anti_aliasing/quality/msaa_3d=2` (2× MSAA)
- `anti_aliasing/quality/screen_space_aa=1` (FXAA)

## Palette (how to tweak)

Central dictionary: `StyleKit.PALETTE` in `scripts/StyleKit.gd`.

Change a color there (e.g. `"maya_hair"`, `"road"`, `"coin"`) and every new material built through `StyleKit.apply_to_mesh()` / `make_toon()` picks it up on next run.

For a single mesh at runtime:

```gdscript
StyleKit.apply_to_mesh(mesh_instance, Color(1.0, 0.3, 0.9), {
    "outline_width": 0.04,
    "emission_strength": 0.8,
    "emission_color": Color(1.0, 0.3, 0.9),
    "rim_amount": 0.5,
})
```

Pass `"outline_width": 0.0` to skip the hull pass (eyes, neon strips).

Vibrant rules used: neons, deep purples, vivid greens/cyans/pinks — no muddy grey/brown road or props.

## What uses the look

| Subject | Where |
|---|---|
| Player (Maya/Jax body, eyes, hair, bike) | `scripts/Player.gd` builds primitive hierarchy |
| Chaser | `scripts/Chaser.gd` body + horns + glow eyes |
| Road + stripes + neon edges + anime props | `scripts/RoadSegment.gd` |
| Coins / boosts / obstacles | respective scripts apply toon + emission |
| Particles | Player: speed lines, lane dust, coin sparkle; squash/stretch on land & boost |

## Performance notes

- Primitive meshes + low particle counts (18–28)
- Outline via `next_pass` (no mesh duplication)
- Cloud count capped (~10), recycled by Z
- Suitable for mobile-bound infinite runner; reduce `cloud_count` / particle `amount` if needed
