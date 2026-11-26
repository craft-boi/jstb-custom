#!/usr/bin/env bash
# net-down.sh — undo everything net-up.sh created.
#   sudo ./net-down.sh
# Leaves no trace: no NM profile, no dnsmasq, no files outside ./run
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/run"
CON=stb-isolated

if [[ $EUID -ne 0 ]]; then echo "run as root: sudo $0" >&2; exit 1; fi

if [[ -f "$RUN/dnsmasq.pid" ]]; then
  kill "$(cat "$RUN/dnsmasq.pid")" 2>/dev/null && echo "  stopped dnsmasq"
  rm -f "$RUN/dnsmasq.pid"
fi

if nmcli -t -f NAME connection show | grep -qx "$CON"; then
  nmcli connection down "$CON" >/dev/null 2>&1 || true
  nmcli connection delete "$CON" >/dev/null 2>&1 && echo "  deleted NM profile '$CON'"
fi

rm -rf "$RUN"
echo "  removed $RUN"
echo "  done — your network is exactly as it was."
