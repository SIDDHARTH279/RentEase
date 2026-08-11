import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import 'chat_room_screen.dart';

/// Opens (or creates) the tenant's conversation with their owner.
Future<void> openTenantChat(BuildContext context) async {
  final primary = Theme.of(context).colorScheme.primary;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Center(
      child: CircularProgressIndicator(color: primary),
    ),
  );

  try {
    final res = await apiClient.post('/api/v1/chat/conversations/');
    final conv = res.data as Map<String, dynamic>;
    if (!context.mounted) return;
    Navigator.pop(context); // close loader

    final title = conv['owner_name']?.toString() ??
        conv['owner_email']?.toString() ??
        'Owner';

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          conversationId: conv['id'] as int,
          title: title,
        ),
      ),
    );
  } on DioException catch (e) {
    if (!context.mounted) return;
    Navigator.pop(context);
    final msg = e.response?.data?['detail'] ?? 'Could not open chat.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red),
    );
  }
}
