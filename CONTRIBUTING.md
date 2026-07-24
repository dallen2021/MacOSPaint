# Contributing to MacOSPaint

Thank you for helping build a friendly, capable image editor for macOS.

## Development setup

1. Use an Apple-silicon Mac running macOS 26 or later.
2. Install and select Xcode 26.x.
3. Clone the repository.
4. Run `./Scripts/test.sh`.
5. Open `MacOSPaint.xcodeproj`, or run `swift run MacOSPaint` for the
   command-line-toolchain workflow.

## Pull requests

- Start from a focused issue or discussion.
- Keep unrelated changes in separate pull requests.
- Add or update tests for model, renderer, persistence, and interaction changes.
- Include before/after captures for visible UI changes in both appearances.
- Verify keyboard access, VoiceOver labels, and reduced-transparency behavior.
- Update the changelog for user-facing changes.

By contributing, you agree that your contribution is licensed under the
project's MIT License. The project does not require a contributor license
agreement.

## Style

- Use Swift 6 concurrency checking.
- Keep UI state on the main actor.
- Send immutable snapshots across renderer and persistence boundaries.
- Keep platform frameworks out of `PaintModel` where practical.
- Prefer focused types and protocol seams over global state.
