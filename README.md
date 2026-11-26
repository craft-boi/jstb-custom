# STB / GenieACS pre-flight — everything to set up *before* the cable goes in

Method used here: **direct cable, isolated subnet** (the second option in the repo README).
Your PC keeps Wi-Fi as its internet uplink; a spare Ethernet NIC becomes a one-cable,
STB-only network that answers DHCP and lies about `acs.oss.jio.com`.

```
STB ──cable── [ spare NIC ] PC 10.10.10.1 ── dnsmasq (DHCP + DNS spoof)
                                        ├── pass_front.py :8443/:9443  (TLS, RilROOTCA chain)
                                        └── GenieACS :7547 (docker)  + NBI :7557 + UI :3000
```

Everything is reversible: two scripts up, two scripts down, nothing outside this folder
and one NetworkManager profile called `stb-isolated`.

---

## 0. Hardware (do this before any software)

- **A spare Ethernet port.** Built-in NIC (`enp0s31f6` is free on this machine) or a
  USB‑A/USB‑C → Ethernet dongle (₹400-ish). **Do not use Wi-Fi** for the STB link:
  you would have to hijack your router's DNS, which is the thing we are avoiding.
- **One plain Ethernet cable** (STB ↔ PC). No crossover needed.
- Keep the PC on Wi-Fi the whole time. Never bridge the spare NIC to Wi-Fi.
- The STB must have **no internet** during the whole Stage 1: a direct cable guarantees it.
  This is the "ensure NO INTERNET ACCESS to the STB" line from the README — satisfied by design.

## 1. Packages (already present on this machine, listed for completeness)

| Need | Arch package | Status here |
|---|---|---|
| Docker + compose | `docker docker-compose` | ✅ 29.10.0 / 5.8.0 (daemon needs root — scripts use sudo) |
| python3 + TLS | `python` | ✅ |
| AES for the network-check spoof | `python-pycryptodome` | ✅ imports fine |
| adb | `android-tools` | ✅ 1.0.41 |
| DHCP + DNS for the isolated net | `dnsmasq` | ✅ |
| NetworkManager | `networkmanager` | ✅ active |

If something is missing: `sudo pacman -S --needed docker docker-compose python python-pycryptodome android-tools dnsmasq`.

## 2. Firewall / forwarding (the README's "please disable firewalls")

- No `ufw` / `firewalld` is active on this machine — nothing to disable.
  If you later enable one, allow inbound **8443/tcp** and **9443/tcp** on the `stb-isolated`
  interface only. (Check: `sudo nft list ruleset | head`.)
- `net.ipv4.ip_forward` is 0 → the STB cannot route through your PC to the internet.
  `net-up.sh` prints this; leave it at 0.

## 3. Bring the fake ACS up (in this order)

```bash
cd jstb-setup
sudo ./net-up.sh            # isolated subnet + DHCP + DNS spoof  (creates profile stb-isolated)
sudo ./acs-up.sh            # docker compose up + pass_front.py   (pulls images first run)
./watch.sh                  # confirm: dnsmasq up, spoof answers, NBI up
```

Then, and only then:

4. Plug the cable into the STB, power the STB on.
5. `./watch.sh` until the device appears in GenieACS (first Inform can take a few minutes;
   reboot the STB once if it was already booted before the cable went in).
6. Run the repo scripts from the repo root, in this folder:

```bash
cd repo
./stage1.sh                 # enables ADB, kills the Jio TR069 client
```

`stage1.sh` needs `adb` and `python3` and talks to `http://127.0.0.1:7557`.
The STB's IP on our subnet will be `10.10.10.5x` — pass it if auto-discovery is confused:
`./stage1.sh --stb-ip 10.10.10.5x`.

## 4. Revert (any time, idempotent)

```bash
sudo ./acs-down.sh          # stop pass_front + containers, drop mongo volume
sudo ./net-down.sh          # stop dnsmasq, delete the stb-isolated profile, remove run/
```

After that: unplug the cable, `nmcli connection show` no longer lists `stb-isolated`,
no ports are listening, and nothing was added to your Wi-Fi, router or boot config.
Nuclear option: `rm -rf jstb-setup` (the containers/volume are gone after `acs-down.sh`).

## 5. What is *not* reversible — think first

- `stage1.sh` on the STB itself: enables USB debugging, disables FOTA, disables the Jio
  TR-069 client, and uninstalls ~45 Jio packages **for user 0**. Undo = factory reset of
  the STB. That is on the box, not on this PC.
- `unlock.sh` (Stage 2) flips the bootloader lock and SELinux; the README warns it is
  one-shot per boot and can brick the box if you flash the wrong image. Check
  `adb shell getprop ro.build.version.security_patch` first — anything after May 2024
  and CVE‑2024‑31317 is patched, so do not bother.
- Keep the STB off the internet until Stage 1 finishes, or the real ACS/FOTA overrides you.

## 6. If the STB never shows up

| Symptom | Cause |
|---|---|
| No DHCPDISCOVER in `run/dnsmasq.log` | cable/NIC dead, or STB uses static IP → try `sudo ./net-up.sh <iface>` with the right NIC |
| DHCP lease but no device in GenieACS | TLS/cert: check `run/pass_front.log` for `TLS fail`; pass_front must be up **before** the STB boots |
| `TLS fail ... bad record mac` / handshake error | STB is pinning and wants **:9443** — the front end already listens on both; block 8443 and see if it moves to 9443 |
| Device appears, tasks queue but never apply | STB offline again: it only applies tasks on its next Inform (or on reboot) |
| `ssl.SSLError` in pass_front log | the chain must include RilROOTCA — `repo/tls/acs_chain.pem` is what is loaded |
