#!/bin/bash
# Recursively transcode video files to HEVC (H.265) in-place, using
# macOS VideoToolbox hardware acceleration. Originals are replaced only
# after the transcoded output passes validation.
#
# Usage:
#   ./transcode-media.sh [root_dir]
#
# Env vars:
#   DRY_RUN=1     List actions without transcoding
#   QUALITY=65    VideoToolbox quality (0-100; higher = better, larger)
#   LOGFILE=...   Path to log file (default: ~/transcode-media.log)
#   MIN_FREE_GB=5 Minimum free GB to keep on the volume (script skips below this)
#   JOBS=1        Number of files to transcode in parallel (1 = sequential)
#   FAST=1        Enable hardware decode + realtime encode + no B-frames.
#                 Faster (~20-40% on heavy sources) with a small quality cost
#                 and ~5-10% larger files at the same -q:v.

set -uo pipefail

ROOT="${1:-/Volumes/nulcell/media-server-data}"
DRY_RUN="${DRY_RUN:-0}"
QUALITY="${QUALITY:-65}"
LOGFILE="${LOGFILE:-$HOME/transcode-media.log}"
MIN_FREE_GB="${MIN_FREE_GB:-5}"
JOBS="${JOBS:-1}"
FAST="${FAST:-0}"

start_ts=$(date +%s)
STATS_FILE=$(mktemp -t transcode-stats.XXXXXX)

# ffmpeg progress lines interleave when running in parallel; only show them in serial mode
FFMPEG_STATS="-stats"
(( JOBS > 1 )) && FFMPEG_STATS="-nostats"

# FAST=1: -hwaccel gives GPU decode (frames are auto-downloaded to CPU after decode;
# pinning them on GPU with -hwaccel_output_format requires an hwdownload filter chain
# and didn't pan out — the CPU round-trip is cheap on Apple Silicon). -realtime hints
# the encoder to prioritize throughput, -bf 0 skips B-frame analysis.
HWACCEL_ARGS=()
FAST_ENCODER_ARGS=()
if [[ "$FAST" == "1" ]]; then
  HWACCEL_ARGS=(-hwaccel videotoolbox)
  FAST_ENCODER_ARGS=(-realtime true -bf 0)
fi

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOGFILE"; }

human() {
  local b=$1
  if   (( b >= 1073741824 )); then printf '%.2f GB' "$(echo "$b / 1073741824" | bc -l)"
  elif (( b >= 1048576 ));    then printf '%.2f MB' "$(echo "$b / 1048576" | bc -l)"
  elif (( b >= 1024 ));       then printf '%.2f KB' "$(echo "$b / 1024" | bc -l)"
  else                             printf '%d B' "$b"
  fi
}

on_interrupt() {
  log "INTERRUPTED — waiting for in-flight workers to exit"
  wait
  # ffmpeg children clean their own temps on the FAIL branch, but if a worker
  # was killed mid-encode, scoop up anything they left behind.
  local leftover
  leftover=$(find "$ROOT" -type f -name '*.transcoding.mkv' 2>/dev/null)
  if [[ -n "$leftover" ]]; then
    log "removing leftover temp files:"
    while IFS= read -r f; do
      log "  $f"
      rm -f "$f"
    done <<< "$leftover"
  fi
  exit 130
}

on_exit() {
  local processed=0 skipped=0 failed=0 bytes_before=0 bytes_after=0
  local kind a b
  if [[ -f "$STATS_FILE" ]]; then
    while read -r kind a b; do
      case "$kind" in
        ok)   processed=$((processed+1)); bytes_before=$((bytes_before+a)); bytes_after=$((bytes_after+b)) ;;
        skip) skipped=$((skipped+1)) ;;
        fail) failed=$((failed+1)) ;;
      esac
    done < "$STATS_FILE"
    rm -f "$STATS_FILE"
  fi
  local elapsed=$(( $(date +%s) - start_ts ))
  local saved=$(( bytes_before - bytes_after ))
  log "=== summary === processed=$processed skipped=$skipped failed=$failed saved=$(human "$saved") elapsed=${elapsed}s"
}

trap on_interrupt INT TERM
trap on_exit EXIT

command -v ffmpeg  >/dev/null || { echo "ffmpeg not installed"  >&2; exit 1; }
command -v ffprobe >/dev/null || { echo "ffprobe not installed" >&2; exit 1; }
[[ -d "$ROOT" ]] || { echo "directory not found: $ROOT" >&2; exit 1; }

process_file() {
  local file="$1"
  local base codec pix_fmt size_before avail_bytes min_free_bytes
  local profile_args bit_label dir stem tmp final out_codec size_after pct

  base=$(basename "$file")

  [[ "$base" == *.transcoding.mkv ]] && return 0
  [[ "$base" == ._* ]] && return 0
  [[ "$base" == .DS_Store ]] && return 0

  codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name \
            -of default=nw=1:nk=1 "$file" 2>/dev/null || true)
  if [[ -z "$codec" ]]; then
    log "SKIP no video stream: $file"
    echo "skip" >> "$STATS_FILE"
    return 0
  fi
  case "$codec" in
    hevc|h265|av1|vp9|vvc|h266)
      log "SKIP already efficient ($codec): $file"
      echo "skip" >> "$STATS_FILE"
      return 0
      ;;
  esac

  pix_fmt=$(ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt \
              -of default=nw=1:nk=1 "$file" 2>/dev/null || true)
  if [[ "$pix_fmt" == *10le* || "$pix_fmt" == *10be* || "$pix_fmt" == p010* || "$pix_fmt" == yuv420p10* ]]; then
    profile_args=(-profile:v main10 -pix_fmt p010le)
    bit_label="10-bit"
  else
    profile_args=(-profile:v main -pix_fmt nv12)
    bit_label="8-bit"
  fi

  size_before=$(stat -f%z "$file")
  avail_bytes=$(df -k "$(dirname "$file")" | awk 'NR==2 {print $4 * 1024}')
  min_free_bytes=$(( MIN_FREE_GB * 1024 * 1024 * 1024 ))

  if (( avail_bytes < size_before + min_free_bytes )); then
    log "SKIP insufficient free space (need $(human $((size_before + min_free_bytes))), have $(human "$avail_bytes")): $file"
    echo "fail" >> "$STATS_FILE"
    return 0
  fi

  dir=$(dirname "$file")
  stem="${base%.*}"
  tmp="$dir/${stem}.transcoding.mkv"
  final="$dir/${stem}.mkv"

  if [[ "$file" != "$final" && -e "$final" ]]; then
    log "SKIP destination already exists: $final (source: $file)"
    echo "skip" >> "$STATS_FILE"
    return 0
  fi

  log "TRANSCODE [$codec $bit_label, $(human "$size_before")]: $file"

  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] would write: $final"
    echo "skip" >> "$STATS_FILE"
    return 0
  fi

  rm -f "$tmp"

  if ffmpeg -hide_banner -loglevel error $FFMPEG_STATS -nostdin -y \
        ${HWACCEL_ARGS[@]+"${HWACCEL_ARGS[@]}"} \
        -i "$file" \
        -map 0:v -map '0:a?' -map '0:s?' \
        -map_metadata 0 -map_chapters 0 \
        -c:v hevc_videotoolbox -q:v "$QUALITY" -tag:v hvc1 \
        ${FAST_ENCODER_ARGS[@]+"${FAST_ENCODER_ARGS[@]}"} \
        "${profile_args[@]}" \
        -c:a copy -c:s copy \
        "$tmp"; then

    out_codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name \
                  -of default=nw=1:nk=1 "$tmp" 2>/dev/null || true)
    size_after=0
    [[ -f "$tmp" ]] && size_after=$(stat -f%z "$tmp")

    if [[ "$out_codec" != "hevc" ]]; then
      log "FAIL output codec was '$out_codec', not hevc: $tmp"
      rm -f "$tmp"
      echo "fail" >> "$STATS_FILE"
    elif (( size_after < 1048576 )); then
      log "FAIL output suspiciously small ($(human "$size_after")): $tmp"
      rm -f "$tmp"
      echo "fail" >> "$STATS_FILE"
    elif (( size_after > size_before * 12 / 10 )); then
      log "FAIL output larger than source by >20% ($(human "$size_after") vs $(human "$size_before")) — keeping original: $tmp"
      rm -f "$tmp"
      echo "fail" >> "$STATS_FILE"
    else
      rm -f "$file"
      mv "$tmp" "$final"
      pct=$(( (size_before - size_after) * 100 / size_before ))
      log "OK -${pct}% [$(human "$size_before") → $(human "$size_after")]: $final"
      echo "ok $size_before $size_after" >> "$STATS_FILE"
    fi
  else
    log "FAIL ffmpeg error on: $file"
    rm -f "$tmp"
    echo "fail" >> "$STATS_FILE"
  fi
}

log "starting transcode under $ROOT (dry_run=$DRY_RUN quality=$QUALITY min_free=${MIN_FREE_GB}GB jobs=$JOBS fast=$FAST)"

while IFS= read -r -d '' file; do
  if (( JOBS > 1 )); then
    # throttle: wait until fewer than $JOBS workers are running
    while (( $(jobs -r -p | wc -l) >= JOBS )); do
      sleep 0.5
    done
    process_file "$file" &
  else
    process_file "$file"
  fi
done < <(find "$ROOT" -type f \( \
            -iname '*.mkv' -o -iname '*.mp4' -o -iname '*.avi' \
         -o -iname '*.mov' -o -iname '*.m4v' -o -iname '*.wmv' \
         -o -iname '*.ts'  -o -iname '*.m2ts' -o -iname '*.mpg' \
         -o -iname '*.mpeg' -o -iname '*.flv' -o -iname '*.webm' \
         \) -print0 | sort -z)

wait
