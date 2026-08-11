import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/api_client.dart';
import '../../core/theme/app_surfaces.dart';
import '../../core/ws_config.dart';

class ChatRoomScreen extends StatefulWidget {
  final int conversationId;
  final String title;

  const ChatRoomScreen({
    super.key,
    required this.conversationId,
    required this.title,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _storage = const FlutterSecureStorage();
  final _textController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  final Map<int, GlobalKey> _messageKeys = {};

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSendingMedia = false;
  bool _searchOpen = false;
  String? _error;
  String? _cachedEmail;
  Map<String, dynamic>? _replyTo;
  WebSocketChannel? _channel;
  int? _highlightId;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _textController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _cachedEmail = await _storage.read(key: 'user_email');
    await _loadHistory();
    await _connectSocket();
  }

  Future<void> _loadHistory({String? q}) async {
    final showSpinner = _messages.isEmpty;
    if (showSpinner) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final res = await apiClient.get(
        '/api/v1/chat/conversations/${widget.conversationId}/messages/',
        queryParameters: (q != null && q.isNotEmpty) ? {'q': q} : null,
      );
      final list = (res.data as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() => _messages = list);
      if (q == null || q.isEmpty) {
        _scrollToBottom();
      }
    } on DioException {
      if (!mounted) return;
      setState(() => _error = 'Could not load messages.');
    } finally {
      if (mounted && showSpinner) setState(() => _isLoading = false);
    }
  }

  Future<void> _connectSocket() async {
    final token = await _storage.read(key: accessTokenKey);
    if (token == null) return;

    final uri = Uri.parse(
      '$wsBaseUrl/ws/chat/${widget.conversationId}/?token=$token',
    );
    _channel = WebSocketChannel.connect(uri);
    _channel!.stream.listen(
      (event) {
        try {
          final data = jsonDecode(event as String) as Map<String, dynamic>;
          if (data['event'] == 'read') {
            final ids = (data['message_ids'] as List<dynamic>? ?? [])
                .map((e) => int.tryParse(e.toString()))
                .whereType<int>()
                .toSet();
            setState(() {
              _messages = _messages.map((m) {
                final mid = m['id'];
                final midInt = mid is int ? mid : int.tryParse('$mid');
                if (midInt != null && ids.contains(midInt)) {
                  return {...m, 'is_read': true};
                }
                return m;
              }).toList();
            });
            return;
          }

          setState(() {
            final id = data['id'];
            if (id != null && _messages.any((m) => m['id'] == id)) return;
            // If search filter is active, only append if it matches
            final q = _searchController.text.trim().toLowerCase();
            if (q.isNotEmpty) {
              final text = (data['text']?.toString() ?? '').toLowerCase();
              if (!text.contains(q)) return;
            }
            _messages = [..._messages, data];
          });
          if (!_searchOpen) _scrollToBottom();
        } catch (_) {}
      },
      onError: (_) {},
      onDone: () {},
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _scrollToMessageId(int id) async {
    // Ensure full history if currently filtered
    if (_searchController.text.trim().isNotEmpty) {
      _searchController.clear();
      await _loadHistory();
    }

    final index = _messages.indexWhere((m) => m['id'] == id);
    if (index < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original message not found')),
      );
      return;
    }

    setState(() => _highlightId = id);
    await Future.delayed(const Duration(milliseconds: 50));
    final key = _messageKeys[id];
    final ctx = key?.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        alignment: 0.35,
        curve: Curves.easeOut,
      );
    }
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _highlightId = null);
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    final replyId = _replyTo?['id'];
    setState(() => _replyTo = null);

    final payload = <String, dynamic>{'text': text};
    if (replyId != null) payload['reply_to'] = replyId;

    if (_channel != null) {
      _channel!.sink.add(jsonEncode(payload));
      return;
    }

    try {
      final res = await apiClient.post(
        '/api/v1/chat/conversations/${widget.conversationId}/messages/',
        data: payload,
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      setState(() {
        if (!_messages.any((m) => m['id'] == data['id'])) {
          _messages = [..._messages, data];
        }
      });
      _scrollToBottom();
    } on DioException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send message'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickAndSend(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (file == null) return;
      await _sendImage(File(file.path));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open camera/gallery'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendImage(File file) async {
    setState(() => _isSendingMedia = true);
    final replyId = _replyTo?['id'];
    final caption = _textController.text.trim();
    _textController.clear();
    setState(() => _replyTo = null);

    try {
      final form = FormData.fromMap({
        if (caption.isNotEmpty) 'text': caption,
        if (replyId != null) 'reply_to': replyId,
        'image': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split(Platform.pathSeparator).last,
        ),
      });
      final res = await apiClient.post(
        '/api/v1/chat/conversations/${widget.conversationId}/messages/',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      if (!mounted) return;
      setState(() {
        if (!_messages.any((m) => m['id'] == data['id'])) {
          _messages = [..._messages, data];
        }
      });
      _scrollToBottom();
    } on DioException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send photo'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSendingMedia = false);
    }
  }

  void _showAttachSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AttachOption(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                color: const Color(0xFF7B1FA2),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSend(ImageSource.gallery);
                },
              ),
              _AttachOption(
                icon: Icons.photo_camera_rounded,
                label: 'Camera',
                color: const Color(0xFFD32F2F),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSend(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _jumpToDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) {
        final scheme = Theme.of(context).colorScheme;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: scheme.copyWith(primary: scheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;

    // Need full history for jump
    if (_searchController.text.trim().isNotEmpty || _searchOpen) {
      _searchController.clear();
      setState(() => _searchOpen = false);
      await _loadHistory();
    }

    final index = _messages.indexWhere((m) {
      final dt = DateTime.tryParse(m['created_at']?.toString() ?? '');
      if (dt == null) return false;
      final local = dt.toLocal();
      return local.year == picked.year &&
          local.month == picked.month &&
          local.day == picked.day;
    });

    if (index < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No messages on that date')),
      );
      return;
    }

    final id = _messages[index]['id'] as int;
    await _scrollToMessageId(id);
  }

  List<_ChatItem> _buildItems() {
    final items = <_ChatItem>[];
    DateTime? lastDay;
    for (final msg in _messages) {
      final dt = DateTime.tryParse(msg['created_at']?.toString() ?? '');
      final local = dt?.toLocal();
      if (local != null) {
        final day = DateTime(local.year, local.month, local.day);
        if (lastDay == null || day != lastDay) {
          items.add(_ChatItem.date(_dateLabel(day)));
          lastDay = day;
        }
      }
      items.add(_ChatItem.message(msg));
    }
    return items;
  }

  String _dateLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today) return 'Today';
    if (day == yesterday) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${day.day} ${months[day.month - 1]} ${day.year}';
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    final scheme = context.colors;
    final muted = scheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: context.isDark
          ? scheme.surface
          : const Color(0xFFECE5DD),
      appBar: AppBar(
        titleSpacing: 0,
        title: _searchOpen
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: scheme.onPrimary),
                cursorColor: scheme.onPrimary,
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: TextStyle(
                      color: scheme.onPrimary.withValues(alpha: 0.7)),
                  border: InputBorder.none,
                ),
                onChanged: (v) {
                  // Debounce lightly via microtask batching
                  Future.microtask(() => _loadHistory(q: v.trim()));
                },
              )
            : Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
        actions: [
          if (_searchOpen)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchOpen = false);
                _loadHistory();
              },
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: () => setState(() => _searchOpen = true),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'jump') _jumpToDate();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'jump',
                  child: Text('Jump to date'),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading && _messages.isEmpty
                ? Center(
                    child: CircularProgressIndicator(color: scheme.primary))
                : _error != null
                    ? Center(child: Text(_error!))
                    : items.isEmpty
                        ? Center(
                            child: Text(
                              _searchOpen
                                  ? 'No matching messages'
                                  : 'No messages yet.\nSay hello!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: muted),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                            itemCount: items.length,
                            itemBuilder: (_, i) {
                              final item = items[i];
                              if (item.isDate) {
                                return _DateChip(label: item.dateLabel!);
                              }
                              final msg = item.message!;
                              final id = msg['id'] as int?;
                              final key = id == null
                                  ? null
                                  : _messageKeys.putIfAbsent(
                                      id, () => GlobalKey());
                              final mine =
                                  msg['sender_email'] == _cachedEmail;
                              return KeyedSubtree(
                                key: key,
                                child: _Bubble(
                                  message: msg,
                                  isMine: mine,
                                  highlighted: id != null && id == _highlightId,
                                  searchQuery: _searchOpen
                                      ? _searchController.text.trim()
                                      : '',
                                  onLongPress: () {
                                    setState(() => _replyTo = msg);
                                  },
                                  onReplyTap: (replyId) =>
                                      _scrollToMessageId(replyId),
                                  onImageTap: (url) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            _FullScreenImage(url: url),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
          ),
          if (_replyTo != null) _ReplyBanner(
            message: _replyTo!,
            onClose: () => setState(() => _replyTo = null),
          ),
          if (_isSendingMedia)
            LinearProgressIndicator(
              color: scheme.primary,
              minHeight: 2,
            ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
              color: context.softFill,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: _isSendingMedia ? null : _showAttachSheet,
                    icon: Icon(Icons.add_circle_outline_rounded,
                        color: scheme.primary, size: 28),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: TextField(
                        controller: _textController,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'Type a message',
                          hintStyle: TextStyle(color: muted),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  CircleAvatar(
                    backgroundColor: scheme.primary,
                    child: IconButton(
                      icon: Icon(Icons.send_rounded,
                          color: scheme.onPrimary, size: 20),
                      onPressed: _isSendingMedia ? null : _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatItem {
  final String? dateLabel;
  final Map<String, dynamic>? message;

  _ChatItem.date(this.dateLabel) : message = null;
  _ChatItem.message(this.message) : dateLabel = null;

  bool get isDate => dateLabel != null;
}

class _DateChip extends StatelessWidget {
  final String label;
  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.isDark
              ? scheme.surfaceContainerHighest
              : const Color(0xFFE1F2FB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: context.isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 2,
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ReplyBanner extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback onClose;

  const _ReplyBanner({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final preview = message['message_type'] == 'image'
        ? (message['text']?.toString().isNotEmpty == true
            ? message['text'].toString()
            : 'Photo')
        : (message['text']?.toString() ?? '');
    final name = message['sender_name']?.toString() ?? 'Message';

    final scheme = context.colors;
    return Container(
      width: double.infinity,
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.brandText,
                    fontSize: 13,
                  ),
                ),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: onClose),
        ],
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color,
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMine;
  final bool highlighted;
  final String searchQuery;
  final VoidCallback onLongPress;
  final void Function(int replyId) onReplyTap;
  final void Function(String url) onImageTap;

  const _Bubble({
    required this.message,
    required this.isMine,
    required this.highlighted,
    required this.searchQuery,
    required this.onLongPress,
    required this.onReplyTap,
    required this.onImageTap,
  });

  String _formatLocalTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final text = message['text']?.toString() ?? '';
    final timeLabel = _formatLocalTime(message['created_at']?.toString());
    final imageUrl = message['image']?.toString();
    final isImage = message['message_type'] == 'image' ||
        (imageUrl != null && imageUrl.isNotEmpty);
    final reply = message['reply_preview'] as Map<String, dynamic>?;
    final isRead = message['is_read'] == true;

    // Own: brand blue + white text; peer: soft surface (no white glare in dark).
    final bg = isMine
        ? const Color(0xFF2E6DA4)
        : (context.isDark
            ? scheme.surfaceContainerHighest
            : Colors.white);
    final fg = isMine ? Colors.white : scheme.onSurface;
    final metaColor = isMine
        ? Colors.white.withValues(alpha: 0.75)
        : scheme.onSurfaceVariant;
    final highlightBg = context.isDark
        ? const Color(0xFF6D5C1A)
        : const Color(0xFFFFF59D);
    final replyAccent = isMine ? Colors.white : context.brandText;
    final replyFg = isMine
        ? Colors.white.withValues(alpha: 0.85)
        : scheme.onSurfaceVariant;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: highlighted ? highlightBg : bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(isMine ? 12 : 3),
              bottomRight: Radius.circular(isMine ? 3 : 12),
            ),
            border: (!isMine && !highlighted)
                ? Border.all(color: scheme.outlineVariant)
                : null,
            boxShadow: context.isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (reply != null)
                GestureDetector(
                  onTap: () {
                    final id = reply['id'];
                    if (id is int) onReplyTap(id);
                  },
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isMine
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(
                              alpha: context.isDark ? 0.2 : 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(color: replyAccent, width: 3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reply['sender_name']?.toString() ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: replyAccent,
                          ),
                        ),
                        Text(
                          reply['text']?.toString() ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: replyFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (isImage && imageUrl != null)
                GestureDetector(
                  onTap: () => onImageTap(imageUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      width: 220,
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 220,
                        height: 120,
                        color: context.softFill,
                        alignment: Alignment.center,
                        child: Icon(Icons.broken_image_outlined,
                            color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
              if (text.isNotEmpty) ...[
                if (isImage) const SizedBox(height: 6),
                _HighlightedText(
                  text: text,
                  query: searchQuery,
                  style: TextStyle(color: fg, fontSize: 15, height: 1.25),
                ),
              ],
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    timeLabel,
                    style: TextStyle(
                      color: metaColor,
                      fontSize: 11,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isRead ? Icons.done_all : Icons.done,
                      size: 16,
                      color: isRead
                          ? const Color(0xFF53BDEB)
                          : metaColor,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;

  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, style: style);
    }
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final idx = lower.indexOf(q, start);
      if (idx < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      final isDark = Theme.of(context).brightness == Brightness.dark;
      spans.add(TextSpan(
        text: text.substring(idx, idx + q.length),
        style: style.copyWith(
          backgroundColor:
              isDark ? const Color(0xFF6D5C1A) : const Color(0xFFFFF176),
          fontWeight: FontWeight.w700,
        ),
      ));
      start = idx + q.length;
    }
    return RichText(text: TextSpan(style: style, children: spans));
  }
}

class _FullScreenImage extends StatelessWidget {
  final String url;
  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
