// frontend/lib/screens/chat/chat_screen.dart

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemChannels.textInput.invokeMethod('TextInput.hide');
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

// --- Service Imports ---
import '../../services/websocket_service.dart';
import '../../services/auth_provider.dart';
import '../../services/api/user_service.dart';
import '../../services/api/chat_service.dart';
import '../../services/api/event_service.dart';

// --- Model Imports ---
import '../../models/chat_message_data.dart';
import '../../models/event_model.dart';
import '../../models/message_model.dart';

// --- Widget Imports ---
import '../../widgets/chat_message_bubble.dart';
import '../../widgets/chat_event_card.dart';

// --- Theme and Constants ---
import '../../theme/theme_constants.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int? _selectedCommunityId;
  int? _selectedEventId;
  List<ChatMessageData> _messages = [];
  List<Map<String, dynamic>> _userCommunities = [];
  EventModel? _selectedEventDetails;

  bool _isLoadingMessages = false;
  bool _isLoadingCommunities = true;
  bool _isLoadingEventDetails = false;
  bool _isSendingMessage = false;
  bool _canLoadMoreMessages = true;

  StreamSubscription? _wsMessagesSubscription;
  StreamSubscription? _wsConnectionStateSubscription;
  final Map<int, String?> _userAvatarCache = {};
  List<File> _pickedImageFiles = [];
  bool _showEmojiPicker = false;

  @override
  void initState() {
    super.initState();
    _messageFocusNode.addListener(_onFocusChange); // Use a dedicated listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeChat();
        _setupWebSocketListener();
      }
    });
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    print("ChatScreen disposing...");
    _messageController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _messageFocusNode.removeListener(_onFocusChange); // Remove listener
    _messageFocusNode.dispose();
    _wsMessagesSubscription?.cancel();
    _wsConnectionStateSubscription?.cancel();
    super.dispose();
  }

  // --- Focus Listener for Emoji Picker ---
  void _onFocusChange() {
    // If text field gains focus AND emoji picker is shown, hide emoji picker
    if (_messageFocusNode.hasFocus && _showEmojiPicker && mounted) {
      setState(() => _showEmojiPicker = false);
    }
  }
  // --- End Focus Listener ---


  Future<void> _initializeChat() async { /* ... (Keep existing implementation) ... */
    await _loadUserCommunities();
    if (_selectedCommunityId != null && mounted) {
      _updateChatRoomLabel();
      await _loadChatHistory(isInitialLoad: true);
      _connectWebSocket();
    }
  }

  void _setupWebSocketListener() { /* ... (Keep existing implementation, ChatMessageData.fromJson handles media) ... */
    if (!mounted) return;
    final wsService = Provider.of<WebSocketService>(context, listen: false);
    _wsMessagesSubscription = wsService.rawMessages.listen((messageMap) async {
      if (!mounted) return;
      final currentKey = getRoomKey(_selectedEventId != null ? 'event' : 'community', _selectedEventId ?? _selectedCommunityId);
      final messageRoomKey = getRoomKey(messageMap['event_id'] != null ? 'event' : 'community', messageMap['event_id'] ?? messageMap['community_id']);
      if (messageMap.containsKey('message_id') && messageRoomKey == currentKey) {
        try {
          final chatMessage = ChatMessageData.fromJson(messageMap);
          await _ensureAvatarCached(chatMessage.user_id);
          setState(() {
            if (!_messages.any((m) => m.message_id == chatMessage.message_id)) {
              _messages.add(chatMessage); _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
            }
          });
        } catch (e) { print("ChatScreen: Error parsing incoming chat message with media: $e"); }
      }
    }, onError: (error) { print("ChatScreen: Error on WS messages stream: $error"); });
    _wsConnectionStateSubscription = wsService.connectionState.listen((state) { if (!mounted) return; setState(() {}); });
  }

  Future<void> _ensureAvatarCached(int userId) async { /* ... (Keep existing implementation) ... */
    if (_userAvatarCache.containsKey(userId) || !mounted) return;
    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userProfile = await userService.getUserProfile(userId, token: authProvider.token);
      if (mounted) _userAvatarCache[userId] = userProfile['image_url'] as String?;
    } catch (e) { if (mounted) _userAvatarCache[userId] = null; }
  }
  Future<void> _loadUserCommunities() async { /* ... (Keep existing implementation) ... */
    if (!mounted) return; setState(() => _isLoadingCommunities = true);
    final userService = Provider.of<UserService>(context, listen: false); final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) { setState(() { _isLoadingCommunities = false; _userCommunities = []; _selectedCommunityId = null; _selectedEventId = null; }); return; }
    try {
      final communitiesData = await userService.getMyJoinedCommunities(authProvider.token!); if (!mounted) return; _userCommunities = List<Map<String, dynamic>>.from(communitiesData);
      int? initialCommunityId = _selectedCommunityId;
      if (_userCommunities.isNotEmpty && (initialCommunityId == null || !_userCommunities.any((c) => c['id'] == initialCommunityId))) initialCommunityId = _userCommunities.first['id'] as int?;
      else if (_userCommunities.isEmpty) initialCommunityId = null;
      setState(() { _selectedCommunityId = initialCommunityId; _isLoadingCommunities = false; _selectedEventId = null; });
    } catch (e) { if (!mounted) return; print('ChatScreen: Error loading communities: $e'); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading communities: $e'))); setState(() => _isLoadingCommunities = false); }
  }
  Future<void> _loadChatHistory({bool isInitialLoad = false, int? beforeMessageId}) async { /* ... (Keep existing implementation) ... */
    final String roomType = _selectedEventId != null ? 'event' : 'community'; final int? roomId = _selectedEventId ?? _selectedCommunityId;
    if (!mounted || roomId == null) { setState(() { _messages = []; _isLoadingMessages = false; _canLoadMoreMessages = true; }); return; }
    if (isInitialLoad) { setState(() { _isLoadingMessages = true; _messages = []; _canLoadMoreMessages = true; }); }
    else if (_isLoadingMessages || !_canLoadMoreMessages) { return; } else { setState(() => _isLoadingMessages = true); }
    final chatService = Provider.of<ChatService>(context, listen: false); final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) { setState(() { _isLoadingMessages = false; _messages = []; }); return; }
    try {
      final List<dynamic> messagesData = await chatService.getChatMessages(token: authProvider.token!, communityId: roomType == 'community' ? roomId : null, eventId: roomType == 'event' ? roomId : null, limit: 50, beforeId: beforeMessageId);
      if (!mounted) return; final newMessages = messagesData.map((m) => ChatMessageData.fromJson(m as Map<String, dynamic>)).toList();
      for (var msg in newMessages) { await _ensureAvatarCached(msg.user_id); } newMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      setState(() { if (isInitialLoad) _messages = newMessages; else _messages.insertAll(0, newMessages); _isLoadingMessages = false; _canLoadMoreMessages = newMessages.length >= 50; });
      if (isInitialLoad) WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(true));
    } catch (e) { if (!mounted) return; print("ChatScreen: Error loading chat history: $e"); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading messages: $e'))); setState(() { _isLoadingMessages = false; });}
  }
  Future<void> _loadSelectedEventDetails() async { /* ... (Keep existing implementation) ... */
    if (!mounted || _selectedEventId == null) return; setState(() => _isLoadingEventDetails = true);
    final eventService = Provider.of<EventService>(context, listen: false); final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) { setState(() { _isLoadingEventDetails = false; _selectedEventDetails = null; }); return; }
    try {
      final eventData = await eventService.getEventDetails(_selectedEventId!, token: authProvider.token!);
      if (mounted) setState(() { _selectedEventDetails = EventModel.fromJson(eventData); _isLoadingEventDetails = false; });
    } catch (e) { print("ChatScreen: Error loading selected event details: $e"); if (mounted) setState(() { _isLoadingEventDetails = false; _selectedEventDetails = null; }); }
  }
  void _scrollListener() { /* ... (Keep existing implementation) ... */
    if (_scrollController.position.pixels < 100 && !_isLoadingMessages && _canLoadMoreMessages) { final oldestMessageId = _messages.isNotEmpty ? _messages.first.message_id : null; if (oldestMessageId != null) _loadChatHistory(beforeMessageId: oldestMessageId); }
  }
  void _connectWebSocket() { /* ... (Keep existing implementation) ... */
    final String? roomType = _selectedEventId != null ? 'event' : 'community'; final int? roomId = _selectedEventId ?? _selectedCommunityId;
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (roomId != null && token != null) Provider.of<WebSocketService>(context, listen: false).connect(roomType!, roomId, token);
  }
  void _disconnectWebSocket() { /* ... (Keep existing implementation) ... */ Provider.of<WebSocketService>(context, listen: false).disconnect(); }
  void _toggleDrawer() { /* ... (Keep existing implementation) ... */
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) Navigator.of(context).pop(); else _scaffoldKey.currentState?.openDrawer();
  }
  void _selectCommunity(int id) { /* ... (Keep existing, clear picked files & emoji) ... */
    if (_selectedCommunityId == id && _selectedEventId == null) { Navigator.of(context).pop(); return; } if (!mounted) return;
    setState(() { _selectedCommunityId = id; _selectedEventId = null; _messages = []; _selectedEventDetails = null; _isLoadingMessages = true; _canLoadMoreMessages = true; _pickedImageFiles = []; _showEmojiPicker = false; });
    Navigator.of(context).pop(); _updateChatRoomLabel(); _loadChatHistory(isInitialLoad: true); _connectWebSocket();
  }
  void selectEvent(int eventId, int communityId) { /* ... (Keep existing, clear picked files & emoji) ... */
    if (_selectedEventId == eventId) return; if (!mounted) return;
    setState(() { _selectedCommunityId = communityId; _selectedEventId = eventId; _messages = []; _selectedEventDetails = null; _isLoadingMessages = true; _isLoadingEventDetails = true; _canLoadMoreMessages = true; _pickedImageFiles = []; _showEmojiPicker = false; });
    _updateChatRoomLabel(); _loadChatHistory(isInitialLoad: true); _loadSelectedEventDetails(); _connectWebSocket();
  }
  void selectCommunityChat() { /* ... (Keep existing, clear picked files & emoji) ... */
    if (_selectedEventId == null) return; if (!mounted) return;
    setState(() { _selectedEventId = null; _selectedEventDetails = null; _messages = []; _isLoadingMessages = true; _canLoadMoreMessages = true; _pickedImageFiles = []; _showEmojiPicker = false; });
    _updateChatRoomLabel(); _loadChatHistory(isInitialLoad: true); _connectWebSocket();
  }
  void _updateChatRoomLabel() { /* UI updated via build method */ }
  Future<void> _pickChatImages() async { /* ... (Keep existing implementation) ... */
    final picker = ImagePicker();
    try {
      final List<XFile> pickedXFiles = await picker.pickMultiImage(imageQuality: 70, maxWidth: 1080);
      if (pickedXFiles.isNotEmpty && mounted) {
        setState(() { for (var xfile in pickedXFiles) { if (_pickedImageFiles.length < 3) _pickedImageFiles.add(File(xfile.path)); else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Max 3 images per message.'), backgroundColor: Colors.orange)); break;}}});
      }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error picking images.'), backgroundColor: Colors.red)); }
  }
  void _removePickedImage(int index) { /* ... (Keep existing implementation) ... */
    if (mounted && index >= 0 && index < _pickedImageFiles.length) setState(() => _pickedImageFiles.removeAt(index));
  }

  void _toggleEmojiPicker() {
    if (mounted) {
      if (_showEmojiPicker) { // If emoji picker is open, close it
        setState(() => _showEmojiPicker = false);
        // Optionally, re-focus the text field if it's desired behavior
        // FocusScope.of(context).requestFocus(_messageFocusNode);
      } else { // If emoji picker is closed, open it
        // Hide keyboard before showing emoji picker
        if (_messageFocusNode.hasFocus) {
          _messageFocusNode.unfocus(); // Unfocus to hide keyboard
          // SystemChannels.textInput.invokeMethod('TextInput.hide'); // Alternative way to hide keyboard
          // Give a slight delay for keyboard to hide before showing emoji picker
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) setState(() => _showEmojiPicker = true);
          });
        } else {
          setState(() => _showEmojiPicker = true);
        }
      }
    }
  }

  Future<void> _sendMessage() async { /* ... (Keep existing implementation, uses ChatService.sendChatMessageWithMedia) ... */
    final messageText = _messageController.text.trim();
    if ((messageText.isEmpty && _pickedImageFiles.isEmpty) || !mounted || _isSendingMessage) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false); if (!authProvider.isAuthenticated || authProvider.token == null) return;
    final chatService = Provider.of<ChatService>(context, listen: false); final String roomType = _selectedEventId != null ? 'event' : 'community';
    final int? roomId = _selectedEventId ?? _selectedCommunityId; if (roomId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No chat room selected.'))); return; }
    setState(() => _isSendingMessage = true);
    try {
      await chatService.sendChatMessageWithMedia(token: authProvider.token!, content: messageText, communityId: roomType == 'community' ? roomId : null, eventId: roomType == 'event' ? roomId : null, files: _pickedImageFiles.isNotEmpty ? _pickedImageFiles : null);
      _messageController.clear(); setState(() => _pickedImageFiles = []);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: ${e.toString().replaceFirst("Exception: ","")}'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _isSendingMessage = false); }
  }

  void _scrollToBottom([bool jump = false]) { /* ... (Keep existing implementation) ... */
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) { if (_scrollController.hasClients) { final maxScroll = _scrollController.position.maxScrollExtent; if (jump) _scrollController.jumpTo(maxScroll); else { final currentScroll = _scrollController.position.pixels; if ((maxScroll - currentScroll) < 200) _scrollController.animateTo(maxScroll, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);}}});
  }
  String _getAppBarTitle() { /* ... (Keep existing implementation) ... */
    if (_selectedEventId != null && _selectedEventDetails != null) return _selectedEventDetails!.title;
    else if (_selectedCommunityId != null) { final community = _userCommunities.firstWhereOrNull((c) => c['id'] == _selectedCommunityId); return community?['name'] ?? 'Community Chat'; }
    else return 'Chat';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context); final isDark = theme.brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    // Wrap with WillPopScope to handle back button when emoji picker is open
    return WillPopScope(
        onWillPop: () async {
          if (_showEmojiPicker) {
            setState(() => _showEmojiPicker = false);
            return false; // Prevent app from closing/navigating back
          }
          return true; // Allow normal back navigation
        },
        child: Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(title: Text(_getAppBarTitle(), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), leading: IconButton(icon: const Icon(Icons.menu), tooltip: "Select Room", onPressed: _toggleDrawer)),
          drawer: _buildDrawer(isDark),
          body: !authProvider.isAuthenticated ? _buildNotLoggedInView(isDark)
              : Column(children: [
            if (_isLoadingCommunities) const LinearProgressIndicator(minHeight: 2),
            if (_selectedEventId != null) _buildSelectedEventCardContainer(isDark, authProvider.userId),
            Expanded(child: GestureDetector( // Tap message list to hide emoji picker
                onTap: () { if (_showEmojiPicker && mounted) setState(() => _showEmojiPicker = false); FocusScope.of(context).unfocus(); },
                child: _buildMessagesListContainer(isDark, authProvider.userId ?? '')
            )),
            if (_pickedImageFiles.isNotEmpty) _buildImagePreviews(),
            _buildMessageInput(isDark),
            Offstage(offstage: !_showEmojiPicker, child: SizedBox(height: 250, child: EmojiPicker(
              onEmojiSelected: (Category? category, Emoji emoji) { _messageController..text += emoji.emoji..selection = TextSelection.fromPosition(TextPosition(offset: _messageController.text.length));},
              onBackspacePressed: () { _messageController..text = _messageController.text.characters.skipLast(1).toString()..selection = TextSelection.fromPosition(TextPosition(offset: _messageController.text.length));},
              config: Config(columns: 7, emojiSizeMax: 32 * (Platform.isIOS ? 1.30 : 1.0), verticalSpacing: 0, horizontalSpacing: 0, gridPadding: EdgeInsets.zero, initCategory: Category.RECENT, bgColor: isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade100, indicatorColor: ThemeConstants.accentColor, iconColor: Colors.grey, iconColorSelected: ThemeConstants.accentColor, backspaceColor: ThemeConstants.accentColor, skinToneDialogBgColor: Colors.white, skinToneIndicatorColor: Colors.grey, enableSkinTones: true, recentTabBehavior: RecentTabBehavior.RECENT, recentsLimit: 28, replaceEmojiOnLimitExceed: false, noRecents: Text('No Recents', style: TextStyle(fontSize: 20, color: Colors.grey.shade600), textAlign: TextAlign.center), loadingIndicator: const SizedBox.shrink(), tabIndicatorAnimDuration: kTabScrollDuration, categoryIcons: const CategoryIcons(), buttonMode: ButtonMode.MATERIAL, checkPlatformCompatibility: true,),),),),
          ],
          ),
        )
    );
  }

  Widget _buildDrawer(bool isDark) { /* ... (Keep existing implementation) ... */
    return Drawer(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [ DrawerHeader(decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.8)), child: Text('Select Community', style: Theme.of(context).primaryTextTheme.titleLarge)), Expanded(child: _isLoadingCommunities ? const Center(child: CircularProgressIndicator()) : _userCommunities.isEmpty ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No communities joined.'))) : ListView.builder(padding: EdgeInsets.zero, itemCount: _userCommunities.length, itemBuilder: (context, index) { final community = _userCommunities[index]; final communityIdInt = community['id'] as int; final isSelected = (_selectedCommunityId == communityIdInt && _selectedEventId == null); final String? logoUrl = community['logo_url']; return ListTile(leading: CircleAvatar(backgroundColor: isSelected ? ThemeConstants.accentColor : (isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade200), backgroundImage: logoUrl != null ? NetworkImage(logoUrl) : null, child: logoUrl == null ? Text((community['name'] as String)[0].toUpperCase(), style: TextStyle(color: isSelected ? Colors.white : null, fontWeight: FontWeight.bold)) : null), title: Text(community['name'] as String, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)), selected: isSelected, selectedTileColor: ThemeConstants.accentColor.withOpacity(0.1), onTap: () => _selectCommunity(communityIdInt));},),), const Divider(height: 1), ListTile(leading: const Icon(Icons.list_alt), title: const Text('Manage Communities'), onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nav to Manage Comm (Placeholder)')));},), ]));
  }
  Widget _buildSelectedEventCardContainer(bool isDark, String? currentUserId) {
    if (_isLoadingEventDetails) return const Padding(padding: EdgeInsets.all(8.0), child: Center(child: LinearProgressIndicator(minHeight: 2)));
    if (_selectedEventDetails == null) return Container(margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), padding: const EdgeInsets.all(12.0), decoration: BoxDecoration(color: isDark ? Colors.grey.shade800.withOpacity(0.5) : Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.red.shade100)), child: const Text("Event details unavailable.", style: TextStyle(color: Colors.redAccent)));

    final event = _selectedEventDetails!;
    // Use event.isParticipatingByViewer (nullable bool) for join status
    final bool isJoined = event.isParticipatingByViewer ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ChatEventCard(
        event: event,
        isJoined: isJoined, // Pass the determined join status
        isSelected: true,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tapped event card: ${event.title}')));
          // Potentially navigate to a full event detail screen if needed
        },
        onJoin: () {
          // Implement join/leave logic for the event if this button is active
          // This might involve calling an EventService method.
          // For now, it's likely handled elsewhere or not active in this context.
          print("Join/Leave tapped for event in chat: ${event.title}");
        },
        // showJoinButton: false, // Usually false if just displaying info in chat header
        showJoinButton: true, // Or true if you want active join/leave from here
        trailingWidget: TextButton(
          onPressed: selectCommunityChat, // Go back to general community chat
          child: const Text('Back to Community Chat'),
        ),
      ),
    );
  }
  Widget _buildMessagesListContainer(bool isDark, String currentUserId) { /* ... (Keep existing implementation - already passes media to bubble) ... */
    bool showTopLoader = _isLoadingMessages && _messages.isNotEmpty && _canLoadMoreMessages;
    return Column(children: [ if (showTopLoader) const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))), Expanded(child: (_isLoadingMessages && _messages.isEmpty) ? const Center(child: CircularProgressIndicator()) : _messages.isEmpty ? Center(child: Text('No messages yet. Be the first!', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600))) : ListView.builder(controller: _scrollController, padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.smallPadding, vertical: 8.0), itemCount: _messages.length, itemBuilder: (context, index) { final messageData = _messages[index]; final bool isCurrentUserMessage = currentUserId.isNotEmpty && (messageData.user_id.toString() == currentUserId); String? senderAvatarUrl = _userAvatarCache[messageData.user_id]; if (isCurrentUserMessage) senderAvatarUrl = Provider.of<AuthProvider>(context, listen: false).userImageUrl ?? senderAvatarUrl; List<MediaItem>? uiMediaItems; if (messageData.media.isNotEmpty) { uiMediaItems = messageData.media.map((backendMedia) => MediaItem(id: backendMedia.id.toString(), url: backendMedia.url, mimeType: backendMedia.mimeType, originalFilename: backendMedia.originalFilename, fileSize: backendMedia.fileSizeBytes,)).toList(); } final displayMessage = MessageModel(id: messageData.message_id.toString(), senderId: messageData.user_id.toString(), senderName: messageData.username, content: messageData.content, timestamp: messageData.timestamp, profileImageUrl: senderAvatarUrl, media: uiMediaItems); return ChatMessageBubble(message: displayMessage, isMe: isCurrentUserMessage);},),), ]);
  }
  Widget _buildImagePreviews() { /* ... (Keep existing implementation) ... */
    if (_pickedImageFiles.isEmpty) return const SizedBox.shrink();
    return Container(height: 90, padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0), decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? ThemeConstants.backgroundDark.withOpacity(0.5) : Colors.grey.shade100, border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5))),
      child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _pickedImageFiles.length, itemBuilder: (context, index) {
        return Padding(padding: const EdgeInsets.only(right: 8.0), child: Stack(alignment: Alignment.topRight, children: [ ClipRRect(borderRadius: BorderRadius.circular(8.0), child: Image.file(_pickedImageFiles[index], width: 70, height: 70, fit: BoxFit.cover)), InkWell(onTap: () => _removePickedImage(index), child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 14))), ]));},),);
  }
  Widget _buildMessageInput(bool isDark) { /* ... (Keep existing implementation with emoji button) ... */
    return StreamBuilder<String>(stream: Provider.of<WebSocketService>(context, listen: false).connectionState, initialData: 'disconnected',
      builder: (context, snapshot) {
        final wsService = Provider.of<WebSocketService>(context, listen: false); final connectionState = snapshot.data; final String? targetRoomKey = getRoomKey(_selectedEventId != null ? 'event' : 'community', _selectedEventId ?? _selectedCommunityId); final String? connectedRoomKey = wsService.currentRoomKey; final bool isConnectedToCorrectRoom = connectionState == 'connected' && (connectedRoomKey == targetRoomKey) && targetRoomKey != null; final bool canSendViaHttp = _pickedImageFiles.isNotEmpty || _messageController.text.trim().isNotEmpty; final bool canTrySend = (isConnectedToCorrectRoom || _pickedImageFiles.isNotEmpty) && !_isSendingMessage;
        return Container(padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), decoration: BoxDecoration(color: isDark ? ThemeConstants.backgroundDarker : Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, -2))]),
            child: SafeArea(child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              IconButton(icon: Icon(_showEmojiPicker ? Icons.keyboard_alt_outlined : Icons.emoji_emotions_outlined, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600), tooltip: "Toggle Emojis", onPressed: _toggleEmojiPicker),
              IconButton(icon: Icon(Icons.add_photo_alternate_outlined, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600), tooltip: "Attach Images", onPressed: _pickChatImages),
              Expanded(child: TextField(controller: _messageController, focusNode: _messageFocusNode, decoration: InputDecoration(hintText: (isConnectedToCorrectRoom || _pickedImageFiles.isNotEmpty) ? 'Type a message...' : 'Connect to chat...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), filled: true, fillColor: isDark ? ThemeConstants.backgroundDark : Colors.grey.shade100, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), isDense: true), minLines: 1, maxLines: 5, textCapitalization: TextCapitalization.sentences, textInputAction: TextInputAction.send, onSubmitted: canTrySend && canSendViaHttp ? (_) => _sendMessage() : null, enabled: canTrySend, onTap: () { if (_showEmojiPicker && mounted) setState(() => _showEmojiPicker = false); },)),
              const SizedBox(width: 8),
              CircleAvatar(radius: 22, backgroundColor: canTrySend && canSendViaHttp ? ThemeConstants.accentColor : Colors.grey, child: _isSendingMessage ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : IconButton(icon: const Icon(Icons.send), color: Colors.white, tooltip: "Send Message", onPressed: canTrySend && canSendViaHttp ? _sendMessage : null))
            ]))
        );
      },);
  }
  Widget _buildNotLoggedInView(bool isDark) { /* ... (Keep existing implementation) ... */
    final theme = Theme.of(context); return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.chat_bubble_outline, size: 80, color: isDark ? Colors.grey.shade700 : Colors.grey.shade400), const SizedBox(height: 20), Text('Login to Chat', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700), textAlign: TextAlign.center), const SizedBox(height: 8), Text('Join communities and events to start chatting!', style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600), textAlign: TextAlign.center), const SizedBox(height: 30), ElevatedButton.icon(icon: const Icon(Icons.login), label: const Text('Go to Login'), onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false), style: ElevatedButton.styleFrom(backgroundColor: ThemeConstants.accentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), textStyle: const TextStyle(fontSize: 16))), ])));
  }
  String? getRoomKey(String? type, int? id) { /* ... (Keep existing implementation) ... */
    if (type == null || id == null || id <= 0) return null; return "${type}_${id}";
  }
}