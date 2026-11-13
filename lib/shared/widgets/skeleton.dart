import 'package:flutter/material.dart';
import 'package:round_ai/core/theme/app_colors.dart';

/// Grey placeholder blocks that stand in for a list while it loads. They pulse
/// gently, and stay still when the device asks for less motion.
class Skeleton extends StatefulWidget {
  const Skeleton({required this.child, super.key});

  final Widget child;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return Opacity(opacity: 1 - 0.5 * _controller.value, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

/// One grey block.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({this.width, this.height = 14, this.radius = 8, super.key});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.chipIdle,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A card-shaped placeholder: a title line and two shorter lines.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SkeletonBox(width: 160, height: 16),
          SizedBox(height: 10),
          SkeletonBox(height: 12),
          SizedBox(height: 8),
          SkeletonBox(width: 110, height: 12),
        ],
      ),
    );
  }
}

/// A screen of placeholders for a list that is still loading.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    this.count = 4,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 24),
    super.key,
  });

  final int count;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        itemCount: count,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) => const SkeletonCard(),
      ),
    );
  }
}

/// Placeholders for inside a scrolling page, where a list is still loading.
class SkeletonColumn extends StatelessWidget {
  const SkeletonColumn({this.count = 3, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Column(
        children: <Widget>[
          for (int i = 0; i < count; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 12),
            const SkeletonCard(),
          ],
        ],
      ),
    );
  }
}
