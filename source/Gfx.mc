import Toybox.Lang;
import Toybox.Graphics;
import Toybox.Math;

// Programmatic gradient + arc primitives. Everything is drawn with basic dc
// calls (no bitmaps), so it stays crisp at any size, uses no persistent memory,
// and only runs on the rare data-change redraw - keeping battery cost near zero.
module Gfx {

    // Linear interpolate between two 0xRRGGBB colours.
    function lerp(c1 as Number, c2 as Number, t as Float) as Number {
        if (t < 0.0) { t = 0.0; }
        if (t > 1.0) { t = 1.0; }
        var r1 = (c1 >> 16) & 0xFF; var g1 = (c1 >> 8) & 0xFF; var b1 = c1 & 0xFF;
        var r2 = (c2 >> 16) & 0xFF; var g2 = (c2 >> 8) & 0xFF; var b2 = c2 & 0xFF;
        var r = (r1 + (r2 - r1) * t).toNumber();
        var g = (g1 + (g2 - g1) * t).toNumber();
        var b = (b1 + (b2 - b1) * t).toNumber();
        return (r << 16) | (g << 8) | b;
    }

    // Vertical gradient fill, drawn as horizontal bands `step` px tall.
    function vGradient(dc as Graphics.Dc, x as Number, y as Number,
                       w as Number, h as Number,
                       cTop as Number, cBottom as Number, step as Number) as Void {
        var yy = y;
        while (yy < y + h) {
            var t = (yy - y).toFloat() / h;
            dc.setColor(lerp(cTop, cBottom, t), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, yy, w, step);
            yy += step;
        }
    }

    // Rounded pill (stadium) filled with a vertical gradient. Rounded ends are
    // produced by insetting each scanline along a circular profile, so corners
    // stay smooth without needing bitmaps or alpha.
    function gradientPill(dc as Graphics.Dc, x as Number, y as Number,
                          w as Number, h as Number,
                          cTop as Number, cBottom as Number, r as Number) as Void {
        if (r > h / 2) { r = h / 2; }
        if (r > w / 2) { r = w / 2; }
        var rf = r.toFloat();
        for (var i = 0; i < h; i += 1) {
            var inset = 0;
            if (i < r) {
                var dy = rf - i - 0.5;
                inset = (rf - Math.sqrt(rf * rf - dy * dy)).toNumber();
            } else if (i >= h - r) {
                var dy2 = i - (h - r) + 0.5;
                inset = (rf - Math.sqrt(rf * rf - dy2 * dy2)).toNumber();
            }
            if (inset < 0) { inset = 0; }
            var lineW = w - 2 * inset;
            if (lineW <= 0) { continue; }
            var t = i.toFloat() / (h - 1);
            dc.setColor(lerp(cTop, cBottom, t), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + inset, y + i, lineW, 1);
        }
    }

    // Point on a circle. Angle in degrees, 0 = east, 90 = north (screen top).
    function px(cx as Number, r as Number, deg as Float) as Number {
        return (cx + r * Math.cos(deg * Math.PI / 180.0)).toNumber();
    }
    function py(cy as Number, r as Number, deg as Float) as Number {
        return (cy - r * Math.sin(deg * Math.PI / 180.0)).toNumber();
    }

    // Solid arc of given thickness (single colour), rounded caps.
    function arc(dc as Graphics.Dc, cx as Number, cy as Number, radius as Number,
                 penW as Number, startDeg as Float, endDeg as Float,
                 color as Number) as Void {
        gradientArc(dc, cx, cy, radius, penW, startDeg, endDeg, color, color);
    }

    // Thick arc whose colour sweeps from c1 (start) to c2 (end), rounded caps.
    function gradientArc(dc as Graphics.Dc, cx as Number, cy as Number,
                         radius as Number, penW as Number,
                         startDeg as Float, endDeg as Float,
                         c1 as Number, c2 as Number) as Void {
        var segs = 48;
        var cw = (endDeg < startDeg);   // sweeping to a smaller angle = clockwise
        dc.setPenWidth(penW);
        for (var i = 0; i < segs; i += 1) {
            var a = startDeg + (endDeg - startDeg) * (i.toFloat() / segs);
            var b = startDeg + (endDeg - startDeg) * ((i + 1).toFloat() / segs);
            dc.setColor(lerp(c1, c2, i.toFloat() / segs), Graphics.COLOR_TRANSPARENT);
            if (cw) {
                dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, a, b - 0.6);
            } else {
                dc.drawArc(cx, cy, radius, Graphics.ARC_COUNTER_CLOCKWISE, a, b + 0.6);
            }
        }
        dc.setPenWidth(1);
        // rounded caps
        var cap = (penW / 2).toNumber();
        dc.setColor(c1, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(px(cx, radius, startDeg), py(cy, radius, startDeg), cap);
        dc.setColor(c2, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(px(cx, radius, endDeg), py(cy, radius, endDeg), cap);
    }
}
