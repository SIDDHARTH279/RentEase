import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';

/// App-bar bell with unread badge; refreshes when returning from /activity.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with WidgetsBindingObserver {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUnread();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUnread();
    }
  }

  Future<void> _loadUnread() async {
    try {
      final res = await apiClient.get('/api/v1/auth/notifications/');
      if (!mounted) return;
      final count = (res.data as Map)['unread_count'];
      setState(() => _unread = count is int ? count : int.tryParse('$count') ?? 0);
    } on DioException {
      // ignore — keep last known count
    }
  }

  Future<void> _open() async {
    await context.push('/activity');
    if (mounted) _loadUnread();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _unread > 0 ? 'Notifications ($_unread)' : 'Notifications',
      onPressed: _open,
      icon: Badge(
        isLabelVisible: _unread > 0,
        backgroundColor: const Color(0xFFE53935),
        label: Text(
          _unread > 99 ? '99+' : '$_unread',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        child: Icon(
          _unread > 0
              ? Icons.notifications_rounded
              : Icons.notifications_outlined,
        ),
      ),
    );
  }
}
