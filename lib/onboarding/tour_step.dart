import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

import '../l10n/app_localizations.dart';
import 'product_tour.dart';

/// One step of the guided walkthrough.
///
/// Wrapping every target in this widget keeps the tooltip styling, the action
/// row and the highlight geometry identical across the whole tour.
class TourStep extends StatelessWidget {
  const TourStep({
    super.key,
    required this.stepKey,
    required this.title,
    required this.description,
    required this.child,
    this.targetRadius = 16,
    this.targetPadding = const EdgeInsets.all(6),
    this.tooltipPosition,
  });

  final GlobalKey stepKey;
  final String title;
  final String description;
  final Widget child;

  /// Corner radius of the cut-out drawn around the target.
  final double targetRadius;

  /// Breathing room between the target and the cut-out edge.
  final EdgeInsets targetPadding;

  /// Forces the tooltip to a side. Left null the package picks the side with
  /// the most free space.
  final TooltipPosition? tooltipPosition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final direction = Directionality.of(context);

    return Showcase(
      key: stepKey,
      scope: ProductTour.scope,
      title: title,
      description: description,
      titleTextDirection: direction,
      descriptionTextDirection: direction,
      titleAlignment: AlignmentDirectional.centerStart,
      descriptionAlignment: AlignmentDirectional.centerStart,
      titleTextStyle: theme.textTheme.titleMedium?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w800,
        height: 1.25,
      ),
      descTextStyle: theme.textTheme.bodyMedium?.copyWith(
        color: cs.onSurfaceVariant,
        height: 1.45,
      ),
      titlePadding: const EdgeInsets.only(bottom: 6),
      tooltipBackgroundColor: cs.surfaceContainerHigh,
      textColor: cs.onSurface,
      tooltipPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      tooltipBorderRadius: BorderRadius.circular(20),
      tooltipPosition: tooltipPosition,
      targetPadding: targetPadding,
      targetBorderRadius: BorderRadius.circular(targetRadius),
      overlayColor: cs.scrim,
      overlayOpacity: 0.72,
      blurValue: 1.5,
      toolTipMargin: 16,
      targetTooltipGap: 14,
      tooltipActionConfig: const TooltipActionConfig(
        position: TooltipActionPosition.inside,
        alignment: MainAxisAlignment.spaceBetween,
        gapBetweenContentAndAction: 16,
        actionGap: 8,
      ),
      tooltipActions: _actions(context, theme),
      child: child,
    );
  }

  List<TooltipActionButton> _actions(BuildContext context, ThemeData theme) {
    final l = AppLocalizations.of(context)!;
    final cs = theme.colorScheme;
    final label = theme.textTheme.labelLarge ?? const TextStyle(fontSize: 14);

    return [
      TooltipActionButton(
        type: TooltipDefaultActionType.skip,
        name: l.tourSkipButton,
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        textStyle: label.copyWith(color: cs.onSurfaceVariant),
      ),
      if (!TourKeys.startsChapter(stepKey))
        TooltipActionButton(
          type: TooltipDefaultActionType.previous,
          name: l.tourBackButton,
          backgroundColor: Colors.transparent,
          border: Border.all(color: cs.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          textStyle: label.copyWith(color: cs.onSurface),
        ),
      TooltipActionButton(
        type: TooltipDefaultActionType.next,
        name: TourKeys.endsTour(stepKey) ? l.tourDoneButton : l.tourNextButton,
        backgroundColor: cs.primary,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        textStyle: label.copyWith(
          color: cs.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ];
  }
}
