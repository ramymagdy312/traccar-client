import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:serb_tracker_client/geolocation_service.dart';
import 'package:serb_tracker_client/main.dart';
import 'package:serb_tracker_client/permissions/location_permission_service.dart';
import 'package:serb_tracker_client/preferences.dart';

import '../api/fleet_api.dart';
import '../l10n/app_localizations.dart';
import '../models/service_order.dart';

class ServicesListScreen extends StatefulWidget {
  const ServicesListScreen({super.key});

  @override
  State<ServicesListScreen> createState() => _ServicesListScreenState();
}

/// View states the screen can be in. Driven by a small set of source-of-truth
/// flags below; never set directly.
enum _ViewState { initialLoading, error, empty, content }

class _ServicesListScreenState extends State<ServicesListScreen> {
  final FleetApi _api = FleetApi();
  List<ServiceOrder> _allOrders = [];
  List<ServiceOrder> _filteredOrders = [];
  int _statusFilter = 0;

  // ── State source-of-truth flags ──
  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  String? _error;

  final TextEditingController _searchController = TextEditingController();

  static String _formatDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilter);
    _loadServices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Derive the current view state from the source-of-truth flags.
  /// Keeping this as a pure getter avoids accidental drift between flags.
  _ViewState get _viewState {
    if (_isLoading && !_hasLoadedOnce) return _ViewState.initialLoading;
    if (_error != null && _allOrders.isEmpty) return _ViewState.error;
    if (_filteredOrders.isEmpty) return _ViewState.empty;
    return _ViewState.content;
  }

  /// Fetch services. Re-entrancy is guarded by [_isLoading] so that the user
  /// cannot fire multiple requests by tapping reload repeatedly. On refresh
  /// from a populated list, we keep the existing data on screen until the
  /// new response arrives — no flicker — and surface failures via a SnackBar.
  Future<void> _loadServices() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final dateFrom = now.subtract(const Duration(days: 1));
      final dateTo = now.add(const Duration(days: 1));
      final list = await _api.getServiceOrders(
        dateFrom: _formatDate(dateFrom),
        dateTo: _formatDate(dateTo),
      );
      if (!mounted) return;
      setState(() {
        _allOrders = list;
        _isLoading = false;
        _hasLoadedOnce = true;
        _error = null;
      });
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _isLoading = false;
        _hasLoadedOnce = true;
        _error = message;
      });
      // Don't lose existing data on a refresh failure — keep it visible and
      // surface the error inline as a SnackBar instead.
      if (_allOrders.isNotEmpty) {
        messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _applyFilter();
    }
  }

  void _applyFilter() {
    String query = _searchController.text.trim().toLowerCase();
    int status = _statusFilter;

    _filteredOrders =
        _allOrders.where((o) {
          final matchStatus =
              status == 0 ||
              (status == 1 && o.trackerStatus == 0) ||
              (status == 2 && o.trackerStatus == 1) ||
              (status == 3 && o.trackerStatus == 2);
          if (!matchStatus) return false;
          if (query.isEmpty) return true;
          return (o.sONo.toLowerCase().contains(query)) ||
              (o.custName?.toLowerCase().contains(query) ?? false) ||
              (o.localRef?.toLowerCase().contains(query) ?? false) ||
              (o.carNo?.toLowerCase().contains(query) ?? false) ||
              (o.transName?.toLowerCase().contains(query) ?? false);
        }).toList();

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.servicesListTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showSearchDialog(),
                ),
              ],
            ),
          ),
          _buildFilterChips(theme),
          Expanded(child: _buildBody(colorScheme)),
        ],
      ),
    );
  }

  Map<int, int> _countsForCurrentQuery() {
    final query = _searchController.text.trim().toLowerCase();
    final source =
        query.isEmpty
            ? _allOrders
            : _allOrders.where((o) {
              return (o.sONo.toLowerCase().contains(query)) ||
                  (o.custName?.toLowerCase().contains(query) ?? false) ||
                  (o.localRef?.toLowerCase().contains(query) ?? false) ||
                  (o.carNo?.toLowerCase().contains(query) ?? false) ||
                  (o.transName?.toLowerCase().contains(query) ?? false);
            }).toList();

    final all = source.length;
    final notStarted = source.where((o) => o.trackerStatus == 0).length;
    final inProgress = source.where((o) => o.trackerStatus == 1).length;
    final completed = source.where((o) => o.trackerStatus == 2).length;
    return {0: all, 1: notStarted, 2: inProgress, 3: completed};
  }

  Widget _buildFilterChips(ThemeData theme) {
    final counts = _countsForCurrentQuery();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(theme, 0, _filterLabels[0], counts[0] ?? 0),
            const SizedBox(width: 10),
            _filterChip(theme, 1, _filterLabels[1], counts[1] ?? 0),
            const SizedBox(width: 10),
            _filterChip(theme, 2, _filterLabels[2], counts[2] ?? 0),
            const SizedBox(width: 10),
            _filterChip(theme, 3, _filterLabels[3], counts[3] ?? 0),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(ThemeData theme, int value, String label, int count) {
    final selected = _statusFilter == value;
    final cs = theme.colorScheme;
    final badgeBg = selected ? cs.primary : cs.surfaceContainerHighest;
    final badgeFg = selected ? cs.onPrimary : cs.primary;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelMedium?.copyWith(
                color: badgeFg,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      selected: selected,
      onSelected:
          (_) => setState(() {
            _statusFilter = value;
            _applyFilter();
          }),
      selectedColor: cs.primaryContainer,
      checkmarkColor: cs.primary,
      showCheckmark: false,
    );
  }

  List<String> get _filterLabels {
    final l = AppLocalizations.of(context)!;
    return [
      l.filterAll,
      l.filterNotStarted,
      l.filterInProgress,
      l.filterCompleted,
    ];
  }

  Widget _buildBody(ColorScheme colorScheme) {
    final l = AppLocalizations.of(context)!;

    // Smooth transitions between Loading / Error / Empty / Content states.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder:
          (child, animation) =>
              FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(
        key: ValueKey(_viewState),
        child: switch (_viewState) {
          _ViewState.initialLoading => const Center(
            child: CircularProgressIndicator(),
          ),
          _ViewState.error => _ScrollablePlaceholder(
            onRefresh: _loadServices,
            child: _StatePlaceholder(
              icon: Icons.cloud_off_rounded,
              iconColor: colorScheme.error,
              title: l.failedToLoadTitle,
              subtitle: _error,
              buttonLabel: l.retryButton,
              buttonIcon: Icons.replay_rounded,
              onPressed: _loadServices,
              isBusy: _isLoading,
            ),
          ),
          _ViewState.empty => _ScrollablePlaceholder(
            onRefresh: _loadServices,
            child: _StatePlaceholder(
              icon: Icons.inbox_rounded,
              iconColor: colorScheme.primary,
              title: l.noServices,
              subtitle: l.emptyServicesHint,
              buttonLabel: l.reloadButton,
              onPressed: _loadServices,
              isBusy: _isLoading,
            ),
          ),
          _ViewState.content => RefreshIndicator(
            onRefresh: _loadServices,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredOrders.length,
              itemBuilder: (context, index) {
                final child = _ServiceOrderCard(
                  order: _filteredOrders[index],
                  colorScheme: colorScheme,
                  startLabel: l.startButton,
                  endLabel: l.endButton,
                  onStart: () => _onStartOrder(_filteredOrders[index]),
                  onEnd: () => _onEndOrder(_filteredOrders[index]),
                );

                final disableAnimations =
                    MediaQuery.maybeOf(context)?.disableAnimations ?? false;
                if (disableAnimations) return child;

                // Subtle staggered entrance (fade + slide) for a production feel.
                final delayMs = (index.clamp(0, 8)) * 35;
                return TweenAnimationBuilder<double>(
                  key: ValueKey(
                    'order_${_filteredOrders[index].sOSubId}_${_filteredOrders[index].trackerStatus}',
                  ),
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 320 + delayMs),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) {
                    final y = (1 - t) * 10;
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, y),
                        child: child,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        },
      ),
    );
  }

  void _showSearchDialog() {
    final l = AppLocalizations.of(context)!;
    final controller = _searchController;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 4,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.searchTitle,
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l.searchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final hasText = value.text.trim().isNotEmpty;
                      if (!hasText) return const SizedBox.shrink();
                      return IconButton(
                        tooltip: l.clearButton,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          controller.clear();
                          _applyFilter();
                        },
                      );
                    },
                  ),
                ),
                onChanged: (_) => _applyFilter(),
                onSubmitted: (_) => Navigator.pop(ctx),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        controller.clear();
                        _applyFilter();
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.onSurface,
                        side: BorderSide(color: cs.outlineVariant),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(l.clearButton),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(l.okButton),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  int? get _repId {
    final s = Preferences.instance.getString(Preferences.id);
    return int.tryParse(s ?? '');
  }

  /// RepMan can close without odometer input; Driver / empty roles must enter it on end.
  bool get _isRepMan {
    final raw = Preferences.instance.getString(Preferences.roles) ?? '';
    if (raw.isEmpty) return false;
    return raw
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .contains('repman');
  }

  bool get _requiresMeterInput => !_isRepMan;

  /// Start: confirmation only — meter is shown read-only for the driver to review.
  void _onStartOrder(ServiceOrder order) {
    final l = AppLocalizations.of(context)!;
    final startMeter = order.maxKM ?? 0;
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l.confirmStartTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${l.referenceLabel}: ${order.localRef ?? order.sONo}'),
                const SizedBox(height: 4),
                Text('${l.serviceTypeLabel}: ${order.transName ?? "-"}'),
                const SizedBox(height: 8),
                Text(
                  '${l.startMeterLabel}: $startMeter ${l.kmLabel}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.cancelButton),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _submitStart(order, startMeter);
                },
                child: Text(l.startButton),
              ),
            ],
          ),
    );
  }

  void _submitStart(ServiceOrder order, int meter) async {
    final l = AppLocalizations.of(context)!;
    final repId = _repId;
    if (repId == null || repId == 0) {
      messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(l.repIdMissing)),
      );
      return;
    }
    try {
      final coords = await _resolveServiceCoords();
      if (coords == null) return;
      await _api.updateServiceStatus(
        repId: repId,
        sOSubId: order.sOSubId,
        status: 1,
        startMeter: meter,
        endMeter: 0,
        lat: coords.lat,
        lng: coords.lng,
      );
      if (!mounted) return;
      messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(l.serviceStarted)),
      );
      await _loadServices();
    } catch (e) {
      if (!mounted) return;
      messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _onEndOrder(ServiceOrder order) {
    if (_requiresMeterInput) {
      _showEndMeterDialog(order);
    } else {
      _showEndConfirmDialog(order);
    }
  }

  void _showEndConfirmDialog(ServiceOrder order) {
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l.confirmEndTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${l.referenceLabel}: ${order.localRef ?? order.sONo}'),
                const SizedBox(height: 4),
                Text('${l.serviceTypeLabel}: ${order.transName ?? "-"}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.cancelButton),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _submitEnd(order, 0);
                },
                child: Text(l.endButton),
              ),
            ],
          ),
    );
  }

  void _showEndMeterDialog(ServiceOrder order) {
    final l = AppLocalizations.of(context)!;
    final startMeter = order.maxKM ?? 0;
    final controller = TextEditingController(text: '$startMeter');
    final key = GlobalKey<_MeterDialogState>();

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l.endMeterTitle),
            content: _MeterDialog(
              key: key,
              startMeter: startMeter,
              controller: controller,
              l10n: l,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.cancelButton),
              ),
              FilledButton(
                onPressed: () {
                  final state = key.currentState;
                  if (state == null) return;
                  final meter = int.tryParse(controller.text.trim());
                  final err = state.validateEnd(meter);
                  if (err != null) {
                    state.setError(err);
                    return;
                  }
                  Navigator.pop(ctx);
                  _submitEnd(order, meter!);
                },
                child: Text(l.endButton),
              ),
            ],
          ),
    );
  }

  void _submitEnd(ServiceOrder order, int meter) async {
    final l = AppLocalizations.of(context)!;
    final repId = _repId;
    if (repId == null || repId == 0) {
      messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(l.repIdMissing)),
      );
      return;
    }
    try {
      final coords = await _resolveServiceCoords();
      if (coords == null) return;
      await _api.updateServiceStatus(
        repId: repId,
        sOSubId: order.sOSubId,
        status: 2,
        startMeter: 0,
        endMeter: meter,
        lat: coords.lat,
        lng: coords.lng,
      );
      if (!mounted) return;
      messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(l.serviceEnded)),
      );
      await _loadServices();
    } catch (e) {
      if (!mounted) return;
      messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  /// Runs the disclosure + permission flow, then fetches a real GPS fix.
  /// Returns `null` (and shows feedback) when location cannot be obtained —
  /// never falls back to `0.0` for service start/end.
  Future<({double lat, double lng})?> _resolveServiceCoords() async {
    final l = AppLocalizations.of(context)!;
    final access = await LocationPermissionService.ensureAccess(
      context,
      requireBackground: false,
    );
    if (!mounted) return null;

    if (access == LocationAccessResult.disclosureDeclined) {
      messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(l.locationRequiredForService)),
      );
      return null;
    }
    if (access == LocationAccessResult.denied) {
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(l.locationRequiredForService),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: l.settingsTitle,
            onPressed: () => AppSettings.openAppSettings(
              type: AppSettingsType.settings,
            ),
          ),
        ),
      );
      return null;
    }

    final coords = await GeolocationService.fetchCoords();
    if (!mounted) return null;
    if (coords == null) {
      messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(l.locationUnavailableForService)),
      );
      return null;
    }
    return coords;
  }
}

class _MeterDialog extends StatefulWidget {
  final int startMeter;
  final TextEditingController controller;
  final AppLocalizations l10n;

  const _MeterDialog({
    super.key,
    required this.startMeter,
    required this.controller,
    required this.l10n,
  });

  @override
  State<_MeterDialog> createState() => _MeterDialogState();
}

class _MeterDialogState extends State<_MeterDialog> {
  String? _error;
  int? _diff;

  void setError(String msg) {
    setState(() => _error = msg);
  }

  String? validateEnd(int? meter) {
    final l = widget.l10n;
    if (meter == null) return l.enterValidNumber;
    if (meter < widget.startMeter) return l.endMeterLessThanStart;
    final d = meter - widget.startMeter;
    if (d >= 2000) return l.distanceTooLargeMax;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l10n;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${l.startMeterLabel}: ${widget.startMeter} ${l.kmLabel}'),
          const SizedBox(height: 12),
          TextField(
            controller: widget.controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l.endMeterLabel,
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) {
              setState(() {
                _error = null;
                final end = int.tryParse(v.trim());
                if (end != null && end >= widget.startMeter) {
                  _diff = end - widget.startMeter;
                  if (_diff! >= 2000) _error = l.distanceTooLarge;
                } else {
                  _diff = null;
                }
              });
            },
          ),
          if (_diff != null && _diff! < 2000)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l.distanceKm(_diff!),
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }
}

class _ServiceOrderCard extends StatelessWidget {
  final ServiceOrder order;
  final ColorScheme colorScheme;
  final String startLabel;
  final String endLabel;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  const _ServiceOrderCard({
    required this.order,
    required this.colorScheme,
    required this.startLabel,
    required this.endLabel,
    required this.onStart,
    required this.onEnd,
  });

  String _statusLabel(AppLocalizations l, int status) {
    switch (status) {
      case 1:
        return l.filterInProgress;
      case 2:
        return l.filterCompleted;
      case 0:
      default:
        return l.filterNotStarted;
    }
  }

  ({
    Color accent,
    Color accentAlt,
    Color container,
    Color onContainer,
    IconData icon,
  })
  _statusPalette(ColorScheme cs, Brightness brightness, int status) {
    final isDark = brightness == Brightness.dark;
    switch (status) {
      case 1:
        return (
          accent: isDark ? const Color(0xFFE57373) : cs.error,
          accentAlt: isDark ? const Color(0xFFFF8A65) : const Color(0xFFE57373),
          container: cs.errorContainer,
          onContainer: cs.onErrorContainer,
          icon: Icons.play_arrow_rounded,
        );
      case 2:
        return (
          accent: isDark ? const Color(0xFF43A047) : const Color(0xFF2E7D32),
          accentAlt: isDark ? const Color(0xFF66BB6A) : const Color(0xFF43A047),
          container: isDark ? const Color(0xFF16361C) : const Color(0xFFE8F5E9),
          onContainer:
              isDark ? const Color(0xFFB7F0C2) : const Color(0xFF1B5E20),
          icon: Icons.check_circle_rounded,
        );
      case 0:
      default:
        return (
          accent: cs.primary,
          accentAlt: isDark ? const Color(0xFF4DD0E1) : cs.tertiary,
          container: cs.primaryContainer,
          onContainer: cs.onPrimaryContainer,
          icon: Icons.schedule_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = order.trackerStatus;
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final palette = _statusPalette(colorScheme, brightness, status);
    final btnText = status == 1 ? endLabel : startLabel;
    final btnAction = status == 2 ? null : (status == 1 ? onEnd : onStart);
    final localeIsArabic = Localizations.localeOf(context).languageCode == 'ar';

    final surface = colorScheme.surface;
    final overlay = palette.accent.withValues(alpha: isDark ? 0.08 : 0.04);
    final cardBg = Color.alphaBlend(overlay, surface);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: cardBg,
      elevation: isDark ? 2 : 1,
      shadowColor: palette.accent.withValues(alpha: isDark ? 0.3 : 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: palette.accent.withValues(alpha: isDark ? 0.25 : 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header with gradient accent bar ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  palette.accent.withValues(alpha: isDark ? 0.2 : 0.12),
                  palette.accentAlt.withValues(alpha: isDark ? 0.08 : 0.04),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        palette.accent.withValues(alpha: 0.9),
                        palette.accentAlt.withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: palette.accent.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(palette.icon, size: 15, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        _statusLabel(l, status),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Time / date
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: isDark ? 0.6 : 0.7,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        (order.pickupTime != null &&
                                order.pickupTime!.isNotEmpty)
                            ? order.pickupTime!
                            : order.sODate,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body content ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order number
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: palette.accent.withValues(
                          alpha: isDark ? 0.15 : 0.1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        size: 20,
                        color: palette.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.sONo,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (order.localRef != null &&
                              order.localRef!.isNotEmpty)
                            Text(
                              order.localRef!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Customer & service type
                if (order.custName != null && order.custName!.isNotEmpty)
                  _DetailRow(
                    icon: Icons.business_rounded,
                    text: order.custName!,
                    colorScheme: colorScheme,
                    accentColor: palette.accent,
                  ),
                if (order.transName != null && order.transName!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _DetailRow(
                    icon: Icons.local_shipping_rounded,
                    text: order.transName!,
                    colorScheme: colorScheme,
                    accentColor: palette.accent,
                  ),
                ],

                const SizedBox(height: 14),

                // Info chips in a neat grid
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.calendar_month_rounded,
                      text: order.sODate,
                      colorScheme: colorScheme,
                    ),
                    _InfoChip(
                      icon: Icons.person_rounded,
                      text: '${l.adultsLabel}: ${order.totalAdlt ?? 0}',
                      colorScheme: colorScheme,
                    ),
                    _InfoChip(
                      icon: Icons.child_care_rounded,
                      text: '${l.childrenLabel}: ${order.totalChd ?? 0}',
                      colorScheme: colorScheme,
                    ),
                    if (order.carNo != null && order.carNo!.isNotEmpty)
                      _InfoChip(
                        icon: Icons.directions_car_filled_rounded,
                        text: order.carNo!,
                        colorScheme: colorScheme,
                        accentColor: palette.accent,
                      ),
                    if (order.maxKM != null)
                      _InfoChip(
                        icon: Icons.speed_rounded,
                        text: '${order.maxKM} ${l.kmLabel}',
                        colorScheme: colorScheme,
                        accentColor: palette.accent,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Action button footer ──
          if (btnAction != null)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Align(
                alignment:
                    localeIsArabic
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                child: FilledButton(
                  onPressed: btnAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                    shadowColor: palette.accent.withValues(alpha: 0.4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        status == 1
                            ? Icons.stop_circle_rounded
                            : Icons.play_circle_fill_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(btnText),
                    ],
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final ColorScheme colorScheme;
  final Color accentColor;

  const _DetailRow({
    required this.icon,
    required this.text,
    required this.colorScheme,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accentColor.withValues(alpha: 0.7)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final ColorScheme colorScheme;
  final Color? accentColor;

  const _InfoChip({
    required this.icon,
    required this.text,
    required this.colorScheme,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasAccent = accentColor != null;
    final bg =
        hasAccent
            ? accentColor!.withValues(alpha: isDark ? 0.15 : 0.08)
            : colorScheme.surfaceContainerHighest.withValues(
              alpha: isDark ? 0.6 : 0.7,
            );
    final fg = hasAccent ? accentColor! : colorScheme.onSurfaceVariant;
    final textColor =
        hasAccent
            ? (isDark ? accentColor! : accentColor!.withValues(alpha: 0.85))
            : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border:
            hasAccent
                ? Border.all(
                  color: accentColor!.withValues(alpha: isDark ? 0.3 : 0.2),
                )
                : Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: hasAccent ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable empty/error placeholder. Composes an icon, title, optional
/// subtitle and an optional action button. The button can show an inline
/// busy indicator and is automatically disabled when [isBusy] is true so that
/// rapid taps cannot fire concurrent requests.
class _StatePlaceholder extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final String? buttonLabel;
  final IconData buttonIcon;
  final VoidCallback? onPressed;
  final bool isBusy;

  const _StatePlaceholder({
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.buttonLabel,
    this.buttonIcon = Icons.refresh_rounded,
    this.onPressed,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = iconColor ?? cs.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: isDark ? 0.14 : 0.09),
              border: Border.all(
                color: accent.withValues(alpha: isDark ? 0.28 : 0.18),
              ),
            ),
            child: Icon(icon, size: 56, color: accent),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
          if (buttonLabel != null) ...[
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: isBusy ? null : onPressed,
              icon: isBusy
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: cs.onPrimary,
                      ),
                    )
                  : Icon(buttonIcon, size: 20),
              label: Text(buttonLabel!),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Wraps a placeholder so it lives inside a scrollable, enabling
/// pull-to-refresh on empty/error states with no list to scroll.
class _ScrollablePlaceholder extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const _ScrollablePlaceholder({required this.child, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: child),
            ),
          );
        },
      ),
    );
  }
}
