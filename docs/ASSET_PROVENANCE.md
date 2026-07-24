# Demo asset provenance

The Coastal Keepers artwork and Gouache brush swatch in
`Sources/MacOSPaintApp/Resources` are original demonstration fixtures created
for MacOSPaint with OpenAI's built-in image generation tools. They do not use
third-party logos or source artwork.

- `AppIcon.png` is the 1024×1024 sRGB master for the original Crop Window
  mark in graphite, ivory, coral, and teal. `AppIcon.icns` is the mechanically
  generated multi-resolution macOS icon container.
- `coastal-landscape.png`, `coastal-square.png`, and `coastal-story.png` are
  the three campaign artboard previews.
- `coastal-square-footer.png` is a project-specific edit of the square preview
  that adds the campaign badge and footer shown in the selected visual target.
- `coastal-square-final.png` adds the target's coral dry-brush underline while
  preserving the badge and footer.
- `gouache-swatch.png` is an isolated generated dry-gouache stroke with a
  locally removed chroma-key background.

These files are distributed under the repository's MIT License. The campaign
art and swatch are demo content; none of the generated assets are part of the
public `.macospaint` compatibility schema.
