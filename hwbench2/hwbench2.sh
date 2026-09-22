#!/data/data/com.termux/files/usr/bin/bash
# hwbench2 — DOE-driven extension of hwbench: 3-SoC benchmark with
# thermal + power telemetry.
#
# Reuses hwbench v1 conventions: ffmpeg -nostdin under `timeout`,
# result in {OK, FAIL, TIMEOUT}, non-empty (-s) output check, CSV to Export/.
#
# Usage:
#   hwbench2 <segment> [--pilot|--full|--plan|--prep] [--trials N]
#            [--sustained K] [--timeout S] [--seed N] [--4k]
#
#   --prep     device readiness checks + input caching (no benchmark)
#   --plan     print the experiment plan (cells, run counts) and exit
#   --pilot    validation run: h264 only, 1080p (defaults: 3 trials, 5 sustained)
#   --full     the week DOE: h264+hevc, 1080p (defaults: 5 trials, 10 sustained)
#   --4k       add 4K cells (stretch goal)
#
# Results: ~/storage/shared/Export/hwbench2_<device>_<timestamp>.csv
# Cross-device rule: generate inputs once (--prep on device 1), copy
# ~/.cache/hwbench2/in_*.mp4 to the other devices, verify sha matches.

set -u
PROG="hwbench2"

# ---------- args (while/case — never the for/shift desync) ----------
SEGMENT=""; MODE="pilot"; TRIALS=""; SUSTAINED=""; SEED="$RANDOM"
TIMEOUT_S=300; TIMEOUT_SET=0; FOURK=0
while [ $# -gt 0 ]; do
  case "$1" in
    --pilot) MODE="pilot" ;;
    --full) MODE="full" ;;
    --plan) MODE="plan" ;;
    --prep) MODE="prep" ;;
    --4k) FOURK=1 ;;
    --trials) TRIALS="$2"; shift ;;
    --sustained) SUSTAINED="$2"; shift ;;
    --timeout) TIMEOUT_S="$2"; TIMEOUT_SET=1; shift ;;
    --seed) SEED="$2"; shift ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    -*) echo "$PROG: unknown flag $1" >&2; exit 2 ;;
    *) if [ -z "$SEGMENT" ]; then SEGMENT="$1";
       else echo "$PROG: only one segment" >&2; exit 2; fi ;;
  esac
  shift
done
[ -z "$SEGMENT" ] && { echo "usage: $PROG <segment> [--pilot|--full|--plan|--prep]" >&2; exit 2; }

case "$MODE" in
  pilot) : "${TRIALS:=3}"; : "${SUSTAINED:=5}"; [ "$TIMEOUT_SET" = 0 ] && TIMEOUT_S=120 ;;
  full|plan) : "${TRIALS:=5}"; : "${SUSTAINED:=10}" ;;
esac

# ---------- paths ----------
SEG_DIR="$HOME/storage/shared/$SEGMENT"
EXPORT_DIR="$HOME/storage/shared/Export"
CACHE_DIR="$HOME/.cache/hwbench2"
LOG_DIR="$CACHE_DIR/logs"
mkdir -p "$EXPORT_DIR" "$CACHE_DIR" "$LOG_DIR"

# ---------- device identity ----------
DEVICE_MODEL="$(getprop ro.product.model 2>/dev/null | tr -cd 'A-Za-z0-9' || echo unknown)"
SOC="$(getprop ro.soc.model 2>/dev/null || getprop ro.hardware 2>/dev/null || echo unknown)"
FINGERPRINT="$(getprop ro.build.fingerprint 2>/dev/null || echo unknown)"
TS="$(date +%Y%m%d_%H%M%S)"
CSV="$EXPORT_DIR/hwbench2_${DEVICE_MODEL}_${TS}.csv"

declare -A INPUT_SHA=()

# ---------- telemetry ----------
batt_pct() {
  if command -v termux-battery-status >/dev/null 2>&1; then
    termux-battery-status 2>/dev/null | jq -r '.percentage // empty' 2>/dev/null
  else
    dumpsys battery 2>/dev/null | awk '/level:/{print $2}'
  fi
}

# Skin/SoC temp preferred, else hottest zone. sysfs is millidegrees.
skin_temp_c() {
  local f type t skin="" maxt=""
  for f in /sys/class/thermal/thermal_zone*/temp; do
    [ -r "$f" ] || continue
    type="$(cat "${f%/temp}/type" 2>/dev/null)"
    t="$(cat "$f" 2>/dev/null)"
    case "$type" in *skin*|*Skin*|*soc*|*SOC*) skin="$t" ;; esac
    if [ -z "$maxt" ] || [ "${t:-0}" -gt "$maxt" ]; then maxt="$t"; fi
  done
  t="${skin:-$maxt}"
  [ -n "$t" ] && awk "BEGIN{printf \"%.1f\", $t/1000}" || echo ""
}

cpu_mhz_avg() {
  local sum=0 n=0 f v
  for f in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq; do
    [ -r "$f" ] || continue
    v="$(cat "$f" 2>/dev/null)" || continue
    sum=$((sum + v)); n=$((n + 1))
  done
  [ "$n" -gt 0 ] && awk "BEGIN{printf \"%.0f\", $sum/$n/1000}" || echo ""
}

# ---------- capability detection (same spirit as hwbench v1 DETECT) ----------
ENC_H264_SW=0; ENC_H264_HW=0; ENC_HEVC_SW=0; ENC_HEVC_HW=0; DEC_HW=0
have_encoder() { ffmpeg -hide_banner -encoders 2>/dev/null | grep -q " $1 "; }
have_hwaccel() { ffmpeg -hide_banner -hwaccels 2>/dev/null | grep -q "$1"; }

detect_caps() {
  have_encoder libx264 && ENC_H264_SW=1
  have_encoder h264_mediacodec && ENC_H264_HW=1
  have_encoder libx265 && ENC_HEVC_SW=1
  have_encoder hevc_mediacodec && ENC_HEVC_HW=1
  have_hwaccel mediacodec && DEC_HW=1
  echo "$PROG: caps: libx264=$ENC_H264_SW h264_mediacodec=$ENC_H264_HW libx265=$ENC_HEVC_SW hevc_mediacodec=$ENC_HEVC_HW mediacodec_decode=$DEC_HW"
}

# ---------- test inputs: identical bytes on every device ----------
prep_inputs() {
  [ -d "$SEG_DIR" ] || { echo "$PROG: segment dir not found: $SEG_DIR" >&2; exit 1; }
  local src
  src="$(find "$SEG_DIR" -maxdepth 1 -type f -name '*.mp4' ! -name '.*' 2>/dev/null | head -1)"
  [ -n "$src" ] || { echo "$PROG: no .mp4 found in $SEG_DIR (dotfiles excluded)" >&2; exit 1; }
  local res out scale
  for res in 1080p 4k; do
    out="$CACHE_DIR/in_${res}.mp4"
    if [ ! -s "$out" ]; then
      scale="scale=1920:1080"; [ "$res" = "4k" ] && scale="scale=3840:2160"
      echo "$PROG: generating $out from $(basename "$src")..."
      ffmpeg -nostdin -y -i "$src" -t 10 -vf "$scale" \
        -c:v libx264 -preset veryfast -crf 23 -an "$out" </dev/null \
        >/dev/null 2>"$LOG_DIR/gen_${res}.log" || {
          echo "$PROG: input gen failed:"; tail -n 6 "$LOG_DIR/gen_${res}.log"; exit 1; }
    fi
    INPUT_SHA[$res]="$(sha256sum "$out" | awk '{print $1}')"
  done
}

# ---------- experiment cells ----------
CELLS=()
build_cells() {
  CELLS=()
  local codecs="h264" reses="1080p" codec res
  [ "$MODE" = "full" ] && codecs="h264 hevc"
  [ "$FOURK" = 1 ] && reses="1080p 4k"
  for codec in $codecs; do
    for res in $reses; do
      case "$codec" in
        h264)
          [ "$ENC_H264_SW" = 1 ] && CELLS+=("h264|sw|${res}")
          [ "$ENC_H264_HW" = 1 ] && CELLS+=("h264|hw_enc|${res}")
          { [ "$DEC_HW" = 1 ] && [ "$ENC_H264_SW" = 1 ]; } && CELLS+=("h264|hw_dec|${res}")
          ;;
        hevc)
          [ "$ENC_HEVC_SW" = 1 ] && CELLS+=("hevc|sw|${res}")
          [ "$ENC_HEVC_HW" = 1 ] && CELLS+=("hevc|hw_enc|${res}")
          ;;
      esac
    done
  done
}

# ---------- one encode ----------
encode_one() { # codec path res out log
  local inp="$CACHE_DIR/in_$3.mp4"
  case "$1|$2" in
    "h264|sw")     timeout "$TIMEOUT_S" ffmpeg -nostdin -y -i "$inp" -c:v libx264 -preset veryfast -crf 23 -an "$4" </dev/null >"$5" 2>&1 ;;
    "h264|hw_enc") timeout "$TIMEOUT_S" ffmpeg -nostdin -y -i "$inp" -c:v h264_mediacodec -b:v 8M -an "$4" </dev/null >"$5" 2>&1 ;;
    "h264|hw_dec") timeout "$TIMEOUT_S" ffmpeg -nostdin -y -hwaccel mediacodec -i "$inp" -c:v libx264 -preset veryfast -crf 23 -an "$4" </dev/null >"$5" 2>&1 ;;
    "hevc|sw")     timeout "$TIMEOUT_S" ffmpeg -nostdin -y -i "$inp" -c:v libx265 -preset veryfast -crf 28 -an "$4" </dev/null >"$5" 2>&1 ;;
    "hevc|hw_enc") timeout "$TIMEOUT_S" ffmpeg -nostdin -y -i "$inp" -c:v hevc_mediacodec -b:v 8M -an "$4" </dev/null >"$5" 2>&1 ;;
  esac
  return $?
}

fps_from_log() { grep -oE 'fps=[ ]*[0-9.]+' "$1" 2>/dev/null | tail -1 | grep -oE '[0-9.]+'; }

write_header() {
  [ -s "$CSV" ] && return 0
  echo "device,soc,fingerprint,ts_iso,codec,path,res,trial_idx,sustained_idx,run_kind,result,elapsed_s,out_bytes,fps,temp_c_start,temp_c_end,cpu_mhz_avg,batt_start,batt_end,input_sha256,seed" > "$CSV"
}

cell_summary() { # elapsed values of OK runs
  [ $# -eq 0 ] && { echo "  summary: no OK runs in cell"; return; }
  printf '%s\n' "$@" | awk '{s+=$1; ss+=$1*$1; n++}
    END{mean=s/n; var=(ss-s*s/n)/(n>1?n-1:1); if(var<0)var=0;
        printf "  summary: n=%d mean=%.2fs stdev=%.2fs\n", n, mean, sqrt(var)}'
}

BASELINE_TEMP=""
cooldown() {
  local target now waited=0
  [ -z "$BASELINE_TEMP" ] && return 0
  target="$(awk "BEGIN{printf \"%.1f\", $BASELINE_TEMP + 2.0}")"
  while [ "$waited" -lt 600 ]; do
    now="$(skin_temp_c)"; [ -z "$now" ] && return 0
    if awk "BEGIN{exit !( $now <= $target )}"; then
      echo "  cooldown done (${now}C <= ${target}C)"; return 0
    fi
    sleep 15; waited=$((waited + 15))
  done
  echo "  cooldown timed out at ${now}C (target ${target}C) — continuing, flagged in notes"
}

run_cell() { # codec path res
  local codec="$1" path="$2" res="$3" sha="${INPUT_SHA[$3]}"
  local run_kind reps i out log rc result elapsed fps bytes
  local trial_idx sust_idx t0 t1 ts0 c0 b0 mhz c1 b1
  local -a ok_times=()
  for run_kind in trial sustained; do
    if [ "$run_kind" = "trial" ]; then reps="$TRIALS"; else reps="$SUSTAINED"; fi
    for ((i=1; i<=reps; i++)); do
      out="$LOG_DIR/out_${codec}_${path}_${res}_${run_kind}_${i}.mp4"
      log="$LOG_DIR/run_${codec}_${path}_${res}_${run_kind}_${i}.log"
      rm -f "$out"
      t0="$(date +%s.%N)"; ts0="$(date -u +%FT%TZ)"
      c0="$(skin_temp_c)"; b0="$(batt_pct)"; mhz="$(cpu_mhz_avg)"
      encode_one "$codec" "$path" "$res" "$out" "$log"; rc=$?
      t1="$(date +%s.%N)"
      c1="$(skin_temp_c)"; b1="$(batt_pct)"
      elapsed="$(awk "BEGIN{printf \"%.2f\", $t1 - $t0}")"
      if [ "$rc" -eq 124 ]; then result="TIMEOUT"
      elif [ "$rc" -eq 0 ] && [ -s "$out" ]; then result="OK"
      else result="FAIL"
      fi
      fps="$(fps_from_log "$log")"
      bytes=0; [ -f "$out" ] && bytes="$(stat -c%s "$out" 2>/dev/null || echo 0)"
      if [ "$run_kind" = "trial" ]; then trial_idx="$i"; sust_idx=""; else trial_idx=""; sust_idx="$i"; fi
      printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$DEVICE_MODEL" "$SOC" "$FINGERPRINT" "$ts0" "$codec" "$path" "$res" \
        "$trial_idx" "$sust_idx" "$run_kind" "$result" "$elapsed" "$bytes" "$fps" \
        "$c0" "$c1" "$mhz" "$b0" "$b1" "$sha" "$SEED" >> "$CSV"
      echo "  [$run_kind $i/$reps] $codec/$path/$res -> $result ${elapsed}s${fps:+ ${fps}fps}"
      [ "$result" = "OK" ] && ok_times+=("$elapsed")
      if [ "$result" = "FAIL" ]; then echo "  log tail:"; tail -n 4 "$log" | sed 's/^/    /'; fi
      [ "$run_kind" = "trial" ] && sleep 2
    done
  done
  cell_summary "${ok_times[@]}"
  cooldown
}

# ---------- modes ----------
do_prep() {
  echo "== $PROG --prep =="
  echo "device : $DEVICE_MODEL / $SOC"
  echo "build  : $FINGERPRINT"
  local c
  for c in ffmpeg jq timeout shuf; do
    command -v "$c" >/dev/null 2>&1 && echo "  [ok] $c" || echo "  [MISSING] $c"
  done
  command -v termux-battery-status >/dev/null 2>&1 \
    && echo "  [ok] termux-battery-status" \
    || echo "  [warn] termux-battery-status missing (Termux:API app + pkg install termux-api)"
  python3 -c "import matplotlib" 2>/dev/null \
    && echo "  [ok] matplotlib" \
    || echo "  [info] matplotlib missing -> pkg install python matplotlib (needed for plots)"
  echo "battery: $(batt_pct)% (want >60 and UNPLUGGED for drain measurement)"
  echo "skin temp now: $(skin_temp_c)C"
  prep_inputs
  echo "inputs cached in $CACHE_DIR — copy these exact files to other devices:"
  sha256sum "$CACHE_DIR"/in_*.mp4
  echo ""
  echo "manual steps before a run:"
  echo "  1. unplug charger (charging adds heat + ruins drain measurement)"
  echo "  2. airplane mode ON, brightness fixed low, close all apps"
  echo "  3. idle 5 min, then: $PROG <segment> --pilot"
}

do_plan() {
  local per_cell total
  per_cell=$((TRIALS + SUSTAINED)); total=$((${#CELLS[@]} * per_cell))
  echo "mode=$MODE trials=$TRIALS sustained=$SUSTAINED timeout=${TIMEOUT_S}s seed=$SEED"
  echo "cells (${#CELLS[@]}):"
  local c; for c in "${CELLS[@]}"; do echo "  - ${c//|/ /}"; done
  echo "runs: $total total ($per_cell per cell)"
  echo "rough wall time @~75s/run incl. cooldowns: ~$((total * 75 / 60)) min"
}

# ---------- dispatch ----------
case "$MODE" in prep) do_prep; exit 0 ;; esac

prep_inputs
detect_caps
build_cells
[ "${#CELLS[@]}" -eq 0 ] && { echo "$PROG: no runnable cells — no encoders detected?" >&2; exit 1; }
case "$MODE" in plan) do_plan; exit 0 ;; esac

mapfile -t ORDERED < <(printf '%s\n' "${CELLS[@]}" | shuf)
printf '%s\n' "${ORDERED[@]}" > "$LOG_DIR/run_order_${TS}.txt"
BASELINE_TEMP="$(skin_temp_c)"
echo "$PROG: baseline skin temp ${BASELINE_TEMP}C; seed $SEED; results -> $CSV"
write_header
for cell in "${ORDERED[@]}"; do
  IFS='|' read -r codec path res <<< "$cell"
  echo "== cell: $codec / $path / $res =="
  run_cell "$codec" "$path" "$res"
done
echo "$PROG: done. CSV: $CSV"
echo "Plot it: hwbench_plot.py $CSV"
