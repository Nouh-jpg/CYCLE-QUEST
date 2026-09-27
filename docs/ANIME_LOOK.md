# Cycle Quest — Anime / Cel-Shaded Look Reference

Visual overhaul from greybox to vibrant cartoon anime (cel-shaded) style for Godot 4.3 Forward+.

## Shaders

### Toon / cel (`res://shaders/toon.gdshader`)

Custom light-pass shader with hard shade bands, optional highlight band, fresnel rim, and emission.

Key uniforms:

| Uniform | Role | Typical |
|---|---|---|
| `albedo` | Base flat color (`source_color` (Godot 4; formerly hint_source_color)) | palette color |
| `shade_color` | Multiply tint in shadow band | deep purple `(0.35, 0.28, 0.55)` |
| `shade_threshold` | N·L edge for shade band | `0.45` |
| `shade_softness` | Band edge soft width | `0.04` |
| `highlight_threshold` / `highlight_mix` | Second bright band | `0.85` / `0.25` |
| `rim_amount` / `rim_threshold` / `rim_color` | View fresnel rim | `0.4` / `0.55` / cool white |
| `emission_color` / `emission_strength` | Self-glow (coins, neon) | color / `0–2.5` |

Full source lives at `shaders/toon.gdshader`. Materials are built at runtime by `StyleKit.make_toon()` so every mesh gets consistent bands + outline.

### Outline method (chosen)

**Inverted-hull outline via `next_pass`** on the toon `ShaderMaterial`.

- Shader: `res://shaders/outline.gdshader`
- Shared resource: `res://materials/outline.tres`
- Technique: `cull_front` + expand `VERTEX += NORMAL * outline_width` in the vertex stage; draws only backfaces as a fat silhouette.
- Applied by setting `ShaderMaterial.next_pass = outline_material` inside `StyleKit.make_toon()` when `outline_width > 0`.
- Alternative considered (not used): duplicate mesh with a second MeshInstance3D. `next_pass` keeps one mesh, lower draw overhead for this mobile-bound runner.

Outline defaults: color `(0.08, 0.04, 0.16)`, width `0.035` (tweak per mesh size).

## WorldEnvironment (Main)

Set on `scenes/Main.tscn` → `WorldEnvironment` / sub-resource `Environment_Main`:

| Setting | Value |
|---|---|
| Background | Sky (`background_mode = 2`) with `ProceduralSkyMaterial` |
| Sky top | `(0.35, 0.45, 1.0)` |
| Sky horizon | `(1.0, 0.55, 0.85)` |
| Ground bottom / horizon | purple `(0.45, 0.2, 0.75)` / `(0.85, 0.45, 0.95)` |
| Ambient | Custom color `(0.95, 0.75, 1.0)`, energy `0.95` |
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
