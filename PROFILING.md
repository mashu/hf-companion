# Profiling HF Companion for battery & performance

Battery drain on a Connect IQ **watch-app** (as opposed to a watch face) comes
from three things while the app is open: CPU time per redraw, memory pressure,
and optional phone-network use. HF Companion is built to keep all three tiny.
This guide shows how to measure each, both in the simulator and on the watch.

## What can and can't be simulated

The Connect IQ simulator does **not** print an exact battery-drain percentage
for a foreground app. What it *does* give you is everything that drives drain:

- **CPU cost per redraw** — via the Monkey C **Profiler** (execution time and
  call counts per function).
- **Memory** — peak/used memory in the simulator's memory viewer.
- **Connectivity + battery states** — you can toggle the phone connection and
  set battery level to exercise every code path.

Because this app has **no timer and no animation loop**, its redraws happen only
on data change. So "CPU per redraw × number of redraws" is essentially the whole
active-CPU story, and the profiler measures it directly. Actual battery life is
then a short on-device confirmation (below).

## 1. CPU profiler (simulator)

1. Open the project in VS Code with the Monkey C extension.
2. `Ctrl/Cmd-Shift-P` → **"Monkey C: Run"** to launch the simulator on
   `fenix8pro51mm`.
3. `Ctrl/Cmd-Shift-P` → **"Monkey C: Start Profiler"**, interact with the app
   (let it load, tap to refresh, open the diagnostics overlay), then
   **"Monkey C: Stop Profiler"**.
4. Read the per-function table. The functions to watch are `onUpdate` and the
   `Gfx.*` gradient helpers. They should show a small average time and, crucially,
   a **low call count** — `onUpdate` is only invoked on data changes, not on a
   timer. If you ever see `onUpdate` being called continuously, that's a
   regression: something is requesting updates in a loop.

Official reference: https://developer.garmin.com/connect-iq/core-topics/profiling/

## 2. Memory (simulator)

In the simulator, open **File → View Memory** (or the memory gauge in the device
window). Note the peak. This app uses only programmatic drawing — no bitmap
resources beyond the launcher icon — so memory stays modest and flat; there's no
per-redraw allocation growth to watch for.

## 3. Connectivity paths (simulator)

Use the simulator's **connection** toggle to turn the phone link off, then open
the app: it should show "Phone not connected / Open Garmin Connect" and must
**not** issue a web request (the connectivity guard). Turn it back on and tap to
confirm a refresh succeeds. You can also force feed errors by pointing `DATA_URL`
at an unreachable host to verify the error messaging.

## 4. On-device diagnostics overlay (the profiler you can carry)

Press **MENU** on the watch (or in the simulator) to toggle a live overlay:

```
Battery    87%
Memory     41 / 128 KB
Render     3 ms          <- time the last onUpdate took
Updates    6             <- total redraws this session (should climb slowly)
Requests   1             <- network requests issued this session
Last code  200
Phone      connected
Auto       manual only
```

How to read it for battery:

- **Render** should be a few milliseconds. Redraws are rare, so even a larger
  number wouldn't dominate — but it confirms each draw is cheap.
- **Updates** should climb only when data changes or you interact, never on its
  own. Leave the app open and untouched for a minute: the counter should barely
  move. A steadily incrementing counter means something is redrawing on a timer.
- **Requests** should stay at 1 for a session (or 0 in Manual mode until you
  tap). It must never climb on its own — and after a failed request it will not
  auto-retry at all: the **Auto** line reads "paused (tap)" until you manually
  refresh. Verify this by pointing `DATA_URL` at a dead host, opening the app,
  then navigating away and back several times: **Requests** must not increase.

For a real battery figure: fully charge, note the battery %, leave the app open
and idle for 15–30 minutes with the overlay visible, and compare. Because there
are no timers, the drop reflects display-on cost, which is the same for any app
you'd leave open — the app itself adds almost nothing.

## 5. Controlling refresh frequency

**Data refresh → Manual only** is the default. The app will never fetch on its
own; it shows the cached reading and refreshes only when you tap. If you
explicitly select "When opened (opt-in, if stale)", raise **Min minutes between
auto refresh** (default 60) to reduce how often an open triggers a fetch.
