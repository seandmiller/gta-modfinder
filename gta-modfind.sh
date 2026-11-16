#!/usr/bin/env bash
# gta-modfind.sh — find which .asi mods break GTA V on boot (Linux / Steam / Proton)
#
# How it works: it moves mods out of the game folder in groups, launches the
# game, checks whether it crashed, and keeps splitting the failing groups until
# every bad mod is found. Works even when several mods are broken.
#
# Usage:
#   chmod +x gta-modfind.sh
#   ./gta-modfind.sh                 # "ask" mode: you answer y/n after each boot
#   MODE=auto ./gta-modfind.sh       # fully automatic: watches the game process
#   MODE=dryrun FAKE_BAD="a.asi b.asi" ./gta-modfind.sh   # practice run, no game
#
# All mods are put back where they were when the script finishes or you Ctrl+C.

set -u
shopt -s nullglob

# ---------- settings (edit these or pass them in like GAME_DIR=... ./gta-modfind.sh)
GAME_DIR="${GAME_DIR:-$HOME/.steam/steam/steamapps/common/Grand Theft Auto V}"
APPID="${APPID:-271590}"        # 271590 = GTA V Legacy, 3240220 = GTA V Enhanced
MODE="${MODE:-ask}"             # ask | auto | dryrun
BOOT_TIMEOUT="${BOOT_TIMEOUT:-180}"  # auto: seconds to wait for the game to start
STABLE_TIME="${STABLE_TIME:-90}"     # auto: seconds it must stay running to pass
KEEP=("ScriptHookVDotNet.asi")  # always left enabled, never tested
FAKE_BAD="${FAKE_BAD:-}"        # dryrun only: mods to pretend are broken
# ----------

PARK="$GAME_DIR/_modfind_parked"
LOG="$GAME_DIR/_modfind_results.txt"
GAME_PROC='GTA5(_Enhanced)?\.exe'
BAD=()
COMBOS=()
RUNS=0

say() { echo "$*" | tee -a "$LOG"; }

in_set() {
  local m=$1; shift
  local x
  for x in "$@"; do [[ $x == "$m" ]] && return 0; done
  return 1
}

restore() {
  if [[ -d $PARK ]]; then
    local f
    for f in "$PARK"/*; do mv -n "$f" "$GAME_DIR/"; done
    rmdir "$PARK" 2>/dev/null
    echo "All mods restored to the game folder."
  fi
}
trap 'restore; exit' INT TERM
trap restore EXIT


set_enabled() {
  local m
  for m in "${MODS[@]}"; do
    if in_set "$m" "$@"; then
      [[ -e $PARK/$m ]] && mv "$PARK/$m" "$GAME_DIR/"
    else
      [[ -e $GAME_DIR/$m ]] && mv "$GAME_DIR/$m" "$PARK/"
    fi
  done
}

game_running() { pgrep -f "$GAME_PROC" >/dev/null; }

kill_game() {
  pkill -f "$GAME_PROC" 2>/dev/null
  pkill -f 'PlayGTAV\.exe|Rockstar Games/Launcher|SocialClubHelper\.exe' 2>/dev/null
  local i
  for i in $(seq 1 30); do game_running || break; sleep 1; done
  sleep 10   # give Steam time to notice the game has stopped
}


run_test() {
  RUNS=$((RUNS + 1))
  set_enabled "$@"
  say ""
  say "Test #$RUNS with ${#} mod(s): ${*:-(none)}"

  if [[ $MODE == dryrun ]]; then
    local m
    for m in "$@"; do
      if in_set "$m" $FAKE_BAD; then say "  -> FAIL"; return 1; fi
    done
    say "  -> PASS"; return 0
  fi

  steam -applaunch "$APPID" >/dev/null 2>&1 &

  if [[ $MODE == ask ]]; then
    local ans
    read -r -p "  Did it crash or fail to boot? [y/n] " ans </dev/tty
    kill_game
    if [[ $ans == [yY]* ]]; then say "  -> FAIL"; return 1; fi
    say "  -> PASS"; return 0
  fi

  # auto mode
  local t=0
  until game_running; do
    sleep 2; t=$((t + 2))
    if (( t >= BOOT_TIMEOUT )); then
      say "  -> FAIL (game never started)"; kill_game; return 1
    fi
  done
  t=0
  while (( t < STABLE_TIME )); do
    sleep 2; t=$((t + 2))
    if ! game_running; then
      say "  -> FAIL (game closed after ~${t}s)"; kill_game; return 1
    fi
  done
  say "  -> PASS (stayed running ${STABLE_TIME}s)"
  kill_game
  return 0
}


find_bad() {
  local items=("$@")
  if run_test "${items[@]}"; then return 0; fi
  if (( ${#items[@]} == 1 )); then
    BAD+=("${items[0]}")
    say "  *** Found bad mod: ${items[0]}"
    return 1
  fi
  local half=$(( ${#items[@]} / 2 ))
  local found=0
  find_bad "${items[@]:0:half}" || found=1
  find_bad "${items[@]:half}"   || found=1
  if (( found == 0 )); then
   
    COMBOS+=("${items[*]}")
    say "  *** Conflict: these work alone but crash together: ${items[*]}"
  fi
  return 1
}

# ---------- main
if [[ $MODE != dryrun && ! -d $GAME_DIR ]]; then
  echo "Game folder not found: $GAME_DIR"
  echo "Run again with GAME_DIR=\"/path/to/Grand Theft Auto V\" ./gta-modfind.sh"
  exit 1
fi
if [[ $MODE == dryrun ]]; then
  GAME_DIR="$(mktemp -d)"; PARK="$GAME_DIR/_modfind_parked"; LOG="$GAME_DIR/_modfind_results.txt"
  for m in $FAKE_BAD trainer.asi carspawner.asi weather.asi hud.asi traffic.asi police.asi; do
    touch "$GAME_DIR/$m"
  done
fi

mkdir -p "$PARK"
: > "$LOG"

MODS=()
for f in "$GAME_DIR"/*.asi; do
  name=$(basename "$f")
  in_set "$name" "${KEEP[@]}" || MODS+=("$name")
done

if (( ${#MODS[@]} == 0 )); then
  echo "No .asi mods found in $GAME_DIR"; exit 1
fi

say "Mode: $MODE | Mods to test (${#MODS[@]}): ${MODS[*]}"
[[ $MODE == ask ]] && say "After each launch, play until the point it normally crashes, then answer."


if ! run_test; then
  say ""
  say "The game fails even with NO mods enabled, so the problem is Proton,"
  say "the Rockstar Launcher, or Script Hook V itself, not one of your mods."
  say "Try launch options: PROTON_LOG=1 %command%  and read ~/steam-$APPID.log"
  exit 1
fi


find_bad "${MODS[@]}" && say "" && say "Everything booted fine with all mods enabled. No bad mods found."

say ""
say "================ RESULTS ($RUNS test runs) ================"
if (( ${#BAD[@]} )); then
  say "Bad mods:"; for m in "${BAD[@]}"; do say "  - $m"; done
fi
if (( ${#COMBOS[@]} )); then
  say "Mod conflicts (crash only together):"; for c in "${COMBOS[@]}"; do say "  - $c"; done
fi
say "Full log saved to: $LOG"
