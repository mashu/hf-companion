import Toybox.Lang;
import Toybox.WatchUi;

// START/ENTER or a screen tap refreshes the propagation screen. A horizontal
// swipe or page button switches between propagation and the static Morse table.
// MENU toggles the propagation diagnostics overlay. BACK exits normally.
class HFCompanionDelegate extends WatchUi.BehaviorDelegate {

    var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        _view.refresh();
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        _view.refresh();
        return true;
    }

    function onMenu() as Boolean {
        _view.toggleDiagnostics();
        return true;
    }

    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        _view.toggleScreen();
        return true;
    }

    function onNextPage() as Boolean {
        _view.toggleScreen();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.toggleScreen();
        return true;
    }
}
