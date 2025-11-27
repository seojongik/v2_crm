import 'package:flutter/material.dart';
import '../services/session_manager.dart';

class ActivityDetector extends StatefulWidget {
  final Widget child;

  const ActivityDetector({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<ActivityDetector> createState() => _ActivityDetectorState();
}

class _ActivityDetectorState extends State<ActivityDetector> {
  DateTime? _lastActivityTime;
  final Duration _throttleDuration = const Duration(seconds: 10); // 10초마다만 갱신

  void _handleUserActivity() {
    final now = DateTime.now();

    // 마지막 활동 시간과 10초 이상 차이날 때만 갱신
    if (_lastActivityTime == null ||
        now.difference(_lastActivityTime!).inSeconds >= _throttleDuration.inSeconds) {
      _lastActivityTime = now;
      SessionManager.instance.updateActivity();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _handleUserActivity(),
      onPointerMove: (_) => _handleUserActivity(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _handleUserActivity(),
        onScaleUpdate: (_) => _handleUserActivity(),
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              _handleUserActivity();
            }
            return false;
          },
          child: widget.child,
        ),
      ),
    );
  }
}