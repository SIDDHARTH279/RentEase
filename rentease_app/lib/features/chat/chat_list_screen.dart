import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme/app_surfaces.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _searchController = TextEditingController();
  List<dynamic> _contacts = [];
  List<dynamic> _conversations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        apiClient.get('/api/v1/chat/contacts/'),
        apiClient.get('/api/v1/chat/conversations/'),
      ]);
      if (!mounted) return;
      setState(() {
        _contacts = results[0].data as List<dynamic>? ?? [];
        _conversations = results[1].data as List<dynamic>? ?? [];
      });
    } on DioException {
      if (!mounted) return;
      setState(() => _error = 'Could not load chats.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredContacts {
    final q = _searchController.text.trim().toLowerCase();
    final list = _contacts
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (q.isEmpty) return list;
    return list.where((c) {
      final haystack = [
        c['name'],
        c['email'],
        c['phone'],
        c['unit_number'],
        c['building_name'],
        c['unit_label'],
      ].whereType<Object>().map((e) => e.toString().toLowerCase()).join(' ');
      return haystack.contains(q);
    }).toList();
  }

  String _chatTitle(Map<String, dynamic> contact) {
    final name = contact['name']?.toString().trim();
    final unit = contact['unit_number']?.toString().trim();
    if (name != null && name.isNotEmpty && unit != null && unit.isNotEmpty) {
      return '$name · $unit';
    }
    return name?.isNotEmpty == true
        ? name!
        : (contact['email']?.toString() ?? 'Chat');
  }

  String _lastPreview(dynamic last, Map<String, dynamic> contact) {
    if (last == null) {
      return contact['unit_label']?.toString() ??
          contact['email']?.toString() ??
          '';
    }
    final map = Map<String, dynamic>.from(last as Map);
    if (map['message_type'] == 'image') {
      final caption = map['text']?.toString() ?? '';
      return caption.isNotEmpty ? '📷 $caption' : '📷 Photo';
    }
    return map['text']?.toString() ?? '';
  }

  Future<void> _openChatWithTenant(Map<String, dynamic> contact) async {
    try {
      final res = await apiClient.post(
        '/api/v1/chat/conversations/',
        data: {'tenant_id': contact['id']},
      );
      final conv = res.data as Map<String, dynamic>;
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            conversationId: conv['id'] as int,
            title: _chatTitle(contact),
          ),
        ),
      );
      _load();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['detail'] ?? 'Could not start chat.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _filteredContacts;
    final scheme = context.colors;
    final muted = scheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: scheme.primary))
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by name, unit, or building',
                          prefixIcon: Icon(Icons.search, color: muted),
                          filled: true,
                          fillColor: context.softFill,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: scheme.outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: scheme.primary, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        color: scheme.primary,
                        child: _contacts.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 120),
                                  Center(
                                    child: Text(
                                      'No tenants to chat with yet.\nInvite a tenant first.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: muted),
                                    ),
                                  ),
                                ],
                              )
                            : contacts.isEmpty
                                ? ListView(
                                    children: [
                                      const SizedBox(height: 80),
                                      Center(
                                        child: Text(
                                          'No tenants match your search.',
                                          style: TextStyle(color: muted),
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: contacts.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (_, i) {
                                      final c = contacts[i];
                                      Map<String, dynamic>? convMatch;
                                      for (final raw in _conversations) {
                                        final x = Map<String, dynamic>.from(
                                            raw as Map);
                                        if (x['tenant'] == c['id']) {
                                          convMatch = x;
                                          break;
                                        }
                                      }
                                      final last = convMatch?['last_message'];
                                      final unread =
                                          convMatch?['unread_count'] as int? ??
                                              0;
                                      final unitLabel =
                                          c['unit_label']?.toString() ?? '';
                                      final unit =
                                          c['unit_number']?.toString() ?? '';

                                      return Material(
                                        color: scheme.surface,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          side: BorderSide(
                                              color: scheme.outlineVariant),
                                        ),
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          leading: CircleAvatar(
                                            backgroundColor: scheme.primary,
                                            child: Text(
                                              unit.isNotEmpty
                                                  ? unit.length <= 3
                                                      ? unit
                                                      : _initial(
                                                          c['name']?.toString())
                                                  : _initial(
                                                      c['name']?.toString()),
                                              style: TextStyle(
                                                color: scheme.onPrimary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            c['name']?.toString() ?? 'Tenant',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: context.brandText,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (unitLabel.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 2, bottom: 2),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.home_work_outlined,
                                                        size: 14,
                                                        color: muted,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          unitLabel,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: muted,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              Text(
                                                _lastPreview(last, c),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                          isThreeLine: unitLabel.isNotEmpty,
                                          trailing: unread > 0
                                              ? CircleAvatar(
                                                  radius: 12,
                                                  backgroundColor: Colors.red,
                                                  child: Text(
                                                    '$unread',
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11),
                                                  ),
                                                )
                                              : Icon(Icons.chevron_right,
                                                  color: muted),
                                          onTap: () => _openChatWithTenant(c),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ),
                  ],
                ),
    );
  }

  String _initial(String? name) {
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return 'T';
    return trimmed[0].toUpperCase();
  }
}
