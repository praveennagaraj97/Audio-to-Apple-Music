#!/bin/zsh
set -euo pipefail
here=${0:A:h}
archive="$here/ffmpeg-9.0.2.tar.xz"
stage="$here/ffmpeg-stage"
installRoot=$(/usr/bin/mktemp -d /tmp/audio-to-apple-music-ffmpeg.XXXXXX)
sourceRoot=$(/usr/bin/mktemp -d /tmp/audio-to-apple-music-source.XXXXXX)
trap 'rm -rf "$installRoot" "$sourceRoot"' EXIT

tar -xf "$archive" -C "$sourceRoot"
source="$sourceRoot/ffmpeg-9.0.2"
cd "$source"
./configure \
  --prefix="$installRoot" \
  --arch=arm64 --target-os=darwin --cc=clang \
  --enable-static --disable-shared --disable-doc --disable-debug \
  --disable-ffplay --disable-network --disable-autodetect --disable-everything \
  --enable-zlib \
  --enable-ffmpeg --enable-ffprobe --enable-protocol=file \
  --enable-demuxer=flac --enable-demuxer=wav --enable-demuxer=aiff \
  --enable-demuxer=mp3 --enable-demuxer=aac --enable-demuxer=mov \
  --enable-muxer=ipod --enable-muxer=image2 \
  --enable-decoder=flac --enable-decoder=mp3float --enable-decoder=mp3 \
  --enable-decoder=aac --enable-decoder=alac \
  --enable-decoder=pcm_s8 --enable-decoder=pcm_u8 \
  --enable-decoder=pcm_s16le --enable-decoder=pcm_s16be \
  --enable-decoder=pcm_s24le --enable-decoder=pcm_s24be \
  --enable-decoder=pcm_s32le --enable-decoder=pcm_s32be \
  --enable-decoder=pcm_f32le --enable-decoder=pcm_f32be \
  --enable-decoder=pcm_f64le --enable-decoder=pcm_f64be \
  --enable-decoder=pcm_alaw --enable-decoder=pcm_mulaw \
  --enable-decoder=png --enable-decoder=mjpeg --enable-decoder=webp --enable-decoder=bmp \
  --enable-encoder=alac --enable-encoder=mjpeg \
  --enable-parser=flac --enable-parser=mpegaudio --enable-parser=aac \
  --enable-filter=anull --enable-filter=aresample \
  --enable-avformat --enable-avcodec --enable-swresample --enable-avfilter --enable-swscale

make -j"$(sysctl -n hw.ncpu)" ffmpeg ffprobe
make install
mkdir -p "$stage/bin"
cp "$installRoot/bin/ffmpeg" "$installRoot/bin/ffprobe" "$stage/bin/"
chmod 755 "$stage/bin/ffmpeg" "$stage/bin/ffprobe"
printf 'Bundled FFmpeg tools installed to %s\n' "$stage/bin"
