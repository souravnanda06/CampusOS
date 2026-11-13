import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/mesh_theme.dart';

/// Floating Frosted Composer Pill for Screen 2 (Chat screen).
///
/// Features:
/// - Floating pill with radius 28, margin, layered shadow, and hairline border
/// - Sits smoothly above the keyboard via SafeArea + viewInsets.bottom
/// - 44px image-attach IconButton in accent color with Semantics/tooltip & haptic feedback
/// - Borderless TextField with "Message the mesh" hint
/// - 44px circular send button animating between muted grey (#9A9CC4)
///   and indigo-violet gradient glow (200ms) with tactile haptics
/// - Enter key / TextInputAction.send submission
class Composer extends StatefulWidget {
  final ValueChanged<String> onSend;
  final VoidCallback? onAttachImage;
  final String initialText;
  final ValueChanged<String>? onDraftChanged;
  final FocusNode? focusNode;

  const Composer({
    super.key,
    required this.onSend,
    this.onAttachImage,
    this.initialText = '',
    this.onDraftChanged,
    this.focusNode,
  });

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  late final TextEditingController _controller;
  late final FocusNode _internalFocusNode;
  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _internalFocusNode = FocusNode();
    _hasText = _controller.text.trim().isNotEmpty;

    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasContent = _controller.text.trim().isNotEmpty;
    if (_hasText != hasContent) {
      setState(() {
        _hasText = hasContent;
      });
    }
    widget.onDraftChanged?.call(_controller.text);
  }

  @override
  void didUpdateWidget(covariant Composer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialText != oldWidget.initialText &&
        widget.initialText != _controller.text) {
      _controller.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _internalFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    widget.onSend(text);
    _controller.clear();
    setState(() {
      _hasText = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return SafeArea(
      top: false,
      bottom: viewInsets.bottom == 0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          6,
          16,
          viewInsets.bottom > 0 ? 8 : 12,
        ),
        child: RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.composer),
              boxShadow: AppShadows.composerShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.composer),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.frostedGlassWhite,
                    borderRadius: BorderRadius.circular(AppRadii.composer),
                    border: Border.all(
                      color: AppColors.hairlineBorder,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 44px Image Attach Button
                    Semantics(
                      label: 'Attach photo or file',
                      button: true,
                      child: Tooltip(
                        message: 'Attach photo',
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onAttachImage?.call();
                            },
                            child: const SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(
                                child: Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: AppColors.accentIndigo,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Text Field with no border
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: TextField(
                          controller: _controller,
                          focusNode: _effectiveFocusNode,
                          textInputAction: TextInputAction.send,
                          keyboardType: TextInputType.multiline,
                          cursorColor: AppColors.accentIndigo,
                          keyboardAppearance: Brightness.light,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          style: AppTextStyles.composerInput,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: 'Message the mesh',
                            hintStyle: AppTextStyles.composerHint,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 4,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 44px Animated Circular Send Button
                    Semantics(
                      label: 'Send message to mesh',
                      button: true,
                      child: Tooltip(
                        message: 'Send message',
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: _hasText ? AppColors.accentGradient : null,
                            color: _hasText ? null : AppColors.composerGrey.withValues(alpha: 0.4),
                            boxShadow: _hasText
                                ? [
                                    BoxShadow(
                                      color: AppColors.accentIndigo.withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _hasText ? _submit : null,
                              child: Center(
                                child: Icon(
                                  Icons.arrow_upward_rounded,
                                  color: _hasText ? Colors.white : AppColors.textMeta,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
