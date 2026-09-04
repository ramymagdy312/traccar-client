import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:showcaseview/showcaseview.dart';

import '../preferences.dart';

/// Groups of walkthrough steps. Every chapter is played on the tab that owns
/// its targets so the highlighted widget is always the one on screen.
enum TourChapter {
  /// Account header and bottom navigation — chrome shared by every tab.
  home(tabIndex: 0),

  /// Service orders: search, status filters and the start / end action.
  services(tabIndex: 0),

  /// Live tracking: the master switch, quick actions and SOS.
  tracking(tabIndex: 1);

  const TourChapter({required this.tabIndex});

  final int tabIndex;
}

/// Anchors for every step of the walkthrough, in playback order.
abstract final class TourKeys {
  static final role = GlobalKey(debugLabel: 'tour.role');
  static final logout = GlobalKey(debugLabel: 'tour.logout');
  static final tabServices = GlobalKey(debugLabel: 'tour.tab.services');
  static final tabTracking = GlobalKey(debugLabel: 'tour.tab.tracking');
  static final tabSettings = GlobalKey(debugLabel: 'tour.tab.settings');

  static final search = GlobalKey(debugLabel: 'tour.search');
  static final filters = GlobalKey(debugLabel: 'tour.filters');
  static final serviceCard = GlobalKey(debugLabel: 'tour.service.card');
  static final serviceAction = GlobalKey(debugLabel: 'tour.service.action');

  static final trackingSwitch = GlobalKey(debugLabel: 'tour.tracking.switch');
  static final trackingActions = GlobalKey(debugLabel: 'tour.tracking.actions');
  static final sos = GlobalKey(debugLabel: 'tour.sos');

  static List<GlobalKey> of(TourChapter chapter) => switch (chapter) {
    TourChapter.home => [role, logout, tabServices, tabTracking, tabSettings],
    TourChapter.services => [search, filters, serviceCard, serviceAction],
    TourChapter.tracking => [trackingSwitch, trackingActions, sos],
  };

  /// The first step of a chapter has nothing to go back to, so the "back"
  /// action is hidden there.
  static bool startsChapter(GlobalKey key) =>
      TourChapter.values.any((chapter) => of(chapter).first == key);

  static bool endsTour(GlobalKey key) =>
      of(TourChapter.values.last).last == key;
}

/// Drives the guided walkthrough: plays each chapter on its own tab and
/// remembers that the driver has already seen it.
class ProductTour {
  ProductTour({required Future<void> Function(int tabIndex) selectTab})
    : _selectTab = selectTab;

  /// Isolated showcase scope so the tour never clashes with another overlay.
  static const String scope = 'product_tour';

  /// Bump when steps are added, so returning drivers are shown the tour again.
  static const int version = 1;

  /// Time given to a tab transition before the next chapter is highlighted.
  static const Duration _settleDelay = Duration(milliseconds: 320);

  final Future<void> Function(int tabIndex) _selectTab;

  Completer<void>? _chapter;
  bool _attached = false;
  bool _stopped = false;
  bool _running = false;

  bool get isRunning => _running;

  /// Whether the walkthrough still has to be played for the current [version].
  static bool get isPending =>
      (Preferences.instance.getInt(Preferences.productTourVersion) ?? 0) <
      version;

  static Future<void> markSeen() =>
      Preferences.instance.setInt(Preferences.productTourVersion, version);

  /// Registers the showcase scope. This has to run before the first [TourStep]
  /// in the subtree is built — the package throws when the scope is missing.
  void attach() {
    if (_attached) return;
    _attached = true;
    ShowcaseView.register(
      scope: scope,
      enableAutoScroll: true,
      scrollDuration: const Duration(milliseconds: 350),
      skipIfTargetNotPresent: true,
      onFinish: _closeChapter,
      onDismiss: (_) {
        _stopped = true;
        _closeChapter();
      },
    );
  }

  void detach() {
    if (!_attached) return;
    _stopped = true;
    _closeChapter();
    ShowcaseView.getNamed(scope).unregister();
    _attached = false;
  }

  /// Plays the whole walkthrough. Completes once the driver reaches the last
  /// step or skips out of it.
  Future<void> start() async {
    if (!_attached || _running) return;
    _running = true;
    _stopped = false;
    try {
      for (final chapter in TourChapter.values) {
        await _selectTab(chapter.tabIndex);
        await Future<void>.delayed(_settleDelay);
        if (_stopped || !_attached) break;
        await _play(TourKeys.of(chapter));
        if (_stopped || !_attached) break;
      }
    } finally {
      _running = false;
      await markSeen();
    }
  }

  Future<void> _play(List<GlobalKey> keys) {
    final view = ShowcaseView.getNamed(scope);
    // A chapter whose targets are all absent — an empty service list, for
    // instance — would never report completion, so only play what is built.
    final present = keys.where(view.isTargetRendered).toList();
    if (present.isEmpty) return Future<void>.value();

    final chapter = _chapter = Completer<void>();
    view.startShowCase(present);
    return chapter.future;
  }

  void _closeChapter() {
    final chapter = _chapter;
    _chapter = null;
    if (chapter != null && !chapter.isCompleted) chapter.complete();
  }
}

/// Exposes the tour to the screens that host its steps, so any of them can
/// replay it without reaching for a global.
class TourScope extends InheritedWidget {
  const TourScope({super.key, required this.tour, required super.child});

  final ProductTour tour;

  static ProductTour? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TourScope>()?.tour;

  @override
  bool updateShouldNotify(TourScope oldWidget) => tour != oldWidget.tour;
}
