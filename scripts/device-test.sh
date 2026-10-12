#!/bin/sh
# Runs sidecarctl against a real iPad, for what the unit tests cannot reach. Needs
# one reachable iPad, unlocked and awake, and nothing else starting or ending
# Sidecar sessions meanwhile. It starts and ends sessions, so displays rearrange
# while it runs, and it ends with none. A connect that fails makes macOS show a
# dialog, so a failing run can leave some behind.
#
#   scripts/device-test.sh [path to sidecarctl]

set -u

bin=${1:-.build/release/sidecarctl}
[ -x "$bin" ] || { echo "no binary at $bin, build with: xcrun swift build -c release" >&2; exit 1; }

failures=0

# check <label> <exit code> <first words of the output, or ""> <arguments...>
check() {
  label=$1 code=$2 words=$3
  shift 3
  out=$("$bin" "$@" 2>&1)
  got=$?
  case $out in
    "$words"*) matched=yes ;;
    *) matched=no ;;
  esac
  if [ "$got" -eq "$code" ] && [ "$matched" = yes ]; then
    echo "ok    $label"
  else
    echo "FAIL  $label: exit $got, wanted $code${words:+ and output starting \"$words\"}"
    echo "      $out"
    failures=$((failures + 1))
  fi
  # Sidecar needs a moment between a session ending and the next starting
  sleep 3
}

listing=$("$bin" devices --verbose) || { echo "no reachable iPad" >&2; exit 1; }
[ "$(printf '%s\n' "$listing" | wc -l)" -eq 1 ] || { echo "more than one iPad reachable, this needs exactly one" >&2; exit 1; }
tab=$(printf '\t')
uuid=${listing%%"$tab"*}
rest=${listing#*"$tab"}
name=${rest%%"$tab"*}
echo "status ${rest#*"$tab"}"

"$bin" disconnect >/dev/null 2>&1
sleep 3

check "an unknown UUID is no such device" 3 "no Sidecar device matches" connect 00000000-0000-0000-0000-000000000000
check "disconnect with no session" 0 "not connected" disconnect
check "connect by UUID" 0 "connected to" connect "$uuid"
check "connect again keeps the session" 0 "already connected" connect
check "connect by name finds the same session" 0 "already connected" connect "$name"
check "system keeps whatever is live" 0 "already connected" connect --connection system
check "wireless replaces or keeps it" 0 "" connect --connection wireless
check "wireless again keeps it" 0 "already connected" connect --connection wireless

# With an iPad on USB a forced wired connect replaces the wireless session, and
# without one it is refused and the session stays
"$bin" connect --connection wired >/dev/null 2>&1
case $? in
  0)
    echo "ok    wired replaces wireless (an iPad is on USB)"
    sleep 3
    check "wired again keeps it" 0 "already connected" connect --connection wired
    check "the default keeps a wired session" 0 "already connected" connect
    ;;
  8)
    echo "ok    wired is refused with no iPad on USB"
    check "the wireless session survived the refusal" 0 "already connected" connect --connection wireless
    ;;
  *)
    echo "FAIL  connect --connection wired"
    failures=$((failures + 1))
    ;;
esac

# A boost runs for as long as its session, so it is started in the background and its
# first line read from a file
boost() {
  what=$1
  shift
  "$bin" connect >/dev/null 2>&1
  sleep 3
  out=$(mktemp)
  "$bin" boost "$@" >"$out" 2>&1 &
  pid=$!
  sleep 10
  case $(cat "$out") in
    "mirroring Sidecar from"*) echo "ok    $what" ;;
    *)
      echo "FAIL  $what: $(cat "$out")"
      failures=$((failures + 1))
      ;;
  esac
  check "$what, a second one is refused" 7 "a boost is already running" boost
  check "$what, stopped" 0 "stopped boost" boost --stop
  wait "$pid"
  rm -f "$out"
}

boost "boost"
boost "boost in Retina" --retina
check "no boost left running" 0 "no boost running" boost --stop

check "disconnect by UUID" 0 "disconnected from" disconnect "$uuid"

# One command for the session and the boost, which then end together
out=$(mktemp)
"$bin" connect --boost >"$out" 2>&1 &
pid=$!
sleep 16
case $(cat "$out") in
  "connected to"*"mirroring Sidecar from"*) echo "ok    connect --boost" ;;
  *)
    echo "FAIL  connect --boost: $(cat "$out")"
    failures=$((failures + 1))
    ;;
esac
check "stopping the boost" 0 "stopped boost" boost --stop
wait "$pid"
rm -f "$out"
check "the session ended with the boost" 0 "not connected" disconnect
check "disconnect again" 0 "not connected" disconnect

if [ "$failures" -eq 0 ]; then echo "all passed"; else echo "$failures failed"; fi
[ "$failures" -eq 0 ]
