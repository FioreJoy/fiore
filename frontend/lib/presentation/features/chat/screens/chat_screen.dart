// frontend/lib/presentation/features/chat/screens/chat_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

// --- Data Layer ---
import '../../../../data/datasources/remote/websocket_service.dart';
import '../../../../data/datasources/remote/chat_api.dart';
import '../../../../data/datasources/remote/user_api.dart';
import '../../../../data/datasources/remote/event_api.dart';
import '../../../../data/datasources/remote/community_api.dart';
import '../../../../data/models/chat_message_data.dart';
import '../../../../data/models/event_model.dart';

// --- Presentation Layer (Providers & Own Widgets) ---
import '../../../providers/auth_provider.dart';
import '../widgets/chat_drawer.dart';
import '../widgets/chat_selected_event_card.dart';
import '../widgets/chat_messages_list.dart';
import '../widgets/chat_image_previews.dart';
import '../widgets/chat_message_input_bar.dart';
import '../widgets/chat_not_logged_in.dart';

// --- Core ---
import '../../../../core/theme/theme_constants.dart';

// Typedefs
typedef ChatApiService = ChatService;
typedef UserApiService = UserService;
typedef EventApiService = EventService;
typedef CommunityApiService = CommunityService;

class ChatScreen extends StatefulWidget {
  final int? communityId;
  final String? communityName;
  final int? eventId;
  final String? eventName;
  final int? dmRecipientUserId;
  final String? dmRecipientName;
  final String? dmRecipientAvatarUrl;

  const ChatScreen({
    Key? key,
    this.communityId,
    this.communityName,
    this.eventId,
    this.eventName,
    this.dmRecipientUserId,
    this.dmRecipientName,
    this.dmRecipientAvatarUrl,
  })  : assert(
  (communityId != null && eventId == null && dmRecipientUserId == null) ||
      (communityId == null && eventId != null && dmRecipientUserId == null) ||
      (communityId == null && eventId == null && dmRecipientUserId != null),
  'Exactly one of communityId, eventId, or dmRecipientUserId must be provided.'),
        super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late String _currentRoomType;
  late int _currentRoomId;
  String _currentRoomName = "Chat";
  String? _currentRoomAvatarUrl;
  EventModel? _currentEventDetails;

  List<ChatMessageData> _messages = [];
  bool _isLoadingMessages = true;
  bool _canLoadMoreMessages = true;
  bool _isLoadingRoomDetails = true;
  bool _isSendingMessage = false;
  List<File> _pickedImageFiles = [];
  bool _showEmojiPicker = false;
  String _currentWsConnectionState = 'disconnected';
  String? _errorLoading;
  List<Map<String, dynamic>> _userCommunitiesForDrawer = [];
  StreamSubscription? _wsMessagesSubscription;
  StreamSubscription? _wsConnectionStateSubscription;
  final Map<int, String?> _userAvatarCache = {};
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _myUserId = Provider.of<AuthProvider>(context, listen: false).userId;
        if (_myUserId == null) {
          print("ChatScreen CRITICAL: My User ID is null in initState. This will break DM functionality.");
        }
        _setupInitialRoomState();
        _messageFocusNode.addListener(_onFocusChange);
        _scrollController.addListener(_scrollListener);
        _initializeChatScreenData();
        _setupWebSocketListeners();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _messageFocusNode.removeListener(_onFocusChange);
    _messageFocusNode.dispose();
    _wsMessagesSubscription?.cancel();
    _wsConnectionStateSubscription?.cancel();
    _disconnectWebSocketIfCurrent();
    super.dispose();
  }

  void _setupInitialRoomState() {
    if (widget.communityId != null) {
      _currentRoomType = 'community'; _currentRoomId = widget.communityId!;
      _currentRoomName = widget.communityName ?? 'Community Chat';
    } else if (widget.eventId != null) {
      _currentRoomType = 'event'; _currentRoomId = widget.eventId!;
      _currentRoomName = widget.eventName ?? 'Event Chat';
    } else if (widget.dmRecipientUserId != null) {
      _currentRoomType = 'dm'; _currentRoomId = widget.dmRecipientUserId!;
      _currentRoomName = widget.dmRecipientName ?? 'Direct Message';
      _currentRoomAvatarUrl = widget.dmRecipientAvatarUrl;
    }
  }

  Future<void> _initializeChatScreenData() async {
    if (!mounted) return; setState(() => _isLoadingRoomDetails = true);
    bool nameWasProvided = (_currentRoomType == 'event' && widget.eventName != null) || (_currentRoomType == 'community' && widget.communityName != null) || (_currentRoomType == 'dm' && widget.dmRecipientName != null);
    if (!nameWasProvided) await _fetchCurrentRoomDetails();
    if(_currentRoomType == 'dm' && _currentRoomAvatarUrl == null && _currentRoomId != 0) await _fetchRecipientUserDetails(_currentRoomId);
    await _loadUserCommunitiesForDrawer();
    if (mounted) { await _loadChatHistory(isInitialLoad: true); _connectWebSocket(); setState(() => _isLoadingRoomDetails = false); }
  }

  Future<void> _fetchCurrentRoomDetails() async {
    if (!mounted) return; final authProvider = Provider.of<AuthProvider>(context, listen: false); if (!authProvider.isAuthenticated || authProvider.token == null) return;
    try { if (_currentRoomType == 'event') { final eventService = Provider.of<EventApiService>(context, listen: false); final eventData = await eventService.getEventDetails(_currentRoomId, token: authProvider.token!); if (mounted) { _currentEventDetails = EventModel.fromJson(eventData); setState(() => _currentRoomName = _currentEventDetails?.title ?? 'Event Chat'); } } else if (_currentRoomType == 'community') { final communityService = Provider.of<CommunityApiService>(context, listen: false); final communityData = await communityService.getCommunityDetails(_currentRoomId, token: authProvider.token!); if (mounted) setState(() => _currentRoomName = communityData['name'] ?? 'Community Chat'); } else if (_currentRoomType == 'dm') { await _fetchRecipientUserDetails(_currentRoomId); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Room details error: ${e.toString().substring(0, (e.toString().length < 30 ? e.toString().length : 30))}...'))); }
  }

  Future<void> _fetchRecipientUserDetails(int recipientUserId) async {
    if (!mounted) return; final authProvider = Provider.of<AuthProvider>(context, listen: false); if (!authProvider.isAuthenticated || authProvider.token == null) return;
    try { final userService = Provider.of<UserApiService>(context, listen: false); final userData = await userService.getUserProfile(recipientUserId, token: authProvider.token); if (mounted) { setState(() { _currentRoomName = widget.dmRecipientName ?? userData['name'] ?? userData['username'] ?? 'Direct Message'; _currentRoomAvatarUrl = widget.dmRecipientAvatarUrl ?? userData['image_url']; }); }
    } catch (e) { if (mounted) print("ChatScreen: Error fetching DM recipient details: $e");}
  }

  Future<void> _loadUserCommunitiesForDrawer() async {
    if (!mounted) return; final userService = Provider.of<UserApiService>(context, listen: false); final authProvider = Provider.of<AuthProvider>(context, listen: false); if (!authProvider.isAuthenticated || authProvider.token == null) { if (mounted) setState(() => _userCommunitiesForDrawer = []); return; }
    try { final communitiesData = await userService.getMyJoinedCommunities(authProvider.token!); if (mounted) setState(() => _userCommunitiesForDrawer = List<Map<String, dynamic>>.from(communitiesData)); } catch (e) { /* Handled by auth check or service */ }
  }

  Future<void> _loadChatHistory({bool isInitialLoad = false, int? beforeMessageId}) async {
    if (!mounted) return;
    if (isInitialLoad) setState(() { _isLoadingMessages = true; _messages = []; _canLoadMoreMessages = true; });
    else if (_isLoadingMessages || !_canLoadMoreMessages) return;
    else setState(() => _isLoadingMessages = true);

    final chatService = Provider.of<ChatApiService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null || _myUserId == null) {
      if (mounted) setState(() { _isLoadingMessages = false; _messages = []; _errorLoading = "Auth error or User ID missing."; });
      return;
    }

    try {
      final List<dynamic> messagesData;
      if (_currentRoomType == 'dm') {
        messagesData = await chatService.getChatMessages(
            token: authProvider.token!, limit: 50, beforeId: beforeMessageId, dmWithUserId: _currentRoomId
        );
        print("ChatScreen: Fetching DM history for me: $_myUserId with: $_currentRoomId");
      } else {
        messagesData = await chatService.getChatMessages(
          token: authProvider.token!, communityId: _currentRoomType == 'community' ? _currentRoomId : null,
          eventId: _currentRoomType == 'event' ? _currentRoomId : null, limit: 50, beforeId: beforeMessageId,
        );
      }
      if (!mounted) return;
      final newMessages = messagesData.map((m) => ChatMessageData.fromJson(m as Map<String, dynamic>)).toList();
      for (var msg in newMessages) { await _ensureAvatarCached(msg.user_id); }
      newMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      setState(() {
        if (isInitialLoad) _messages = newMessages; else _messages.insertAll(0, newMessages);
        _isLoadingMessages = false; _canLoadMoreMessages = newMessages.length >= 50; _errorLoading = null;
      });
      if (isInitialLoad) WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(true));
    } catch (e) {
      if (mounted) setState(() { _isLoadingMessages = false; _errorLoading = "Messages error: ${e.toString().replaceFirst("Exception: ", "")}"; });
    }
  }

  Future<void> _ensureAvatarCached(int userId) async {
    if (_userAvatarCache.containsKey(userId) || !mounted) return;
    try {
      final userService = Provider.of<UserApiService>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token == null) return; // Avoid API call if not authed
      final userProfile = await userService.getUserProfile(userId, token: authProvider.token);
      if (mounted) _userAvatarCache[userId] = userProfile['image_url'] as String?;
    } catch (e) { if (mounted) _userAvatarCache[userId] = null; }
  }

  void _setupWebSocketListeners() {
    if (!mounted) return; final wsService = Provider.of<WebSocketService>(context, listen: false);
    _wsMessagesSubscription?.cancel();
    _wsMessagesSubscription = wsService.rawMessages.listen(_handleIncomingWsMessage, onError: (error) {});
    _wsConnectionStateSubscription?.cancel();
    _wsConnectionStateSubscription = wsService.connectionState.listen((state) { if (mounted) setState(() => _currentWsConnectionState = state); });
  }

  void _handleIncomingWsMessage(Map<String, dynamic> messageMap) async {
    if (!mounted || _myUserId == null) return;
    final String? messageRoomKey = _getRoomKeyFromMessage(messageMap);
    final String? activeChatRoomKey = _generateCurrentRoomKey();
    if (messageMap.containsKey('message_id') && messageRoomKey == activeChatRoomKey) {
      try { final chatMessage = ChatMessageData.fromJson(messageMap); await _ensureAvatarCached(chatMessage.user_id);
      if (mounted && !_messages.any((m) => m.message_id == chatMessage.message_id)) {
        setState(() { _messages.add(chatMessage); _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp)); });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
      } catch (e) { /* Logged by WS service */ }
    }
  }

  void _connectWebSocket() {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    final currentMyUserId = _myUserId;
    final wsService = Provider.of<WebSocketService>(context, listen: false);
    if (token != null && currentMyUserId != null) {
      wsService.connect(_currentRoomType, _currentRoomId, token, currentMyUserId);
    } else {
      String errorMsg = "Auth error for chat. ";
      if(token == null) errorMsg += "Token missing. ";
      if(currentMyUserId == null) errorMsg += "User ID missing for DM context. ";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
    }
  }

  void _disconnectWebSocketIfCurrent() {
    final wsService = Provider.of<WebSocketService>(context, listen: false);
    if (wsService.currentRoomKeyAttemptingOrConnected == _generateCurrentRoomKey()) {
      wsService.disconnect();
    }
  }

  void _onFocusChange() { if (_messageFocusNode.hasFocus && _showEmojiPicker && mounted) setState(() => _showEmojiPicker = false); }
  void _scrollListener() { if (_scrollController.hasClients && _scrollController.position.pixels < 100 && !_isLoadingMessages && _canLoadMoreMessages) { final oldestMessageId = _messages.isNotEmpty ? _messages.first.message_id : null; if (oldestMessageId != null) _loadChatHistory(beforeMessageId: oldestMessageId); } }
  void _toggleDrawer() => _scaffoldKey.currentState?.openDrawer();
  Future<void> _pickChatImages() async { final picker = ImagePicker(); try { final List<XFile> pickedXFiles = await picker.pickMultiImage(imageQuality: 70, maxWidth: 1080); if (pickedXFiles.isNotEmpty && mounted) { setState(() { for (var xfile in pickedXFiles) { if (_pickedImageFiles.length < 3) _pickedImageFiles.add(File(xfile.path)); else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Max 3 images.'), backgroundColor: Colors.orange)); break; } } }); } } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error picking images.'), backgroundColor: Colors.red)); } }
  void _removePickedImage(int index) { if (mounted && index >= 0 && index < _pickedImageFiles.length) setState(() => _pickedImageFiles.removeAt(index)); }
  void _toggleEmojiPicker() { if (mounted) { if (_showEmojiPicker) { setState(() => _showEmojiPicker = false); } else { if (_messageFocusNode.hasFocus) _messageFocusNode.unfocus(); Future.delayed(const Duration(milliseconds: 100), () { if (mounted) setState(() => _showEmojiPicker = true); }); } } }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if ((messageText.isEmpty && _pickedImageFiles.isEmpty) || !mounted || _isSendingMessage) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null || _myUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Log in to send messages.'))); return;
    }
    final chatService = Provider.of<ChatApiService>(context, listen: false);
    setState(() => _isSendingMessage = true);
    try {
      await chatService.sendChatMessageWithMedia(
        token: authProvider.token!,
        content: messageText,
        communityId: _currentRoomType == 'community' ? _currentRoomId : null,
        eventId: _currentRoomType == 'event' ? _currentRoomId : null,
        dmRecipientUserId: _currentRoomType == 'dm' ? _currentRoomId : null,
        files: _pickedImageFiles.isNotEmpty ? _pickedImageFiles : null,
      );
      _messageController.clear();
      if (mounted) setState(() => _pickedImageFiles = []);
      _scrollToBottom(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSendingMessage = false);
    }
  }

  void _scrollToBottom([bool jump = false]) { if (!_scrollController.hasClients) return; WidgetsBinding.instance.addPostFrameCallback((_) { if (_scrollController.hasClients) { final maxScroll = _scrollController.position.maxScrollExtent; if (jump) _scrollController.jumpTo(maxScroll); else { final currentScroll = _scrollController.position.pixels; if ((maxScroll - currentScroll) < 200) _scrollController.animateTo(maxScroll, duration: const Duration(milliseconds: 300), curve: Curves.easeOut); } } }); }

  String? _generateCurrentRoomKey() {
    final String? currentActiveUserId = _myUserId;
    if (currentActiveUserId == null) { return null; }
    return _getRoomKey(_currentRoomType, _currentRoomId, currentActiveUserId);
  }

  String? _getRoomKey(String? type, int? id, String currentActiveUserId) {
    if (type == null || id == null || id <= 0 || currentActiveUserId.isEmpty) return null;
    if (type == 'dm') {
      final int? u1 = int.tryParse(currentActiveUserId);
      if (u1 == null) {return null;}
      final int u2 = id;
      if (u1 == 0 || u2 == 0 || u1 == u2) return null;
      return (u1 < u2) ? "dm_${u1}_${u2}" : "dm_${u2}_${u1}";
    }
    return "${type}_$id";
  }

  String? _getRoomKeyFromMessage(Map<String, dynamic> messageMap) {
    final String? currentActiveUserId = _myUserId;
    if (currentActiveUserId == null) return null;
    if (messageMap['community_id'] != null) {
      return _getRoomKey('community', messageMap['community_id'], currentActiveUserId);
    } else if (messageMap['event_id'] != null) {
      return _getRoomKey('event', messageMap['event_id'], currentActiveUserId);
    } else if (messageMap.containsKey('sender_id') && messageMap.containsKey('recipient_id')) {
      final int? u1 = int.tryParse(currentActiveUserId);
      if (u1 == null) return null;
      int u2 = (messageMap['sender_id'] == u1) ? messageMap['recipient_id'] : messageMap['sender_id'];
      return _getRoomKey('dm', u2, currentActiveUserId);
    }
    return null;
  }

  // CORRECTED: Parameter names in the definition to match ChatDrawer's expectation.
  void _switchToRoom(String newRoomType, int newRoomTargetId, String newRoomName,
      {int? dmRecipientId, String? dmRecipientName, String? dmRecipientAvatar}) { // Corrected parameter names
    if (!mounted) return;
    final int effectiveNewRoomId = (newRoomType == 'dm') ? dmRecipientId! : newRoomTargetId;

    if (_currentRoomType == newRoomType && _currentRoomId == effectiveNewRoomId) { Navigator.of(context).pop(); return; }
    _disconnectWebSocketIfCurrent();
    setState(() {
      _currentRoomType = newRoomType; _currentRoomId = effectiveNewRoomId;
      _currentRoomName = newRoomName;
      _currentRoomAvatarUrl = (newRoomType == 'dm') ? dmRecipientAvatar : null;
      if (newRoomType != 'event') _currentEventDetails = null;
      _messages = []; _isLoadingMessages = true; _isLoadingRoomDetails = true;
      _canLoadMoreMessages = true; _pickedImageFiles = []; _showEmojiPicker = false;
      _errorLoading = null;
    });
    Navigator.of(context).pop();
    _initializeChatScreenData();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);

    String appBarTitle = _isLoadingRoomDetails ? "Loading Chat..." : _currentRoomName;

    return WillPopScope(
      onWillPop: () async {
        if (_showEmojiPicker) { setState(() => _showEmojiPicker = false); return false; }
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          leading: ModalRoute.of(context)?.canPop == true && Navigator.of(context).canPop()
              ? BackButton(color: theme.appBarTheme.foregroundColor ?? (isDark ? Colors.white : Colors.black))
              : IconButton(icon: Icon(Icons.menu, color: theme.appBarTheme.iconTheme?.color), tooltip: "Select Room", onPressed: _toggleDrawer),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_currentRoomType == 'dm' && _currentRoomAvatarUrl != null && _currentRoomAvatarUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: CircleAvatar( radius: 18, backgroundImage: CachedNetworkImageProvider(_currentRoomAvatarUrl!)),
                ),
              Flexible(
                child: Text( appBarTitle, style: theme.appBarTheme.titleTextStyle, overflow: TextOverflow.ellipsis,),
              ),
            ],
          ),
        ),
        drawer: ChatDrawer(
          userCommunities: _userCommunitiesForDrawer,
          directMessageContacts: [], // This should ideally come from ChatListScreen state for DMs
          currentRoomType: _currentRoomType,
          currentRoomId: _currentRoomId,
          switchToRoom: _switchToRoom, // Passed here
          isDark: isDark,
        ),
        body: !authProvider.isAuthenticated
            ? ChatNotLoggedInView(isDark: isDark)
            : Column(
          children: [
            if (_currentRoomType == 'event' && _currentEventDetails != null)
              ChatSelectedEventCard(
                currentEventDetails: _currentEventDetails, isLoadingRoomDetails: _isLoadingRoomDetails,
                switchToRoom: _switchToRoom, userCommunities: _userCommunitiesForDrawer,
              ),
            if (_errorLoading != null)
              Padding(padding: const EdgeInsets.all(8.0), child: Text(_errorLoading!, style: TextStyle(color: theme.colorScheme.error))),
            Expanded(
              child: GestureDetector(
                onTap: () { if (_showEmojiPicker && mounted) setState(() => _showEmojiPicker = false); FocusScope.of(context).unfocus(); },
                child: ChatMessagesList(
                  isLoadingMessages: _isLoadingMessages && _messages.isEmpty, messages: _messages, canLoadMoreMessages: _canLoadMoreMessages,
                  scrollController: _scrollController, userAvatarCache: _userAvatarCache,
                ),),),
            if (_pickedImageFiles.isNotEmpty)
              ChatImagePreviews(pickedImageFiles: _pickedImageFiles, onRemoveImage: _removePickedImage),
            ChatMessageInputBar(
              messageController: _messageController, messageFocusNode: _messageFocusNode, isSendingMessage: _isSendingMessage, showEmojiPicker: _showEmojiPicker,
              canSendMessage: (_currentWsConnectionState == 'connected' || _pickedImageFiles.isNotEmpty) && !_isSendingMessage && (_messageController.text.trim().isNotEmpty || _pickedImageFiles.isNotEmpty),
              onSendMessage: _sendMessage, onToggleEmojiPicker: _toggleEmojiPicker, onPickImages: _pickChatImages,
            ),
            Offstage(
              offstage: !_showEmojiPicker,
              child: SizedBox( height: 250,
                child: EmojiPicker(
                  onEmojiSelected: (Category? category, Emoji emoji) { _messageController ..text += emoji.emoji ..selection = TextSelection.fromPosition(TextPosition(offset: _messageController.text.length)); },
                  onBackspacePressed: () { _messageController ..text = _messageController.text.characters.skipLast(1).toString() ..selection = TextSelection.fromPosition(TextPosition(offset: _messageController.text.length)); },
                  config: Config( checkPlatformCompatibility: true, emojiSizeMax: 32 * (kIsWeb ? 1.0 : (Platform.isIOS ? 1.30 : 1.0)),  columns: 7, verticalSpacing: 0, horizontalSpacing: 0, gridPadding: EdgeInsets.zero, initCategory: Category.RECENT,
                    bgColor: isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade100, indicatorColor: ThemeConstants.accentColor, iconColor: Colors.grey, iconColorSelected: ThemeConstants.accentColor,
                    backspaceColor: ThemeConstants.accentColor, skinToneDialogBgColor: Colors.white, skinToneIndicatorColor: Colors.grey, enableSkinTones: true,
                    recentTabBehavior: RecentTabBehavior.RECENT, recentsLimit: 28, replaceEmojiOnLimitExceed: false,
                    noRecents: Text('No Recents', style: TextStyle(fontSize: 20, color: Colors.grey.shade600), textAlign: TextAlign.center),
                    loadingIndicator: const SizedBox.shrink(), tabIndicatorAnimDuration: kTabScrollDuration, categoryIcons: const CategoryIcons(), buttonMode: ButtonMode.MATERIAL,
                  ),),),),
          ],
        ),
      ),
    );
  }
}