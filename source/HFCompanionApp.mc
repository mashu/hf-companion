import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Entry point. The class name here must match the `entry` attribute in
// manifest.xml ("HFCompanionApp").
class HFCompanionApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view together with its input delegate so button
    // presses and taps refresh the data.
    function getInitialView() {
        var view = new HFCompanionView();
        var delegate = new HFCompanionDelegate(view);
        return [view, delegate];
    }
}
