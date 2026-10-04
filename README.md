<p align="center">
  <img src="assets/icon/icon_macos.png" width="128" alt="SVGA Gallery icon">
</p>

# SVGA Gallery

A gallery app for browsing and previewing [SVGA](https://github.com/svga) animations, built with Flutter.

## Features

- Grid of live, looping previews — only the tiles on screen are decoded and played, so large collections stay smooth
- Android: scans the whole device for `.svga` files (Android 10 and newer)
- Import from files, from a URL, or a built-in sample pack
- Player with play/pause, frame scrubber, frame stepping, loop, 0.5×/1×/2× speed, mute and five backgrounds
- Share a file, save a copy, and see its location, size, dimensions, frame rate and frame count
- Search, favorites, sorting and two tile sizes

## Download

Windows builds are attached to each [release](https://github.com/zamansheikh/svga-gallery/releases):

- `SVGA-Gallery-Setup-<version>.exe` — installer (Start menu and optional desktop shortcut, uninstaller)
- `SVGA-Gallery-windows-x64-portable.zip` — no install; unzip and run `svga_gallery.exe`

## Build from source

Requires Flutter 3.47 or newer.

```sh
flutter pub get
flutter run                      # on a connected device
flutter build apk --release      # Android
flutter build windows --release  # Windows (on a Windows machine)
flutter build macos --release    # macOS
```

## Notes

- Only SVGA 2.x files are supported; the older zip-based 1.x format is not.
- On Android 11 and newer the device scan needs the "All files access" permission, because `.svga` is not a media type.
- Playback uses [flutter_svga_easyplayer](https://pub.dev/packages/flutter_svga_easyplayer).

## Author

**Zaman Sheikh** — [GitHub](https://github.com/zamansheikh) · [Facebook](https://fb.com/zamansheikh.404)
