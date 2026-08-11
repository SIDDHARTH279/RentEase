import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme/app_surfaces.dart';
import '../chat/chat_room_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<dynamic> _items = [];
  int _unread = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await apiClient.get('/api/v1/auth/notifications/');
      if (!mounted) return;
      final data = res.data as Map;
      setState(() {
        _items = data['results'] as List<dynamic>? ?? [];
        _unread = data['unread_count'] as int? ?? 0;
      });
    } on DioException {
      try {
        final res = await apiClient.get('/api/v1/auth/activity/');
        if (!mounted) return;
        setState(() {
          _items = (res.data as Map)['results'] as List<dynamic>? ?? [];
          _unread = 0;
        });
      } on DioException {
        if (!mounted) return;
        setState(() => _error = 'Could not load notifications.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clearAll() async {
    try {
      await apiClient.post(
        '/api/v1/auth/notifications/read/',
        data: {'all': true, 'delete': true},
      );
      if (!mounted) return;
      setState(() {
        _items = [];
        _unread = 0;
      });
    } on DioException {
      // ignore
    }
  }

  /// Remove notification from list + server when opened.
  Future<void> _dismiss(dynamic id) async {
    final notifId = id is int ? id : int.tryParse('$id');
    if (notifId == null) return;

    final wasUnread = _items.any((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      return m['id'] == notifId &&
          (m['unread'] == true || m['is_read'] == false);
    });

    setState(() {
      _items = _items.where((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        return m['id'] != notifId;
      }).toList();
      if (wasUnread && _unread > 0) _unread -= 1;
    });

    try {
      await apiClient.delete('/api/v1/auth/notifications/$notifId/');
    } on DioException {
      try {
        await apiClient.post(
          '/api/v1/auth/notifications/read/',
          data: {
            'ids': [notifId],
            'delete': true,
          },
        );
      } on DioException {
        // ignore — already removed from UI
      }
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'rent_overdue':
      case 'overdue_rent':
        return Icons.warning_amber_rounded;
      case 'rent_due':
        return Icons.receipt_long_rounded;
      case 'payment_success':
        return Icons.check_circle_rounded;
      case 'issue':
        return Icons.build_rounded;
      case 'chat':
        return Icons.chat_bubble_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorFor(BuildContext context, String type) {
    switch (type) {
      case 'rent_overdue':
      case 'overdue_rent':
        return context.accentRed();
      case 'rent_due':
        return context.accentOrange();
      case 'payment_success':
        return context.accentGreen();
      case 'issue':
        return context.isDark
            ? const Color(0xFFCE93D8)
            : const Color(0xFF6A1B9A);
      case 'chat':
        return context.accentBlue();
      default:
        return context.brandText;
    }
  }

  Future<void> _onTap(Map<String, dynamic> item) async {
    await _dismiss(item['id']);

    final type = item['type']?.toString() ?? '';
    final data = item['data'] is Map
        ? Map<String, dynamic>.from(item['data'] as Map)
        : <String, dynamic>{};
    final conversationId =
        item['conversation_id'] ?? data['conversation_id'];

    if (type == 'chat' && conversationId != null) {
      final cid = int.tryParse(conversationId.toString());
      if (cid != null && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              conversationId: cid,
              title: item['title']?.toString() ?? 'Chat',
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    if (type == 'issue' ||
        type == 'rent_overdue' ||
        type == 'overdue_rent' ||
        type == 'rent_due' ||
        type == 'payment_success' ||
        type == 'general') {
      // Stay on list so user sees it disappear; only pop for deep nav later if needed
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final muted = scheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: Text(
                'Clear all',
                style: TextStyle(color: scheme.onPrimary),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: scheme.primary))
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: scheme.primary,
                  child: _items.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Text(
                                'You\'re all caught up.',
                                style: TextStyle(color: muted),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final item =
                                Map<String, dynamic>.from(_items[i] as Map);
                            final type = item['type']?.toString() ?? '';
                            final color = _colorFor(context, type);
                            final unread = item['unread'] == true ||
                                item['is_read'] == false;
                            return Material(
                              color: unread
                                  ? scheme.primaryContainer
                                      .withValues(alpha: context.isDark ? 0.35 : 0.55)
                                  : scheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: scheme.outlineVariant),
                              ),
                              child: ListTile(
                                onTap: () => _onTap(item),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      color.withValues(alpha: 0.12),
                                  child: Icon(_iconFor(type),
                                      color: color, size: 20),
                                ),
                                title: Text(
                                  item['title']?.toString() ?? '',
                                  style: TextStyle(
                                    fontWeight: unread
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: context.brandText,
                                  ),
                                ),
                                subtitle: Text(
                                  item['body']?.toString() ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: muted),
                                ),
                                trailing: unread
                                    ? Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
