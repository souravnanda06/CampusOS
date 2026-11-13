import 'package:flutter/material.dart';
import 'app_dock.dart';

export 'app_dock.dart' show AppDock, AppDockItem;

/// Backward-compatible alias for [AppDockItem].
typedef AppleDockItem = AppDockItem;

/// Backward-compatible wrapper that renders the modern Apple-style [AppDock].
class AppleGlassDock extends StatelessWidget {
  final List<AppleDockItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final double maxWidth;

  const AppleGlassDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.maxWidth = 440.0,
  });

  @override
  Widget build(BuildContext context) {
    return AppDock(
      items: items,
      currentIndex: currentIndex,
      onTap: onTap,
      maxWidth: maxWidth,
    );
  }
}
