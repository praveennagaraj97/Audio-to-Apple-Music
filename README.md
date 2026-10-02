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

Build products and extracted FFmpeg sources are generated locally and are excluded from Git. The FFmpeg LGPL license and exact source archive are included in this repository and in the app bundle.

## Use

Choose audio files or folders, then click **Convert & Add to Music**. The app shows a result card for each track with its available metadata, artwork, conversion status, and import status. Original files are kept in place. A converted `.m4a` is removed after Music confirms it copied the file; it is retained in the app's Recovery folder when Music uses that file or cannot confirm its library location, and after a failure.

On first import, macOS may ask you to allow the app to control Music. Approve that request to add tracks.
