# HF Companion — HF Propagation for Garmin Fenix 8 Pro

A stylish, dark, at-a-glance view of current HF band propagation conditions on
your wrist. Built for the **Fenix 8 Pro 51mm** and **Fenix 8 51mm** (both
454×454 AMOLED), with their 47mm counterparts covered by Garmin's shared
Connect IQ product IDs.

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
`fenix8pro47mm`, which also represents Fenix 8 Pro 51mm, to see the estimated
drain for a viewing session.

## Publishing to the Connect IQ Store

HF Companion is a `watch-app`, not a watch face. The manifest packages the two
454×454 AMOLED product groups:

- `fenix8pro47mm` — Fenix 8 Pro **47mm and 51mm**.
- `fenix847mm` — non-Pro Fenix 8 **47mm and 51mm**.

Garmin uses the 47mm suffix as the shared Connect IQ identifier; there is no
separate `fenix8pro51mm` or `fenix851mm` product ID to add.

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
`manifest.xml`. SDK 9.2.0 provides both `fenix8pro47mm` and `fenix847mm`, which
cover the intended 51mm AMOLED models. The separately named
`fenix8solar51mm` is a 280×280 MIP device and is intentionally excluded.

Keep `.ciq/developer_key.der` private and retain it permanently: future store
updates must be signed with the same key. Register a Garmin Developer account,
upload `HFCompanion.iq` at the Connect IQ developer portal, complete the
listing and privacy fields, upload screenshots, then submit for Garmin review.
The upload is validated before the listing fields become available.

## Build & sideload

You need the free **Connect IQ SDK** and the **Monkey C** extension for VS Code.

1. Install the SDK via the [Connect IQ SDK Manager](https://developer.garmin.com/connect-iq/sdk/)
   and download a **System 8 device** bundle that includes Fenix 8 and Fenix 8
   Pro (API level 5.2.0 devices require SDK ≥ 8.3.0).
2. Open this folder in VS Code.
3. **Verify the product ids**:
   `Ctrl/Cmd-Shift-P` → **"Monkey C: Edit Products"** → select Fenix 8 Pro
   47mm and Fenix 8 47mm. Garmin uses these shared IDs for the corresponding
   51mm AMOLED models.
4. Build a sideload package:
   `Ctrl/Cmd-Shift-P` → **"Monkey C: Build for Device"** → pick Fenix 8 Pro
   47mm (for a Pro 51mm) or Fenix 8 47mm (for a non-Pro 51mm). Or from the CLI:
   ```
   monkeyc -f monkey.jungle -d fenix8pro47mm -o HFCompanion.prg -y <your_developer_key.der>
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
   Install an SDK (8.3.0 or newer) and the Fenix 8 / Fenix 8 Pro device
   package. The downloaded SDK is retained in Docker's `ciq-sdk` volume.
2. Generate a local signing key once:
   ```sh
   CIQ_UID=$(id -u) CIQ_GID=$(id -g) docker compose run --rm ciq scripts/ciq-keygen
   ```
   This writes private material under `.ciq/`, which is ignored by Git.
3. Build the app:
   ```sh
   CIQ_UID=$(id -u) CIQ_GID=$(id -g) docker compose run --rm ciq scripts/ciq-build
   ```

The installed Fenix 8 bundle provides `fenix8pro47mm` (Pro 47mm/51mm) and
`fenix847mm` (non-Pro 47mm/51mm). The build helper's default is
`fenix8pro47mm`; use `CIQ_DEVICE=fenix847mm` to build the non-Pro target. The
simulator is graphical; use the native SDK/VS Code integration for the most
reliable simulator and USB-device workflows.

#### Fenix 8 51mm target mapping

No additional SDK Manager package is needed for the 51mm AMOLED models. In
SDK 9.2.0, Garmin maps each 51mm watch to the same product definition as its
47mm sibling:

- Fenix 8 Pro 51mm → `fenix8pro47mm` (454×454 AMOLED)
- Fenix 8 51mm → `fenix847mm` (454×454 AMOLED)
- Fenix 8 Solar 51mm → `fenix8solar51mm` (280×280 MIP; not packaged)

## Two things to check if it doesn't work on the watch

1. **Product ids.** The current `manifest.xml` IDs are `fenix8pro47mm` and
   `fenix847mm`; both match SDK 9.2.0 and cover their 51mm AMOLED variants. If
   a build error says a product id is invalid, use **"Monkey C: Edit Products"**
   to select IDs recognised by that SDK.

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

## License

This project's source code is MIT-licensed; the Garmin Connect IQ SDK remains proprietary.

## Credits & etiquette

Solar-terrestrial data © Paul L Herrman (N0NBH), hamqsl.com. Please keep the
1-hour refresh gate — it's what the feed asks of clients. Propagation
predictions are a guide only; the sure way to know a band is open is to get on
the air. 73!
