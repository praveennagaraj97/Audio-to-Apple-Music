# Audio to Apple Music

A small macOS app that converts local audio files to Apple Lossless (ALAC) and adds them to the Music library. It works with a local library and does not require an Apple Music subscription.

## Supported input

- FLAC
- WAV
- AIFF
- MP3
- AAC and M4A

The app scans selected folders recursively and skips unsupported files. MP3 and AAC are lossy formats; converting them to ALAC does not restore audio quality lost during encoding.

## Build and install

Requirements: macOS 14 or later, Apple Music, Xcode command-line tools, and the included FFmpeg 9.0.2 source archive.

1. Run **Build Bundled FFmpeg.command**. It compiles the included FFmpeg source with only the decoders, artwork formats, and ALAC encoder used by this app.
2. Run **Build Audio to Apple Music.command**. The script builds the app, adds the bundled FFmpeg tools and app icon, signs the local bundle, and creates `Audio to Apple Music.pkg`.
3. Open the generated package and follow the Installer prompts.

## GitHub releases

Releases are built automatically on GitHub Actions when a semantic version tag is pushed. The workflow compiles the bundled FFmpeg tools on a macOS runner, builds the versioned app and installer package, calculates a SHA-256 checksum, and attaches both files to a GitHub Release.

To publish a release, push a tag such as `v2.1.0`:

```sh
git tag -a v2.1.0 -m "Audio to Apple Music 2.1.0"
git push origin v2.1.0
```

The workflow creates the GitHub Release and uploads `Audio to Apple Music.pkg` and its `.sha256` checksum. You can follow progress in the repository's Actions tab.

Build products and extracted FFmpeg sources are generated locally and are excluded from Git. The FFmpeg LGPL license and exact source archive are included in this repository and in the app bundle.

## Use

Choose supported audio files, folders, or both with **Choose Files or Folder…**. Folder scans include nested folders. Click **Clear** to remove the selection and clear the conversion results. Click **Convert & Add to Music** to process the selection. The app shows a result card for each track with its available metadata, artwork, conversion status, and import status. Original files are kept in place. A converted `.m4a` is removed after Music confirms it copied the file; it is retained in the app's Recovery folder when Music uses that file or cannot confirm its library location, and after a failure.

On first import, macOS may ask you to allow the app to control Music. Approve that request to add tracks.
