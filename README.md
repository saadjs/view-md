# ViewMD

ViewMD is a native macOS Markdown preview scaffold. It contains a minimal SwiftUI app and a Quick Look preview extension for Finder spacebar previews.

## Development

Generate the Xcode project:

```sh
xcodegen generate
```

Build and test:

```sh
xcodebuild -scheme ViewMD -destination 'platform=macOS' build test
```
