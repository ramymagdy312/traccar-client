import 'package:flutter/material.dart';
import 'package:quick_actions/quick_actions.dart';

class QuickActionsInitializer extends StatefulWidget {
  const QuickActionsInitializer({super.key});

  @override
  State<QuickActionsInitializer> createState() => _QuickActionsInitializerState();
}

class _QuickActionsInitializerState extends State<QuickActionsInitializer> {
  final QuickActions quickActions = QuickActions();

  @override
  void initState() {
    super.initState();
    // Remove any previously registered quick actions from older versions.
    quickActions.setShortcutItems(const <ShortcutItem>[]);
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
