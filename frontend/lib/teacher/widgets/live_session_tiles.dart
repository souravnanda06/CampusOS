part of '../screens/broadcasting_screen.dart';

/// Conditional amber glass BLE Notice strip shown only when a BLE error exists.
class _BleNoticeStrip extends StatelessWidget {
  final String errorText;
  final VoidCallback onRetry;

  const _BleNoticeStrip({
    required this.errorText,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _LiveGlassSurface(
      radius: _LiveTheme.bleNoticeRadius,
      fillTop: _LiveTheme.amberFill,
      fillBottom: _LiveTheme.amberFill,
      borderColor: _LiveTheme.amberBorder,
      topHighlightColor: _LiveTheme.amber.withValues(alpha: 0.24),
      padding: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 10.0),
      child: Row(
        children: [
          // Left 32px amber icon tile
          Container(
            width: 32.0,
            height: 32.0,
            decoration: ShapeDecoration(
              color: _LiveTheme.amberTileFill,
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.warning_amber_rounded,
              size: 18.0,
              color: _LiveTheme.amber,
            ),
          ),
          const SizedBox(width: 10.0),
          // Middle title + selectable/copyable exact error text (max 2 lines)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'BLE Notice',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: _LiveTheme.amberText,
                  ),
                ),
                const SizedBox(height: 2.0),
                SelectionArea(
                  child: Text(
                    errorText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      height: 1.3,
                      color: _LiveTheme.amberBody,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8.0),
          // Right 32px visual Retry pill inside >=44px tap target
          _TactilePress(
            onTap: onRetry,
            onHaptic: AppHaptics.lightImpact,
            semanticsLabel: 'Retry BLE broadcast',
            minWidth: 44.0,
            minHeight: 44.0,
            child: Container(
              height: 32.0,
              padding: const EdgeInsets.symmetric(horizontal: 11.0),
              decoration: BoxDecoration(
                color: _LiveTheme.amberTileFill,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: _LiveTheme.amber.withValues(alpha: 0.34),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.refresh_rounded,
                    size: 14.0,
                    color: _LiveTheme.amberText,
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    'Retry',
                    style: GoogleFonts.inter(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: _LiveTheme.amberText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 20px circular countdown ring starting at the top (12 o'clock).
class _RingTimer extends StatelessWidget {
  final double progress;

  const _RingTimer({
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: _LiveTheme.ringTimerSize,
        height: _LiveTheme.ringTimerSize,
        child: CustomPaint(
          painter: _RingTimerPainter(
            progress: progress.clamp(0.0, 1.0),
          ),
        ),
      ),
    );
  }
}

class _RingTimerPainter extends CustomPainter {
  final double progress;

  const _RingTimerPainter({
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2.0, size.height / 2.0);
    final double radius =
        (math.min(size.width, size.height) - _LiveTheme.ringTimerStroke) / 2.0;

    final Paint trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _LiveTheme.ringTimerStroke
      ..color = Colors.white.withValues(alpha: 0.14);
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0.0) return;

    final Paint arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _LiveTheme.ringTimerStroke
      ..strokeCap = StrokeCap.round
      ..color = _LiveTheme.accent;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2.0,
      2.0 * math.pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingTimerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Equal-width glass tile for Room PIN, Optical QR, and Hotspot methods.
class _MethodTile extends StatelessWidget {
  final String label;
  final Widget trailing;
  final String value;
  final String? unit;
  final String caption;
  final Color valueColor;
  final Color captionColor;
  final bool isHighlighted;
  final VoidCallback onTap;
  final VoidCallback? onHaptic;
  final String semanticsLabel;

  const _MethodTile({
    required this.label,
    required this.trailing,
    required this.value,
    this.unit,
    required this.caption,
    this.valueColor = _LiveTheme.textPrimary,
    this.captionColor = _LiveTheme.accent,
    this.isHighlighted = false,
    required this.onTap,
    this.onHaptic,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return _TactilePress(
      onTap: onTap,
      onHaptic: onHaptic ?? AppHaptics.selectionClick,
      semanticsLabel: semanticsLabel,
      child: _LiveGlassSurface(
        radius: _LiveTheme.methodTileRadius,
        height: _LiveTheme.methodTileHeight,
        fillTop: isHighlighted
            ? _LiveTheme.indigoRipple.withValues(alpha: 0.22)
            : null,
        fillBottom: isHighlighted
            ? _LiveTheme.indigoDeep.withValues(alpha: 0.12)
            : null,
        borderColor: isHighlighted
            ? _LiveTheme.accent.withValues(alpha: 0.45)
            : null,
        padding: const EdgeInsets.fromLTRB(12.0, 11.0, 11.0, 11.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top row: single-line 10px caps label + 20px ring timer or icon
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: GoogleFonts.inter(
                        fontSize: 10.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5, // 0.05em at 10px
                        color: _LiveTheme.textMuted60,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4.0),
                trailing,
              ],
            ),
            // Bottom group: single-baseline number + unit + caption
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            value,
                            maxLines: 1,
                            softWrap: false,
                            style: GoogleFonts.inter(
                              fontSize: 25.0,
                              fontWeight: FontWeight.w700,
                              height: 1.05,
                              letterSpacing: -0.5,
                              color: valueColor,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          if (unit != null) ...[
                            const SizedBox(width: 4.0),
                            Text(
                              unit!,
                              maxLines: 1,
                              softWrap: false,
                              style: GoogleFonts.inter(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w600,
                                color: _LiveTheme.textMuted60,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 3.0),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      caption,
                      maxLines: 1,
                      softWrap: false,
                      style: GoogleFonts.inter(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600,
                        color: captionColor,
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
