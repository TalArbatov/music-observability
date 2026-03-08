#!/usr/bin/env bash
set -euo pipefail
umask 022
export PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/bin

LIBRARY_ROOT="${LIBRARY_ROOT:-/mnt/hd/music}"
EXPECTED_MOUNT="${EXPECTED_MOUNT:-/mnt/hd}"
OUT_DIR="${OUT_DIR:-/home/pio/services/media-stack/node_exporter/textfile_collector}"
mkdir -p "$OUT_DIR"
OUT_FILE="${OUT_DIR}/music_library.prom"
TMP_FILE="$(mktemp "${OUT_DIR}/music_library.prom.XXXXXX")"

emit_fail_minimal() {
  cat > "$TMP_FILE" <<METRICS
# HELP music_library_mount_ok Whether the expected music filesystem mount is present.
# TYPE music_library_mount_ok gauge
music_library_mount_ok 0

# HELP music_library_scan_success Whether the music library scan succeeded.
# TYPE music_library_scan_success gauge
music_library_scan_success 0

# HELP music_library_last_scan_timestamp Unix timestamp of the last scan attempt.
# TYPE music_library_last_scan_timestamp gauge
music_library_last_scan_timestamp $(date +%s)
METRICS
  chmod 0644 "$TMP_FILE"
  mv "$TMP_FILE" "$OUT_FILE"
}

if [ ! -d "$LIBRARY_ROOT" ]; then
  emit_fail_minimal
  exit 0
fi

actual_mount="$(findmnt -T "$LIBRARY_ROOT" -no TARGET 2>/dev/null || true)"
if [ -z "$actual_mount" ] || [ "$actual_mount" != "$EXPECTED_MOUNT" ]; then
  emit_fail_minimal
  exit 0
fi

library_bytes="$(du -sb -- "$LIBRARY_ROOT" | awk '{print $1}')"
tracks_total="$(find "$LIBRARY_ROOT" -type f \( \
  -iname '*.flac' -o \
  -iname '*.mp3'  -o \
  -iname '*.wav'  -o \
  -iname '*.m4a'  -o \
  -iname '*.ogg'  -o \
  -iname '*.opus' \
\) | wc -l)"

album_dirs_total="$(find "$LIBRARY_ROOT" -type f \( \
  -iname '*.flac' -o \
  -iname '*.mp3'  -o \
  -iname '*.wav'  -o \
  -iname '*.m4a'  -o \
  -iname '*.ogg'  -o \
  -iname '*.opus' \
\) -printf '%h\n' | sort -u | wc -l)"

flac_total="$(find "$LIBRARY_ROOT" -type f -iname '*.flac' | wc -l)"
mp3_total="$(find "$LIBRARY_ROOT" -type f -iname '*.mp3' | wc -l)"
wav_total="$(find "$LIBRARY_ROOT" -type f -iname '*.wav' | wc -l)"
m4a_total="$(find "$LIBRARY_ROOT" -type f -iname '*.m4a' | wc -l)"
ogg_total="$(find "$LIBRARY_ROOT" -type f -iname '*.ogg' | wc -l)"
opus_total="$(find "$LIBRARY_ROOT" -type f -iname '*.opus' | wc -l)"

cat > "$TMP_FILE" <<METRICS
# HELP music_library_mount_ok Whether the expected music filesystem mount is present.
# TYPE music_library_mount_ok gauge
music_library_mount_ok 1

# HELP music_library_scan_success Whether the music library scan succeeded.
# TYPE music_library_scan_success gauge
music_library_scan_success 1

# HELP music_library_bytes Total size of the music library directory in bytes.
# TYPE music_library_bytes gauge
music_library_bytes ${library_bytes}

# HELP music_library_tracks_total Total number of supported audio files in the library.
# TYPE music_library_tracks_total gauge
music_library_tracks_total ${tracks_total}

# HELP music_library_album_dirs_total Total number of directories that directly contain audio files.
# TYPE music_library_album_dirs_total gauge
music_library_album_dirs_total ${album_dirs_total}

# HELP music_library_tracks_by_format_total Total number of tracks by file format.
# TYPE music_library_tracks_by_format_total gauge
music_library_tracks_by_format_total{format="flac"} ${flac_total}
music_library_tracks_by_format_total{format="mp3"} ${mp3_total}
music_library_tracks_by_format_total{format="wav"} ${wav_total}
music_library_tracks_by_format_total{format="m4a"} ${m4a_total}
music_library_tracks_by_format_total{format="ogg"} ${ogg_total}
music_library_tracks_by_format_total{format="opus"} ${opus_total}

# HELP music_library_last_scan_timestamp Unix timestamp of the last successful scan.
# TYPE music_library_last_scan_timestamp gauge
music_library_last_scan_timestamp $(date +%s)
METRICS
  chmod 0644 "$TMP_FILE"


  mv "$TMP_FILE" "$OUT_FILE"
