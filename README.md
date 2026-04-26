# asx-ib — Interactive Brokers Gateway (Docker)

Headless IB Gateway running inside Docker, managed by [IBC](https://github.com/IbcAlpha/IBC) for automated login and daily restarts. Access via VNC to configure settings and handle weekly 2FA.

## Components

| Component | Role |
|-----------|------|
| **IB Gateway** | IBKR's API gateway (TWS without charts) |
| **IBC** | Automates login, handles auto-restart dialogs |
| **Xvfb** | Virtual X11 display (no physical screen needed) |
| **x11vnc** | VNC server so you can see/control the display |
| **supervisord** | Process manager: restarts crashed components |

## Quick Start

```bash
# 1. Copy and fill in credentials
cp .env.example .env
$EDITOR .env

# 2. Build and start
docker compose up -d

# 3. Connect via VNC to complete first-time login
vncviewer localhost:5900
# (or use any VNC client: RealVNC, TigerVNC, etc.)

# 4. Verify API is reachable (after login)
socat /dev/null TCP:localhost:4001
```

## Environment Variables

Set these in your `.env` file (never commit this file):

| Variable | Required | Description |
|----------|----------|-------------|
| `IB_USERNAME` | Yes | Your IBKR username |
| `IB_PASSWORD` | Yes | Your IBKR password |
| `IB_TRADING_MODE` | Yes | `live` or `paper` |
| `VNC_PASSWORD` | Recommended | VNC access password (no auth if omitted) |

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| `4001` | TCP | IB Gateway live trading API |
| `4002` | TCP | IB Gateway paper trading API |
| `5900` | VNC | Remote desktop access |

Connect your trading application to `localhost:4001` (live) or `localhost:4002` (paper).

## VNC Access

Connect with any VNC client to `localhost:5900`. Use the password set in `VNC_PASSWORD`.

Recommended clients:
- **TigerVNC**: `vncviewer localhost:5900`
- **RealVNC Viewer**: connect to `localhost:5900`
- **Remmina** (Linux): create a VNC connection to `localhost:5900`

VNC gives you full control of the IB Gateway GUI. Use it to:
- Complete the initial login
- Approve weekly 2FA (Sunday)
- Configure Gateway settings (API port, trusted IPs, etc.)

## First-Time Configuration

On first launch, connect via VNC and:

1. **Log in** — IBC will pre-fill your credentials; click Login
2. **Enable API** — Configure → Settings → API → Enable ActiveX and Socket Clients
3. **Set socket port** — Configure → Settings → API → Socket port: `4001`
4. **Uncheck "Allow connections from localhost only"** — Configure → Settings → API → uncheck this box, then add the Docker gateway IP (usually `172.18.0.1`) to Trusted IPs. Without this, host→container connections are silently rejected regardless of the TrustedIPs list.
5. **Verify auto-restart** — Configure → Lock and Exit → Auto Restart enabled

These settings are persisted in the `ib-settings` Docker volume.

### Host connectivity (Docker bridge networking)

The container runs on Docker bridge networking. Connections from the host appear inside the container as the Docker gateway IP (`172.18.0.1` on default bridge, or check `ip route` inside the container).

`entrypoint.sh` automatically detects this IP and pre-seeds `jts.ini` with it in `TrustedIPs` before IBC starts. This handles fresh volume scenarios where jts.ini doesn't exist yet. For existing volumes, add the IP via the Gateway UI (Configure → Settings → API → Trusted IPs → Create).

**Key setting:** "Allow connections from localhost only" (Configure → Settings → API) must be **unchecked**. This overrides TrustedIPs completely — if checked, only `127.0.0.1` can connect regardless of what's in the list.

## Auto-Restart Behaviour

IBC manages two types of restart:

### Daily Restart (`AutoRestartTime=11:45 PM`)
- IB Gateway closes and reopens automatically at 11:45 PM local time
- No manual intervention needed Monday–Saturday
- IBC automatically re-logs in using stored credentials

### Weekly Cold Restart (`ColdRestartTime=13:00`)
- Happens on Sundays at 13:00 local time
- IBKR requires a full logout/login once per week
- IBC shuts down Gateway and starts fresh
- **You must approve the IBKR Mobile 2FA notification** within a few minutes

To change restart times, edit `config/ibc/config.ini.tmpl` and rebuild.

**AEST timezone note:** Sunday 13:00 AEST = Sunday 03:00 ET (standard) / 02:00 ET (daylight) — both safely after IBKR's 01:00 ET weekly-reset requirement.

## Building

```bash
# Standard build (latest IB Gateway + IBC 3.23.0)
docker compose build

# Pin a specific IBC version
docker build --build-arg IBC_VERSION=3.22.0 .

# Force fresh IB Gateway download
docker compose build --no-cache
```

## Updating

### Update IB Gateway
IB Gateway is downloaded at build time from the "latest" URL. To update:
```bash
docker compose build --no-cache
docker compose up -d
```

### Update IBC
Change `IBC_VERSION` in `Dockerfile` to the desired version and rebuild.
Current version: **3.23.0** — check [IBC releases](https://github.com/IbcAlpha/IBC/releases) for newer.

## Logs

```bash
# All container logs
docker compose logs -f

# Inside the container
docker compose exec ib-gateway tail -f /var/log/supervisor/ibc.log
docker compose exec ib-gateway tail -f /var/log/supervisor/x11vnc.log
docker compose exec ib-gateway tail -f /var/log/ibc/ibc.log
```

## Security

- **Credentials** live in `.env` (gitignored) and are rendered into `config/ibc/config.ini` (also gitignored) at container start
- **VNC password** — always set `VNC_PASSWORD`; without it, VNC is unauthenticated
- **Port binding** — ports bind to all interfaces by default. To restrict to localhost, change `docker-compose.yml` to `"127.0.0.1:4001:4001"` etc.
- The `ib-settings` Docker volume contains only IB Gateway UI preferences, no credentials

## Troubleshooting

### Gateway doesn't appear in VNC
- Wait 30–60 seconds — IBC takes time to launch IB Gateway
- Check: `docker compose logs ib-gateway`
- `ERROR: IB Gateway not found in /root/Jts/ibgateway/` → installer failed; rebuild with `--no-cache`

### VNC connects but screen is black
- Check process status: `docker compose exec ib-gateway supervisorctl status`
- Restart x11vnc: `docker compose exec ib-gateway supervisorctl restart x11vnc`

### API port not responding after login
- Verify socket port is configured in Gateway UI (Configure → Settings → API)
- Default live port: `4001`, paper port: `4002`

### IBC shows "already running" error
- `docker compose restart`

### Weekly 2FA not triggering on Sunday
- Confirm `ColdRestartTime` is set to a time after 01:00 ET in your local timezone
- The container must have been running continuously since before the cold restart time

## Moving to Another Machine

```bash
# Save image
docker save asx-ib-ib-gateway | gzip > ib-gateway.tar.gz

# On target machine
docker load < ib-gateway.tar.gz
```

Copy `.env` and `docker-compose.yml` to the target. The `ib-settings` volume starts empty — reconfigure Gateway settings via VNC on first run.

## ASX Data Integration

The `asx-data` pipeline uses this Gateway for three purposes:

| Use | Script | Frequency |
|-----|--------|-----------|
| Warrant metadata (expiry, strike, underlying) | `fetch_options_ib.py` | Weekly Sun 6am AEST |
| Warrant EOD closing prices | `fetch_options_eod.py` | Weekdays 4pm AEST |
| Live stock/warrant prices | `asx-web /api/ibgw/*` | On-demand during market hours |

**Symbol mapping:** IB's `localSymbol` field equals the ASX warrant code exactly (e.g. `ACWOC`, `EXROB`). Scripts query IB by underlying symbol (e.g. `reqContractDetails(symbol='ACW', secType='WAR')`) and match results by `localSymbol`. This is how multiple warrants on the same underlying are disambiguated.

**Market data types:** Scripts call `reqMarketDataType(1)` (live data). IB falls back to delayed automatically when market is closed or the account lacks a live data subscription.

## Architecture

```
Container
├── supervisord (PID 1)
│   ├── xvfb        — virtual display :1
│   ├── x11vnc      — VNC on :5900 → display :1
│   └── ibc         — IB Gateway controlled by IBC
│       └── start-gateway.sh
│           ├── detects TWS_MAJOR_VRSN from /root/Jts/ibgateway/
│           └── calls IBC scripts/displaybannerandlaunch.sh
└── volumes
    └── ib-settings → /root/Jts  (IB Gateway settings, persisted)
```
