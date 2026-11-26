#!/usr/bin/env bash
# watch.sh — has the STB talked to us yet?  (no root needed)
#   ./watch.sh
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/run"

echo "== DHCP leases seen by our dnsmasq =="
if [[ -f "$RUN/dnsmasq.log" ]]; then
  grep -E "DHCPACK|DHCPDISCOVER" "$RUN/dnsmasq.log" | tail -5 || echo "  (none yet)"
else
  echo "  dnsmasq not running — sudo ./net-up.sh"
fi

echo
echo "== does the spoof answer? =="
if command -v dig >/dev/null; then
  dig +short +time=1 +tries=1 @10.10.10.1 acs.oss.jio.com A 2>/dev/null || echo "  (no answer — subnet down?)"
else
  echo "  install bind-tools for dig, or check run/dnsmasq.log"
fi

echo
echo "== devices in GenieACS =="
curl -s --max-time 3 'http://127.0.0.1:7557/devices/?projection=_id,_lastInform' 2>/dev/null \
  | python3 -c 'import sys,json
d = json.load(sys.stdin)
if not d: print("  none — STB has not connected yet")
for x in d: print("  ", x["_id"], x.get("_lastInform",""))' 2>/dev/null \
  || echo "  NBI not reachable — sudo ./acs-up.sh"

echo
echo "== CWMP traffic (last 5 lines of run/pass_front.log) =="
tail -5 "$RUN/pass_front.log" 2>/dev/null || echo "  (no pass_front log yet)"
