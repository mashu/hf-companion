# HF Companion — HF Propagation for Garmin Fenix 8 Pro

A stylish, dark, at-a-glance view of current HF band propagation conditions on
your wrist. Built for the **Fenix 8 Pro 51mm** (454×454 AMOLED) and works on any
round Connect IQ device.

Data comes from **N0NBH's solar-terrestrial feed** at
[hamqsl.com](https://www.hamqsl.com/solar.html) — the same source used by most
ham-radio propagation dashboards.

HF Companion is an informational companion for radio operators. It is **not
connected to, and cannot control or wake, a radio**.

## What it shows

- **SFI / SSN / K** — solar flux, sunspot number, planetary K-index.
- **Four HF band groups** (80-40m, 30-20m, 17-15m, 12-10m), each with a **day**
  (☀) and **night** (☾) condition chip, colour-coded:
  - GOOD = green, FAIR = amber, POOR = red, CLSD = grey.
- **Geomagnetic state** (QUIET / UNSETTLED / ACTIVE / STORM, colour-coded) and
  **signal-to-noise** estimate.
- **Feed timestamp**.

Press **START/ENTER** or **tap the screen** to fetch a fresh reading; press
**MENU** to toggle an on-watch diagnostics overlay. On launch the app shows the
last cached reading instantly and does not make a request by default.

## Connectivity

HF Companion reaches the internet the same way nearly every Connect IQ app does:
**over Bluetooth, through the Garmin Connect app on your phone.** It does *not*
use the Fenix 8 Pro's LTE or inReach — those are reserved for Garmin's own
messaging features and require a subscription; third-party apps can't send
web requests over them. All you need is:

- your phone nearby with **Garmin Connect running**, and
- the phone has internet.

When the phone is disconnected the app skips an explicitly requested refresh and
shows "Phone not connected — Open Garmin Connect." The only permission it
requests is **Communications**, shown when you install it. It does not request,
open, or wake GPS, heart-rate, or any other sensor.

**If a refresh fails, the app does not keep trying.** A failed request latches
the optional on-open refresh off until you tap to retry, so a dead feed or flaky
phone connection cannot cause repeated requests.

## Settings (in Garmin Connect → HF Companion)

- **Data refresh** — "Manual only (tap)" is the default. It never fetches on its
  own; the cached reading stays visible until you tap. "When opened (opt-in, if
  stale)" is available only if you explicitly want this behavior.
- **Min minutes between auto refresh** — used only for the opt-in on-open mode;
  default 60, minimum 15.
- **Operator location (optional)** — enter a short location label (up to 32
  characters) in Garmin Connect. Garmin Connect preserves the last value, so it
  remains the default next time you open settings. This is a manual label only:
  HF Companion does not use GPS.

## Battery & profiling

See [PROFILING.md](PROFILING.md) for how to measure CPU, memory, and battery in
the simulator and on the watch, including the built-in **MENU** diagnostics
overlay (battery, memory, render time, redraw count, request count).

## Design

The face is built around a single signature element: a curved **solar-flux
gauge** hugging the top bezel, filling clockwise as the flux rises — the
instrument language shared by Garmin's own faces and radio propagation meters.
Below it, the four HF band groups read as a carded list of glossy gradient
pills, and a second short arc across the bottom bezel encodes the geomagnetic
state. Everything (gauge sweep, pill gloss, background, geomag arc) is a real
gradient drawn programmatically — no image assets — so it stays crisp at any
size and adds nothing to memory or battery cost.

## Battery

Low power draw was a primary design goal. This is an **app you navigate to**, not
a watch face, so it consumes battery only while you're actively viewing it — the
watch returns to your normal face after its inactivity timeout and the app then
draws nothing.

What keeps it light:

- **No timers, no animation.** The screen is static; `onUpdate` runs only when
  the system asks or when new data arrives. The CPU is idle between draws.
- **No background service and no scheduled wakeups.** When the app is closed it
  does no work at all — nothing runs in the background.
- **No sensors.** GPS, heart-rate, and other sensors are never opened.
- **No automatic network requests by default.** The feed is cached to device
  storage and is fetched only when you tap. An on-open request is available as
  an explicit setting and is then limited by the configured interval. Failed
  requests never auto-retry.
- **AMOLED-friendly rendering.** True-black background (pixels off) with colour
  used sparingly as signal, so the panel draws little current on the rare redraw.

Net effect: opening it for a glance uses only a few screen draws; a small HTTPS
GET occurs only after you explicitly request a refresh (or opt in to on-open
refresh). Leaving the app costs nothing.

To verify on your own hardware, the Connect IQ simulator has a **power profiler**
(Simulation → Battery Drain / Profiler in the SDK) — run it against
`fenix8pro51mm` to see the estimated drain for a viewing session.

## Publishing to the Connect IQ Store

HF Companion is a `watch-app`, not a watch face. The manifest currently
packages `fenix8pro47mm` and `fenix8pro51mm`; add and test any additional
product ids before export.

The on-watch launcher artwork is
`resources/drawables/launcher_icon.png` (currently 80×80 PNG), referenced by
`resources/drawables/drawables.xml` and `manifest.xml`. The SDK's Fenix 8 Pro
device definition expects a 65×65 launcher icon, so replace this file with a
65×65 version before release rather than relying on scaling. Keep it as a
simple, high-contrast square image. This is separate from the Connect IQ Store artwork:
prepare an sRGB `500×500` cover icon (with 10px edge padding) for the web and
mobile store listing. Garmin also accepts optional `128×128` icons for the
on-device store: one full-colour OLED asset and one 64-colour MIP asset.

Export one signed `.iq` package containing all manifest targets with the
installed Docker SDK:

```sh
CIQ_UID=$(id -u) CIQ_GID=$(id -g) docker compose run --rm ciq bash -lc \
  'monkeyc -e -f monkey.jungle -o HFCompanion.iq -y .ciq/developer_key.der'
```

The installed Docker SDK inventory must recognise every product listed in
`manifest.xml`. At present it supplies `fenix8pro47mm` but not
`fenix8pro51mm`, so the export above is intentionally blocked until the 51mm
device package is installed through SDK Manager (or that unsupported target is
removed from the manifest). Do not submit a package claiming untested devices.

Keep `.ciq/developer_key.der` private and retain it permanently: future store
updates must be signed with the same key. Register a Garmin Developer account,
upload `HFCompanion.iq` at the Connect IQ developer portal, complete the
listing and privacy fields, upload screenshots, then submit for Garmin review.
The upload is validated before the listing fields become available.

## Build & sideload

You need the free **Connect IQ SDK** and the **Monkey C** extension for VS Code.

1. Install the SDK via the [Connect IQ SDK Manager](https://developer.garmin.com/connect-iq/sdk/)
   and download a **System 8 device** bundle that includes the Fenix 8 Pro (you
   need a recent SDK — API level 5.2.0 devices require SDK ≥ 8.3.0).
2. Open this folder in VS Code.
3. **Verify the product ids** (important — see caveat below):
   `Ctrl/Cmd-Shift-P` → **"Monkey C: Edit Products"** → search "fenix 8 pro" and
   tick the 51mm (and 47mm) entries. This rewrites `manifest.xml` with the exact
   ids the SDK expects.
4. Build a sideload package:
   `Ctrl/Cmd-Shift-P` → **"Monkey C: Build for Device"** → pick the Fenix 8 Pro.
   Or from the CLI:
   ```
   monkeyc -f monkey.jungle -d fenix8pro51mm -o HFCompanion.prg -y <your_developer_key.der>
   ```
5. Copy the resulting `HFCompanion.prg` to `GARMIN/APPS/` on the watch over USB, then
   eject. It appears in the activity/app list.

To test without a watch: **"Monkey C: Run"** launches the simulator; use
**Simulation → Web Requests** if you need to inspect the HTTP call.

### Docker development environment

The SDK Manager bundled by Garmin is linked to the obsolete WebKitGTK 4.0
libraries. `Dockerfile` uses Ubuntu 22.04, the last Ubuntu LTS that provides
those exact libraries, so the host does not need legacy packages.

Run the following commands from the project directory:
```sh
cd /home/mateusz/HFCompanion
```
If running them elsewhere, replace `docker compose` with
`docker compose -f /home/mateusz/HFCompanion/compose.yaml`.

After changing the Docker files, rebuild with:
```sh
CIQ_UID=$(id -u) CIQ_GID=$(id -g) docker compose build
```
If this is the first run after a failed permission setup, reset the named
volumes before rebuilding. This discards any SDK downloads already stored in
the container:
```sh
docker compose down --volumes
CIQ_UID=$(id -u) CIQ_GID=$(id -g) docker compose build
```

1. Build the image and start the SDK Manager (this requires an X11 session):
   ```sh
   xhost +local:docker
   CIQ_UID=$(id -u) CIQ_GID=$(id -g) docker compose run --rm ciq \
     /opt/connectiq-sdk-manager/bin/sdkmanager
   ```
   Install an SDK (8.3.0 or newer) and the Fenix 8 Pro device package. The
   downloaded SDK is retained in Docker's `ciq-sdk` volume.
2. Generate a local signing key once:
   ```sh
   CIQ_UID=$(id -u) CIQ_GID=$(id -g) docker compose run --rm ciq scripts/ciq-keygen
   ```
   This writes private material under `.ciq/`, which is ignored by Git.
3. Build the app:
   ```sh
   CIQ_UID=$(id -u) CIQ_GID=$(id -g) docker compose run --rm ciq scripts/ciq-build
   ```

The installed Fenix 8 Pro bundle currently provides `fenix8pro47mm`, which is
the build helper's default target. Set `CIQ_DEVICE` after installing another
device package. The simulator is graphical; use the native SDK/VS Code
integration for the most reliable simulator and USB-device workflows.

#### Fenix 8 Pro 51mm simulator

SDK 9.2.0's currently installed device inventory does not include
`fenix8pro51mm`. Install it only if SDK Manager offers that exact device after
updating the SDK/device package. Keep the first command running, then use a
second terminal to load the app into that same simulator container:

```sh
CIQ_DEVICE=fenix8pro51mm CIQ_OUTPUT=HFCompanion-fenix8pro51mm.prg \
  docker compose run --rm ciq scripts/ciq-build

xhost +local:docker
CIQ_UID=$(id -u) CIQ_GID=$(id -g) docker compose run --rm --name ciq-sim ciq simulator
```

```sh
docker exec -d --user ciq ciq-sim bash -lc '
  sdk_root="$(< "$HOME/.Garmin/ConnectIQ/current-sdk.cfg")"
  exec "$sdk_root/bin/monkeydo" \
    /workspace/HFCompanion-fenix8pro51mm.prg fenix8pro51mm
'
```

## Two things to check if it doesn't work on the watch

1. **Product ids.** The ids in `manifest.xml` (`fenix8pro51mm`, `fenix8pro47mm`)
   are the expected values, but Connect IQ ids must match your SDK exactly. If a
   build error says a product id is invalid, use **"Monkey C: Edit Products"** to
   regenerate them (step 3 above).

2. **Response content-type.** The app requests the feed as `TEXT_PLAIN`. hamqsl
   serves it as `text/xml`, which the simulator and most firmware accept. If your
   device rejects it (you'll see a non-200 code on the status dot / splash), point
   `DATA_URL` in `source/SolarModel.mc` at a small proxy of your own that returns
   the same body with a `text/plain` or `application/json` content-type. The
   parser only needs the raw XML text.

## Files

```
manifest.xml                     app metadata, permissions, target devices
monkey.jungle                    build config
resources/strings/strings.xml    app name
resources/drawables/             launcher icon + drawable list
resources/settings/              refresh policy and manual location settings
source/HFCompanionApp.mc         entry point
source/HFCompanionView.mc        the dashboard (gauge, pills, diagnostics)
source/HFCompanionDelegate.mc    button / tap / menu handling
source/SolarModel.mc             fetch + parse + cache + refresh policy
source/Gfx.mc                    gradient + arc primitives (no bitmaps)
source/Theme.mc                  palette and condition→colour mapping
PROFILING.md                     how to measure CPU / memory / battery
```

## Credits & etiquette

Solar-terrestrial data © Paul L Herrman (N0NBH), hamqsl.com. Please keep the
1-hour refresh gate — it's what the feed asks of clients. Propagation
predictions are a guide only; the sure way to know a band is open is to get on
the air. 73!
