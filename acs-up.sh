#!/usr/bin/env bash
# ============================================================================
# acs-up.sh — start the fake ACS: GenieACS (docker) + pass_front.py (TLS :8443)
#
#   sudo ./acs-up.sh          # pull images first time, then start both
#   sudo ./acs-down.sh        # stop everything, drop the mongo volume
#
# Ports used on this PC: 7547 (cwmp, docker), 7557 (nbi, docker),
#                        7567/3000 (fs/ui, docker), 8443+9443 (pass_front)
# ============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/run"
TLS="$HERE/repo/tls"

if [[ $EUID -ne 0 ]]; then echo "run as root: sudo $0" >&2; exit 1; fi
[[ -f "$TLS/docker-compose.yml" ]] || { echo "repo missing: $TLS" >&2; exit 1; }
python3 -c 'import Crypto' 2>/dev/null || { echo "install pycryptodome: sudo pacman -S python-pycryptodome" >&2; exit 1; }
mkdir -p "$RUN"

echo "[1/3] GenieACS (docker compose up -d)"
( cd "$TLS" && docker compose up -d --quiet-pull )

echo -n "[2/3] waiting for NBI :7557 "
for i in $(seq 1 60); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:7557/devices/ 2>/dev/null || true)
  [[ "$code" == "200" ]] && break
  printf '.'; sleep 1
done
echo
[[ "${code:-}" == "200" ]] || { echo "  ! NBI did not answer; check: docker logs genieacs" >&2; exit 1; }
echo "      NBI ok"

echo "[3/3] pass_front.py (TLS :8443,:9443 -> genieacs :7547)"
if [[ -f "$RUN/pass_front.pid" ]] && kill -0 "$(cat "$RUN/pass_front.pid")" 2>/dev/null; then
  kill "$(cat "$RUN/pass_front.pid")" 2>/dev/null || true; sleep 1
fi
nohup python3 "$TLS/pass_front.py" --log "$RUN/pass_front.log" \
  >>"$RUN/pass_front.out" 2>&1 &
echo $! > "$RUN/pass_front.pid"
sleep 2
kill -0 "$(cat "$RUN/pass_front.pid")" 2>/dev/null || { tail -5 "$RUN/pass_front.out" >&2; exit 1; }
ss -ltn 2>/dev/null | grep -q ':8443' || { echo "  ! nothing listening on 8443" >&2; exit 1; }

echo
echo "  ACS up:"
echo "    cwmp   127.0.0.1:7547   (docker)"
echo "    nbi    127.0.0.1:7557   (stage1.sh uses this)"
echo "    ui     http://127.0.0.1:3000   admin / admin"
echo "    tls    :8443 + :9443    -> 7547   (pass_front, log: run/pass_front.log)"
echo
echo "  Now: plug the STB into the isolated NIC, power it on, wait ~1 min,"
echo "  then confirm it showed up:  ./watch.sh"
