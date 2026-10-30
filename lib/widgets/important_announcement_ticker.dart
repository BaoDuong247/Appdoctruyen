import 'package:flutter/material.dart';

import '../services/firebase_data.dart';

class ImportantAnnouncementTicker extends StatefulWidget {
  const ImportantAnnouncementTicker({super.key});

  @override
  State<ImportantAnnouncementTicker> createState() =>
      _ImportantAnnouncementTickerState();
}

class _ImportantAnnouncementTickerState
    extends State<ImportantAnnouncementTicker> {
  late final _announcements = FirebaseData.watchImportantNotifications();

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: _announcements,
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <Map<String, dynamic>>[];
          if (items.isEmpty) return const SizedBox.shrink();
          final message = items
              .map((item) {
                final title = item['title'] as String? ?? '';
                final body = item['message'] as String? ?? '';
                if (title.isEmpty) return body;
                if (body.isEmpty) return title;
                return '$title: $body';
              })
              .where((text) => text.trim().isNotEmpty)
              .join('     ✦     ');
          if (message.isEmpty) return const SizedBox.shrink();
          return _ThreePassTicker(message: '✦  $message  ✦');
        },
      );
}

class _ThreePassTicker extends StatefulWidget {
  const _ThreePassTicker({required this.message});

  final String message;

  @override
  State<_ThreePassTicker> createState() => _ThreePassTickerState();
}

class _ThreePassTickerState extends State<_ThreePassTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _completedPasses = 0;
  var _visible = true;

  Duration _durationFor(String message) {
    // Match the travel distance to a readable, steady speed on both phone and
    // desktop layouts. The text is typically a little wider than 8 px/char.
    final travelPixels = MediaQuery.sizeOf(context).width +
        message.length * 8.0 +
        32;
    final milliseconds = (travelPixels / 38 * 1000)
        .round()
        .clamp(14000, 90000)
        .toInt();
    return Duration(milliseconds: milliseconds);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.status == AnimationStatus.dismissed &&
        _completedPasses == 0) {
      _controller.duration = _durationFor(widget.message);
      _controller.forward();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _completedPasses++;
    if (_completedPasses >= 3) {
      if (mounted) setState(() => _visible = false);
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant _ThreePassTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message == widget.message) return;
    _completedPasses = 0;
    _visible = true;
    _controller.stop();
    _controller.duration = _durationFor(widget.message);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor = dark ? const Color(0xFFFF8994) : const Color(0xFFC62835);
    return Container(
      height: 48,
      margin: const EdgeInsets.fromLTRB(22, 10, 22, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF3A2028) : const Color(0xFFFFE9E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dark ? const Color(0xFF75404A) : const Color(0xFFFFC8C8),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final style = TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          );
          final painter = TextPainter(
            text: TextSpan(text: widget.message, style: style),
            textDirection: Directionality.of(context),
            maxLines: 1,
          )..layout();
          final textWidth = painter.width;
          final travel = constraints.maxWidth + textWidth;
          return ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: constraints.maxWidth - travel * _controller.value,
                    top: 13,
                    child: child!,
                  ),
                ],
              ),
              child: Text(
                widget.message,
                maxLines: 1,
                softWrap: false,
                style: style,
              ),
            ),
          );
        },
      ),
    );
  }
}
