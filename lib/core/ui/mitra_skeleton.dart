import 'package:flutter/material.dart';
import '../../app/theme/tokens.dart';

class MitraSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double? borderRadius;

  const MitraSkeleton({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<MitraSkeleton> createState() => _MitraSkeletonState();
}

class _MitraSkeletonState extends State<MitraSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.space;
    final baseColor = theme.colorScheme.surfaceContainerHighest;
    final highlightColor = theme.colorScheme.surfaceContainerHigh;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final color = Color.lerp(baseColor, highlightColor, _controller.value);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(widget.borderRadius ?? space.radiusSm),
          ),
        );
      },
    );
  }
}

class MitraMessageSkeleton extends StatelessWidget {
  const MitraMessageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: space.lg, vertical: space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MitraSkeleton(
                width: 28,
                height: 28,
                borderRadius: space.radiusFull,
              ),
              SizedBox(width: space.sm),
              const MitraSkeleton(width: 80, height: 16),
            ],
          ),
          SizedBox(height: space.md),
          const MitraSkeleton(width: double.infinity, height: 14),
          SizedBox(height: space.xs),
          const MitraSkeleton(width: double.infinity, height: 14),
          SizedBox(height: space.xs),
          MitraSkeleton(
            width: MediaQuery.of(context).size.width * 0.4,
            height: 14,
          ),
        ],
      ),
    );
  }
}

class MitraListSkeleton extends StatelessWidget {
  final int itemCount;

  const MitraListSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return ListView.separated(
      padding: EdgeInsets.all(space.sm),
      itemCount: itemCount,
      separatorBuilder: (context, index) => SizedBox(height: space.xs),
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: space.sm, vertical: space.xs),
          child: Row(
            children: [
              MitraSkeleton(width: 36, height: 36, borderRadius: space.radiusMd),
              SizedBox(width: space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MitraSkeleton(width: 140, height: 16),
                    SizedBox(height: space.xs),
                    const MitraSkeleton(width: double.infinity, height: 12),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
