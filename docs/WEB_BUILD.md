# Web build

The Web build is a reduced build of the desktop game. The "Web" export preset and the CI build set it up, but it has not been run in a browser yet.

## How it differs

- **Renderer:** `project.godot` sets `renderer/rendering_method.web` to Compatibility. Desktop stays on Forward+.
- **Threads:** the preset turns thread support off, so the page needs no cross-origin isolation headers. `GrassField` grows its cells on the main thread when `OS.has_feature("web")`, because worker thread tasks can't be relied on there.
- **Extensions:** the project uses no GDExtension.

## Features to check in Compatibility

These come from reading the code and shaders. Nobody has looked at them in a browser yet.

- Screen-space ambient occlusion (`Settings.ambient_occlusion()`) is ignored.
- `scaling_3d_scale` (the graphics quality render scale) is not supported, so the quality levels would only change shadows.
- The water shader reads the depth texture, and the terrain and surface shaders use `textureGrad` and `textureLod`. All should work, but need a visual check.
- Fog, the procedural sky, and the day/night lighting need a visual check.
- Saves and settings go to `user://`, which is browser storage on Web.

## Building

Install the Web export templates, then run:

```
godot --headless --path . --export-release "Web" build/web/index.html
```

Serve `build/web` over HTTP to try it. The `Test and build` workflow does this and uploads the result as `erlenfall-web`.
