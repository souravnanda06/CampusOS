import 'package:flutter/material.dart';
import '../../theme/mesh_theme.dart';

/// Amber Warning Card inside a message bubble for content moderation safety.
///
/// Features:
/// - Amber background (#FFF3DC), ring (#F2C77B), text (#7A4A00)
/// - Warning triangle icon
/// - "Hidden · abusive language" header & sub-line
/// - AnimatedCrossFade reveal toggle when tapped
class FlaggedMessage extends StatefulWidget {
  final String text;
  final String? customReason;
  final bool initialRevealed;
  final ValueChanged<bool>? onRevealChanged;

  const FlaggedMessage({
    super.key,
    required this.text,
    this.customReason,
    this.initialRevealed = false,
    this.onRevealChanged,
  });

  @override
  State<FlaggedMessage> createState() => _FlaggedMessageState();
}

class _FlaggedMessageState extends State<FlaggedMessage> {
  late bool _isRevealed;

  @override
  void initState() {
    super.initState();
    _isRevealed = widget.initialRevealed;
  }

  void _toggleReveal() {
    setState(() {
      _isRevealed = !_isRevealed;
    });
    widget.onRevealChanged?.call(_isRevealed);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.warningAmberBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.warningAmberRing,
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _toggleReveal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 240),
              firstCurve: Curves.easeOutCubic,
              secondCurve: Curves.easeInCubic,
              crossFadeState: _isRevealed
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: _buildHiddenWarning(),
              secondChild: _isRevealed ? _buildRevealedContent() : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHiddenWarning() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.warningAmberText,
          size: 22,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hidden · abusive language',
                style: AppTextStyles.flaggedTitle,
              ),
              const SizedBox(height: 2),
              Text(
                'Tap to reveal message',
                style: AppTextStyles.flaggedSubtitle,
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        const Icon(
          Icons.visibility_outlined,
          color: AppColors.warningAmberText,
          size: 16,
        ),
      ],
    );
  }

  Widget _buildRevealedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warningAmberText,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Content flagged by mesh safety shield',
                style: AppTextStyles.flaggedSubtitle.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
            Text(
              'Hide',
              style: AppTextStyles.flaggedSubtitle.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          widget.text,
          style: AppTextStyles.incomingMessageText.copyWith(
            color: AppColors.warningAmberText,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
