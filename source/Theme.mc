import Toybox.Lang;
import Toybox.Graphics;

// Palette tuned to the Fenix 8 Pro's AMOLED instrument look: deep near-black
// backgrounds with a cool cyan->teal accent, colour reserved for signal. Each
// condition carries a two-stop gradient so pills read as glossy, dimensional
// elements rather than flat blocks.
module Theme {
    // background gradient (subtle, top -> bottom)
    const BG_TOP    = 0x05070C;
    const BG_BOTTOM = 0x0A0F17;

    // accent (cyan -> teal), used for the solar-flux gauge and highlights
    const ACCENT1 = 0x16C7FF;   // cyan
    const ACCENT2 = 0x18E7B4;   // teal

    // structure / text
    const TRACK  = 0x222A34;    // dim gauge track
    const CARD_TOP    = 0x111520;
    const CARD_BOTTOM = 0x0A0D14;
    const WHITE  = 0xFFFFFF;
    const DIM    = 0x9AA4B0;     // cool grey secondary text
    const MUTED  = 0x59616C;     // tertiary / no-data

    // Condition colours pair a distinct hue with a symbol label:
    // blue = Good, orange = Fair, violet = Poor. This avoids red/green-only
    // meaning for colour-vision deficiencies.
    const GOOD_TOP = 0x6BD8FF;  const GOOD_BOT = 0x2878C8;
    const FAIR_TOP = 0xFFD166;  const FAIR_BOT = 0xD67A1D;
    const POOR_TOP = 0xD9A6FF;  const POOR_BOT = 0x7646A8;
    const CLSD_TOP = 0x4A515B;  const CLSD_BOT = 0x2A2F37;

    // ---- condition helpers -------------------------------------------------

    // 0 = Good, 1 = Fair, 2 = Poor, 3 = Closed / unknown
    function condIndex(cond as String or Null) as Number {
        if (cond == null) { return 3; }
        if (cond.equals("Good")) { return 0; }
        if (cond.equals("Fair")) { return 1; }
        if (cond.equals("Poor")) { return 2; }
        return 3;
    }

    function condTop(cond as String or Null) as Number {
        var i = condIndex(cond);
        if (i == 0) { return GOOD_TOP; }
        if (i == 1) { return FAIR_TOP; }
        if (i == 2) { return POOR_TOP; }
        return CLSD_TOP;
    }

    function condBottom(cond as String or Null) as Number {
        var i = condIndex(cond);
        if (i == 0) { return GOOD_BOT; }
        if (i == 1) { return FAIR_BOT; }
        if (i == 2) { return POOR_BOT; }
        return CLSD_BOT;
    }

    // Dark text on the bright (Good/Fair) pills, light text on Poor/Closed.
    function condTextColor(cond as String or Null) as Number {
        var i = condIndex(cond);
        if (i == 0 || i == 1) { return 0x07131C; }
        return 0xFFFFFF;
    }

    // Connect IQ's built-in bitmap fonts do not guarantee emoji glyphs, so use
    // unambiguous ASCII labels. Colour remains a second, independent cue.
    function condLabel(cond as String or Null) as String {
        var i = condIndex(cond);
        if (i == 0) { return "UP"; }
        if (i == 1) { return "OK"; }
        if (i == 2) { return "DN"; }
        return "--";
    }

    // ---- geomagnetic severity ---------------------------------------------

    function geomagTop(g as String or Null) as Number {
        if (g == null) { return MUTED; }
        var u = g.toUpper();
        if (u.find("STORM") != null || u.find("SEVERE") != null) { return POOR_TOP; }
        if (u.find("ACTIVE") != null || u.find("UNSETTLED") != null) { return FAIR_TOP; }
        if (u.find("QUIET") != null) { return GOOD_TOP; }
        return DIM;
    }

    function geomagBottom(g as String or Null) as Number {
        if (g == null) { return MUTED; }
        var u = g.toUpper();
        if (u.find("STORM") != null || u.find("SEVERE") != null) { return POOR_BOT; }
        if (u.find("ACTIVE") != null || u.find("UNSETTLED") != null) { return FAIR_BOT; }
        if (u.find("QUIET") != null) { return GOOD_BOT; }
        return MUTED;
    }
}
