#!/usr/bin/env bash
# acs-down.sh — stop pass_front + GenieACS and drop the collected data.
#   sudo ./acs-down.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/run"
TLS="$HERE/repo/tls"

if [[ $EUID -ne 0 ]]; then echo "run as root: sudo $0" >&2; exit 1; fi

if [[ -f "$RUN/pass_front.pid" ]]; then
  kill "$(cat "$RUN/pass_front.pid")" 2>/dev/null && echo "  stopped pass_front"
  rm -f "$RUN/pass_front.pid"
fi
if [[ -f "$TLS/docker-compose.yml" ]]; then
  ( cd "$TLS" && docker compose down -v ) && echo "  genieacs + mongo removed (volume dropped)"
fi
echo "  done"
