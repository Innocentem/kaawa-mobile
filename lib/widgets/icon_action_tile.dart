import 'package:flutter/material.dart';

class IconActionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? tooltip;
  final String? badgeText;
  final VoidCallback onTap;

  const IconActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tooltip,
    this.badgeText,
  });

  @override
  State<IconActionTile> createState() => _IconActionTileState();
}

class _IconActionTileState extends State<IconActionTile> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.08).chain(CurveTween(curve: Curves.easeOut)).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bounce() async {
    try {
      await _controller.forward();
      await _controller.reverse();
    } catch (_) {
      // ignore when disposed mid-animation
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = IconTheme.of(context).color ?? theme.colorScheme.primary;
    final showBadge = widget.badgeText != null && widget.badgeText!.isNotEmpty && widget.badgeText != '0';

    return Semantics(
      button: true,
      label: widget.tooltip ?? widget.label,
      child: Tooltip(
        message: widget.tooltip ?? widget.label,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            await _bounce();
            if (!mounted) return;
            widget.onTap();
          },
          child: AnimatedBuilder(
            animation: _scale,
            builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withAlpha(60),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withAlpha(60)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(widget.icon, size: 28, color: iconColor),
                      if (showBadge)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: theme.colorScheme.onError, width: 1),
                            ),
                            child: Text(
                              widget.badgeText!,
                              style: TextStyle(
                                color: theme.colorScheme.onError,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(widget.label, style: theme.textTheme.labelMedium),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

