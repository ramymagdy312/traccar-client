import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Branded stand-in for [CircularProgressIndicator]: the mark turns left and
/// right the way a steering wheel does while work is in progress.
class BrandLoadingIndicator extends StatefulWidget {
  const BrandLoadingIndicator({
    super.key,
    this.size = 60,
    this.spinning = true,
    this.color,
  });

  /// Drawn size of the mark. The artwork is cropped to its bounds, so this is
  /// very nearly the diameter of the wheel on screen.
  final double size;

  /// When false the mark stays still so a parent can rotate it with the drag.
  final bool spinning;

  /// Tint for the mark. The artwork is a near-black silhouette, so it is
  /// always recoloured — defaulting to [ColorScheme.onSurface] keeps it
  /// legible in both themes. Pass the surrounding foreground colour when the
  /// indicator sits on anything other than a plain surface.
  final Color? color;

  @override
  State<BrandLoadingIndicator> createState() => _BrandLoadingIndicatorState();
}

class _BrandLoadingIndicatorState extends State<BrandLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(BrandLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning == oldWidget.spinning) return;
    if (widget.spinning) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    return RotationTransition(
      turns: Tween<double>(begin: -0.16, end: 0.16).animate(animation),
      child: Image.asset(
        'assets/ic_steering_wheel.png',
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        color: widget.color ?? Theme.of(context).colorScheme.onSurface,
        colorBlendMode: BlendMode.srcIn,
      ),
    );
  }
}

/// Pull-to-refresh that shows [BrandLoadingIndicator] instead of the
/// Material spinner.
class BrandRefreshIndicator extends StatefulWidget {
  const BrandRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final RefreshCallback onRefresh;
  final Widget child;

  @override
  State<BrandRefreshIndicator> createState() => _BrandRefreshIndicatorState();
}

class _BrandRefreshIndicatorState extends State<BrandRefreshIndicator>
    with SingleTickerProviderStateMixin {
  static const double _maxTravel = 156;
  static const double _badge = 76;

  /// Travel at which the gesture is considered strong enough to refresh.
  static const double _armAt = 96;

  late final AnimationController _travel = AnimationController(
    vsync: this,
    upperBound: 1,
    duration: const Duration(milliseconds: 340),
  )..addListener(() {
    if (mounted) setState(() {});
  });

  RefreshIndicatorStatus? _status;
  double _raw = 0;
  bool _buzzed = false;

  bool get _holding =>
      _status == RefreshIndicatorStatus.snap ||
      _status == RefreshIndicatorStatus.refresh;

  double get _offset => _travel.value * _maxTravel;

  void _follow(double raw) {
    _travel.stop();
    final eased = raw <= 108 ? raw : 108 + (raw - 108) * 0.28;
    _travel.value = (eased / _maxTravel).clamp(0.0, 1.0);

    // Confirm by touch the moment the pull is long enough to release.
    final armed = _offset >= _armAt;
    if (armed != _buzzed) {
      _buzzed = armed;
      if (armed) HapticFeedback.lightImpact();
    }
  }

  void _settle(double pixels) {
    _raw = pixels;
    _travel.animateTo(
      (pixels / _maxTravel).clamp(0.0, 1.0),
      curve: Curves.easeOutCubic,
    );
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (_holding) return false;

    final metrics = notification.metrics;
    if (notification is ScrollStartNotification) {
      _raw = 0;
      _buzzed = false;
    } else if (notification is ScrollUpdateNotification &&
        metrics.pixels < metrics.minScrollExtent) {
      _raw = metrics.minScrollExtent - metrics.pixels;
      _follow(_raw);
    } else if (notification is OverscrollNotification &&
        metrics.axisDirection == AxisDirection.down &&
        metrics.pixels <= metrics.minScrollExtent + 0.5) {
      _raw = (_raw - notification.overscroll).clamp(0.0, 420.0);
      _follow(_raw);
    } else if (notification is ScrollEndNotification) {
      _settle(0);
    }
    return false;
  }

  @override
  void dispose() {
    _travel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offset = _offset;
    final loading = _holding;
    final armed =
        loading || _status == RefreshIndicatorStatus.armed || offset >= _armAt;
    final progress = armed ? 1.0 : (offset / _armAt).clamp(0.0, 1.0);

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: Stack(
        children: [
          RefreshIndicator.noSpinner(
            onRefresh: widget.onRefresh,
            onStatusChange: (status) {
              if (!mounted) return;
              setState(() => _status = status);
              // Once the gesture is accepted the badge retracts and the page
              // itself takes over showing the reload.
              if (status != RefreshIndicatorStatus.drag &&
                  status != RefreshIndicatorStatus.armed) {
                _settle(0);
              }
            },
            child: Transform.translate(
              offset: Offset(0, offset),
              child: widget.child,
            ),
          ),
          if (offset > 2)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: offset,
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RefreshBadge(
                      progress: progress,
                      // Tied to raw travel rather than [progress], which
                      // pins at 1 once armed: the wheel has to wind back
                      // when the finger moves up again.
                      turns: offset / _armAt,
                      loading: loading,
                      armed: armed,
                      reveal: Curves.easeOut.transform(
                        (offset / 52).clamp(0.0, 1.0),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The puck that follows the finger: a floating disc carrying the steering
/// wheel. The wheel itself is the progress meter — it is geared to the drag,
/// winding one full turn by the time the pull is long enough to release and
/// unwinding again if the finger comes back up, then spins freely while the
/// refresh runs.
class _RefreshBadge extends StatefulWidget {
  const _RefreshBadge({
    required this.progress,
    required this.turns,
    required this.loading,
    required this.armed,
    required this.reveal,
  });

  final double progress;

  /// Revolutions the wheel has been turned by the drag. 1 is the release
  /// threshold; it keeps climbing past that and falls back as the pull eases.
  final double turns;

  final bool loading;
  final bool armed;
  final double reveal;

  @override
  State<_RefreshBadge> createState() => _RefreshBadgeState();
}

class _RefreshBadgeState extends State<_RefreshBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  /// Angle the drag left the wheel at, so the free spin picks up from there
  /// instead of snapping back to zero.
  double _spinFrom = 0;

  @override
  void initState() {
    super.initState();
    if (widget.loading) _sweep.repeat();
  }

  @override
  void didUpdateWidget(_RefreshBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading == oldWidget.loading) return;
    if (widget.loading) {
      _spinFrom = oldWidget.turns;
      _sweep.repeat();
    } else {
      _sweep.stop();
      _sweep.value = 0;
      _spinFrom = 0;
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const size = _BrandRefreshIndicatorState._badge;
    final charge = Curves.easeOutCubic.transform(widget.progress);

    return Opacity(
      opacity: widget.reveal,
      // Grows with the pull, then pops once the gesture is armed.
      child: Transform.scale(
        scale: 0.78 + 0.22 * charge,
        child: AnimatedScale(
          scale: widget.armed ? 1.06 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Tonal elevation: lifts off the page in dark mode, where a
              // drop shadow alone would be invisible.
              color: cs.surfaceContainerHigh,
              boxShadow: [
                // Ambient + key shadow so the puck reads as floating.
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.10),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.07),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: AnimatedBuilder(
                animation: _sweep,
                builder:
                    (context, child) => Transform.rotate(
                      angle:
                          (widget.loading
                              ? _spinFrom + _sweep.value
                              : widget.turns) *
                          2 *
                          math.pi,
                      child: child,
                    ),
                child: BrandLoadingIndicator(
                  size: 44,
                  spinning: false,
                  color: cs.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
