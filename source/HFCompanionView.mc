import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;

// The dashboard.
//
// SIGNATURE ELEMENT: a curved solar-flux gauge hugging the top bezel - the
// instrument language shared by Garmin's own faces and radio propagation
// meters. Real gradients (gauge sweep, glossy band pills, background, geomag
// arc) give it depth; everything is drawn programmatically (no image assets).
//
// BATTERY DESIGN (deliberate):
//   * Watch-APP, not a watch face: runs only while viewed; draws nothing once
//     the system returns to the watch face.
//   * No Timer, no animation loop. onUpdate runs only when the system asks or
//     the data model changes (fetch start / complete). CPU idles between draws.
//   * No background service, no temporal events -> zero wakeups when closed.
//   * No GPS / heart-rate / any sensor opened.
//   * Network travels over the phone via Bluetooth (no LTE/inReach), at most
//     once per the configured interval, only while open, and never when the
//     phone is disconnected (SolarModel connectivity guard).
//
// A MENU press toggles a diagnostics overlay (battery, memory, render time,
// request count) so the app can be profiled on the watch itself.
class HFCompanionView extends WatchUi.View {

    var _model;
    var _diag;
    var _updateCount;
    var _lastRenderMs;
    var _screen;

    function initialize() {
        View.initialize();
        _diag = false;
        _updateCount = 0;
        _lastRenderMs = 0;
        _screen = 0;
        _model = new SolarModel(method(:onModelUpdate));
        _model.loadCache();
    }

    function onModelUpdate() as Void { WatchUi.requestUpdate(); }
    function refresh() as Void {
        if (_screen == 0) { _model.fetch(true); }
    }
    function toggleDiagnostics() as Void {
        if (_screen == 0) {
            _diag = !_diag;
            WatchUi.requestUpdate();
        }
    }
    function toggleScreen() as Void {
        _screen = (_screen == 0) ? 1 : 0;
        if (_screen == 1) { _diag = false; }
        WatchUi.requestUpdate();
    }
    function onShow() as Void { _model.fetch(false); }
    function onHide() as Void {
        // Nothing to tear down: no timers/sensors/background work run here.
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var t0 = System.getTimer();
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        Gfx.vGradient(dc, 0, 0, w, h, Theme.BG_TOP, Theme.BG_BOTTOM, 2);

        if (_screen == 1) {
            drawMorseTable(dc, w, h);
        } else {
            drawSolarGauge(dc, cx, cy, w, h);
            drawSecondaryStats(dc, w, h);
            drawColumnGlyphs(dc, w, h);
            drawBands(dc, w, h);
            drawFooter(dc, cx, cy, w, h);
        }

        if (_diag) { drawDiagnostics(dc, w, h); }

        _lastRenderMs = System.getTimer() - t0;
        _updateCount = _updateCount + 1;
    }

    // Keep corner content clear of the circular AMOLED display's curved edge.
    // Central rows can use more width than the top and bottom safe areas.
    function roundInset(w, h) as Number {
        var side = (w < h) ? w : h;
        return (side * 0.125).toNumber();
    }

    // ---- morse code reference ---------------------------------------------

    function drawMorseTable(dc, w, h) as Void {
        var entries = [
            "A .-", "B -...", "C -.-.", "D -..", "E .", "F ..-.",
            "G --.", "H ....", "I ..",
            "J .---", "K -.-", "L .-..", "M --", "N -.", "O ---",
            "P .--.", "Q --.-", "R .-.",
            "1 .----", "2 ..---", "3 ...--", "4 ....-", "5 .....",
            "6 -....", "7 --...", "8 ---..", "9 ----.",
            "S ...", "T -", "U ..-", "V ...-", "W .--", "X -..-",
            "Y -.--", "Z --..", "0 -----"
        ];
        var margin = (0.105 * w).toNumber();
        var tableW = w - 2 * margin;
        var colW = tableW / 4;
        // Four columns turn the 36-entry reference into nine generous rows.
        // No title is needed, so the table can use the full round-safe height.
        var ruleTop = (0.180 * h).toNumber();
        var ruleBottom = (0.850 * h).toNumber();
        var rowsPerCol = 9;
        var rowH = (ruleBottom - ruleTop) / rowsPerCol;

        dc.setColor(Theme.ACCENT2, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(margin, ruleTop, w - margin, ruleTop);
        dc.drawLine(margin, ruleBottom, w - margin, ruleBottom);

        dc.setColor(Theme.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(margin + colW, ruleTop, margin + colW, ruleBottom);
        dc.drawLine(margin + colW * 2, ruleTop, margin + colW * 2, ruleBottom);
        dc.drawLine(margin + colW * 3, ruleTop, margin + colW * 3, ruleBottom);

        for (var i = 0; i < entries.size(); i++) {
            var col = i / rowsPerCol;
            var row = i % rowsPerCol;
            var x = margin + col * colW + (0.10 * colW).toNumber();
            var y = ruleTop + rowH * row + rowH / 2;
            var letter = entries[i].substring(0, 1);
            var code = entries[i].substring(2, entries[i].length());
            var codeFont = (col == 2) ? Graphics.FONT_XTINY : Graphics.FONT_TINY;
            // Two high-contrast hues distinguish the character from its Morse
            // sequence without relying on the former single green treatment.
            dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, Graphics.FONT_TINY, letter,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            // A fixed column gap keeps wide letters (M/W) clear while the
            // reordered numeric column prevents long codes from crowding edges.
            dc.setColor(0xFFD166, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + (0.37 * colW).toNumber(), y, codeFont, code,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // ---- top: solar-flux gauge + hero number ------------------------------

    function drawSolarGauge(dc, cx, cy, w, h) as Void {
        var label = "SOLAR FLUX";
        var lf = Graphics.FONT_XTINY;
        var ly = (0.105 * h).toNumber();
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, ly, lf, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        var lw = dc.getTextWidthInPixels(label, lf);
        dc.setColor(statusColor(), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - lw / 2 - 12, ly, 4);

        var s = (_model.sfi == null) ? "--" : _model.sfi;
        dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (0.190 * h).toNumber(), Graphics.FONT_LARGE, s,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function statusColor() as Number {
        if (_model.status == :ok)      { return Theme.GOOD_TOP; }
        if (_model.status == :loading) { return Theme.FAIR_TOP; }
        if (_model.status == :nophone) { return Theme.FAIR_TOP; }
        if (_model.status == :error)   { return Theme.POOR_TOP; }
        return Theme.MUTED;
    }

    // ---- secondary stats --------------------------------------------------

    function drawSecondaryStats(dc, w, h) as Void {
        // Separate hero number, labels, and values into independent vertical bands.
        var y = (0.325 * h).toNumber();
        drawStat(dc, (0.40 * w).toNumber(), y, "SSN", _model.sunspots);
        drawStat(dc, (0.60 * w).toNumber(), y, "K",   _model.kIndex);
    }

    function drawStat(dc, cx, y, label, value) as Void {
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y - 12, Graphics.FONT_XTINY, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        var s = (value == null) ? "--" : value;
        dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y + 12, Graphics.FONT_TINY, s,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---- day / night headers ----------------------------------------------

    function dayCenterX(w)   { return (0.64 * w).toNumber(); }
    function nightCenterX(w) { return (0.83 * w).toNumber(); }

    function drawColumnGlyphs(dc, w, h) as Void {
        var y = (0.420 * h).toNumber();
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dayCenterX(w), y, Graphics.FONT_XTINY, "DAY",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(nightCenterX(w), y, Graphics.FONT_XTINY, "NIGHT",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---- band rows --------------------------------------------------------

    function drawBands(dc, w, h) as Void {
        var yTop = (0.450 * h).toNumber();
        var rowH = (0.080 * h).toNumber();
        var labelX = (0.120 * w).toNumber();
        var chipW = (0.130 * w).toNumber();
        var chipH = (0.052 * h).toNumber();
        var cardX = (0.075 * w).toNumber();
        var cardW = w - 2 * cardX;
        var cardH = (0.070 * h).toNumber();

        var bands = _model.bands;
        for (var i = 0; i < bands.size(); i++) {
            var row = bands[i];
            var rowCy = yTop + rowH * i + rowH / 2;

            Gfx.gradientPill(dc, cardX, rowCy - cardH / 2, cardW, cardH,
                Theme.CARD_TOP, Theme.CARD_BOTTOM, 10);

            dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(labelX, rowCy, Graphics.FONT_TINY, row[0],
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

            drawPill(dc, dayCenterX(w),   rowCy, chipW, chipH, row[1]);
            drawPill(dc, nightCenterX(w), rowCy, chipW, chipH, row[2]);
        }
    }

    function drawPill(dc, cx, cy, pw, ph, cond) as Void {
        var x = cx - pw / 2;
        var y = cy - ph / 2;
        Gfx.gradientPill(dc, x, y, pw, ph,
            Theme.condTop(cond), Theme.condBottom(cond), (ph / 2).toNumber());
        dc.setColor(Theme.condTextColor(cond), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_XTINY, Theme.condLabel(cond),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---- footer -----------------------------------------------------------

    function drawFooter(dc, cx, cy, w, h) as Void {
        var geo = (_model.geomag == null) ? "--" : _model.geomag;
        var sn  = (_model.signalNoise == null) ? "--" : _model.signalNoise;
        dc.setColor(Theme.geomagTop(_model.geomag), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (0.795 * h).toNumber(), Graphics.FONT_XTINY,
            geo + "  S/N " + sn,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (_model.updated != null) {
            dc.setColor(Theme.MUTED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (0.865 * h).toNumber(), Graphics.FONT_XTINY,
                _model.updated,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // ---- diagnostics overlay (MENU) ---------------------------------------

    function drawDiagnostics(dc, w, h) as Void {
        var stats = System.getSystemStats();
        var used = (stats has :usedMemory)  ? stats.usedMemory  : 0;
        var total = (stats has :totalMemory) ? stats.totalMemory : 0;
        var batt = (stats has :battery) ? stats.battery : 0.0;

        var autoStr;
        if (!_model.automaticRefreshEnabled()) {
            autoStr = "manual only";
        } else if (_model.autoBlocked()) {
            autoStr = "paused (tap)";
        } else {
            autoStr = "on";
        }

        var lines = [
            "Battery   " + batt.format("%d") + "%",
            "Memory    " + kb(used) + " / " + kb(total) + " KB",
            "Render    " + _lastRenderMs + " ms",
            "Updates   " + _updateCount,
            "Requests  " + _model.fetchCount,
            "Last code " + (_model.lastCode == null ? "-" : _model.lastCode.toString()),
            "Phone     " + (_model.phoneConnected() ? "connected" : "away"),
            "Auto      " + autoStr
        ];

        var pw = (0.74 * w).toNumber();
        var ph = (0.66 * h).toNumber();
        var px = (w - pw) / 2;
        var py = (h - ph) / 2;

        dc.setColor(0x0D0F15, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(px, py, pw, ph, 14);
        dc.setColor(Theme.ACCENT2, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(px, py, pw, ph, 14);
        dc.setPenWidth(1);

        dc.drawText(w / 2, py + 18, Graphics.FONT_XTINY, "DIAGNOSTICS",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var lineH = (ph - 44) / lines.size();
        var tx = px + 22;
        var ty = py + 40;
        dc.setColor(Theme.WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(tx, ty + lineH * i + lineH / 2, Graphics.FONT_XTINY, lines[i],
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function kb(bytes) {
        return (bytes / 1024).toNumber();
    }
}
