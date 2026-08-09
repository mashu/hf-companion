import Toybox.Lang;
import Toybox.Communications;
import Toybox.Application;
import Toybox.PersistedContent;
import Toybox.Time;
import Toybox.System;

// Fetches and parses the N0NBH solar-terrestrial feed from hamqsl.com.
//
// CONNECTIVITY: like all Connect IQ apps, the web request travels over
// Bluetooth through the phone's Garmin Connect app - it does NOT use the
// Fenix 8 Pro's LTE/inReach (those are reserved for Garmin's own messaging and
// need a subscription). If the phone isn't connected we skip the request
// entirely to avoid an unnecessary phone data request.
//
// REFRESH POLICY is user-configurable in Garmin Connect (see settings.xml):
//   automaticRefreshEnabled = 0 (the default): never auto-fetch; the cache is shown
//            until the user taps.
//   automaticRefreshEnabled = 1: an explicit opt-in to refresh when opened, but
//            only if the cache is older than `autoRefreshMinutes`; a tap always
//            forces a refresh.
class SolarModel {

    const DATA_URL = "https://www.hamqsl.com/solarxml.php";

    // Minimum gap between *auto* fetch attempts (seconds) - throttle that
    // protects the battery if the feed is unreachable and the app is opened
    // and closed repeatedly. Manual refresh (force = true) is never throttled.
    const MIN_RETRY = 120;

    const KEY_XML  = "hfc_xml";
    const KEY_TIME = "hfc_time";

    // ---- status
    var status;        // :idle, :loading, :ok, :error, :nophone
    var errorCode;
    var lastCode;      // last HTTP/response code seen (diagnostics)
    var fetchCount;    // number of network requests issued (diagnostics)
    var hasData;
    var fetchedAt;
    var _lastAttempt;
    var _failed;       // latched true after a failed request; blocks auto-retry
                       // until the user manually refreshes

    // ---- parsed values
    var updated; var sfi; var sunspots; var aIndex; var kIndex;
    var xray; var aurora; var geomag; var signalNoise;
    var bands;

    var _cb;

    function initialize(callback) {
        _cb = callback;
        status = :idle;
        errorCode = null;
        lastCode = null;
        fetchCount = 0;
        hasData = false;
        fetchedAt = 0;
        _lastAttempt = 0;
        _failed = false;
        _resetBands();
    }

    function _resetBands() as Void {
        bands = [
            ["80-40m", null, null],
            ["30-20m", null, null],
            ["17-15m", null, null],
            ["12-10m", null, null]
        ];
    }

    // ---- settings ----------------------------------------------------------

    function automaticRefreshEnabled() as Boolean {
        var v = null;
        try { v = Application.Properties.getValue("automaticRefreshEnabled"); }
        catch (e) { v = null; }
        return v == 1;
    }

    function autoRefreshSeconds() as Number {
        var v = null;
        try { v = Application.Properties.getValue("autoRefreshMinutes"); }
        catch (e) { v = null; }
        if (v == null || v < 5) { v = 60; }
        return v * 60;
    }

    // ---- cache -------------------------------------------------------------

    function loadCache() as Void {
        var xml = Application.Storage.getValue(KEY_XML);
        var t   = Application.Storage.getValue(KEY_TIME);
        if (xml != null) {
            parse(xml);
            hasData = true;
            status = :ok;
            fetchedAt = (t == null) ? 0 : t;
        }
    }

    function now() as Number { return Time.now().value(); }

    function isStale() as Boolean {
        if (!hasData) { return true; }
        return (now() - fetchedAt) > autoRefreshSeconds();
    }

    function phoneConnected() as Boolean {
        var ds = System.getDeviceSettings();
        if (ds has :phoneConnected) { return ds.phoneConnected; }
        return true; // assume reachable if the device can't tell us
    }

    // True when auto-refresh is latched off after a failed request (diagnostics).
    function autoBlocked() as Boolean { return _failed; }

    // ---- fetch -------------------------------------------------------------

    function fetch(force as Boolean) as Void {
        if (status == :loading) { return; }

        if (!force) {
            // After a failed request we do NOT auto-retry - a failure latches
            // auto-fetch off until the user taps. This is the key guard against
            // a dead feed or flaky link draining the battery with repeated
            // background requests.
            if (_failed) { return; }
            if (!automaticRefreshEnabled()) { return; }
            if (!isStale()) { return; }                      // cache still fresh
            if ((now() - _lastAttempt) < MIN_RETRY) { return; } // throttle
        }

        // Connectivity guard: no phone link -> avoid a needless data request.
        if (!phoneConnected()) {
            _lastAttempt = now();
            status = :nophone;
            _notify();
            return;
        }

        _lastAttempt = now();
        status = :loading;
        fetchCount = fetchCount + 1;
        _notify();

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN
        };
        Communications.makeWebRequest(DATA_URL, {}, options, method(:onReceive));
    }

    function onReceive(responseCode as Number, data as Null or Dictionary or String or PersistedContent.Iterator) as Void {
        lastCode = responseCode;
        if (responseCode == 200 && data != null) {
            var xml = data.toString();
            parse(xml);
            hasData = true;
            status = :ok;
            fetchedAt = now();
            _failed = false;   // success re-enables auto-refresh
            Application.Storage.setValue(KEY_XML, xml);
            Application.Storage.setValue(KEY_TIME, fetchedAt);
        } else {
            status = :error;
            errorCode = responseCode;
            _failed = true;    // no auto-retry; wait for a manual tap
        }
        _notify();
    }

    function _notify() as Void {
        if (_cb != null) { _cb.invoke(); }
    }

    // ---- parsing -----------------------------------------------------------

    function parse(xml as String) as Void {
        updated     = inner(xml, "<updated>",     "</updated>");
        sfi         = inner(xml, "<solarflux>",   "</solarflux>");
        sunspots    = inner(xml, "<sunspots>",    "</sunspots>");
        aIndex      = inner(xml, "<aindex>",      "</aindex>");
        kIndex      = inner(xml, "<kindex>",      "</kindex>");
        xray        = inner(xml, "<xray>",        "</xray>");
        aurora      = inner(xml, "<aurora>",      "</aurora>");
        geomag      = inner(xml, "<geomagfield>", "</geomagfield>");
        signalNoise = inner(xml, "<signalnoise>", "</signalnoise>");

        bands = [
            ["80-40m", band(xml, "80m-40m", "day"), band(xml, "80m-40m", "night")],
            ["30-20m", band(xml, "30m-20m", "day"), band(xml, "30m-20m", "night")],
            ["17-15m", band(xml, "17m-15m", "day"), band(xml, "17m-15m", "night")],
            ["12-10m", band(xml, "12m-10m", "day"), band(xml, "12m-10m", "night")]
        ];
    }

    function inner(src as String, open as String, close as String) as String or Null {
        var i = src.find(open);
        if (i == null) { return null; }
        var rest = src.substring(i + open.length(), src.length());
        var k = rest.find(close);
        if (k == null) { return null; }
        return trim(rest.substring(0, k));
    }

    function band(src as String, name as String, time as String) as String or Null {
        var open = "<band name=\"" + name + "\" time=\"" + time + "\">";
        return inner(src, open, "</band>");
    }

    function trim(s as String or Null) as String or Null {
        if (s == null) { return null; }
        var chars = s.toCharArray();
        var start = 0;
        var end = chars.size();
        while (start < end && isSpace(chars[start])) { start++; }
        while (end > start && isSpace(chars[end - 1])) { end--; }
        return s.substring(start, end);
    }

    function isSpace(c as Char) as Boolean {
        return c == ' ' || c == '\n' || c == '\r' || c == '\t';
    }
}
