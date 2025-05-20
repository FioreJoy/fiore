import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

// --- Data Layer ---
import '../../../../data/datasources/remote/websocket_service.dart';
import '../../../../data/datasources/remote/chat_api.dart';
import '../../../../data/datasources/remote/user_api.dart';
import '../../../../data/datasources/remote/event_api.dart';
import '../../../../data/datasources/remote/community_api.dart';
import '../../../../data/models/chat_message_data.dart';
import '../../../../data/models/event_model.dart';
// message_model.dart might not be directly needed if ChatMessageBubble takes ChatMessageData
// If ChatMessageBubble *transforms* ChatMessageData into MessageModel internally, then it's fine.
// For now, assume MessageModel/MediaItem from message_model.dart are useful within ChatMessageBubble

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
// AppConstants may not be directly used if defaults are in other widgets/services
// import '../../../../core/constants/app_constants.dart';
import '../../../../data/datasources/remote/api_endpoints.dart'; // If any endpoint strings are used directly

class ChatScreen extends StatefulWidget {
  final int? communityId;
  final String? communityName;
  final int? eventId;
  final String? eventName;

  const ChatScreen({
    /* Constructor same as before */
    Key? key,
    this.communityId,
    this.communityName,
    this.eventId,
    this.eventName,
  })  : assert(communityId != null || eventId != null,
            'Either communityId or eventId must be provided.'),
        assert(communityId == null || eventId == null,
            'Cannot provide both communityId and eventId.'),
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

  List<ChatMessageData> _messages = [];
  List<Map<String, dynamic>> _userCommunities = [];
  EventModel? _currentEventDetails;

  bool _isLoadingMessages = true; // Start true to show loader initially
  bool _isLoadingRoomDetails = true;
  bool _isSendingMessage = false;
  bool _canLoadMoreMessages = true;

  StreamSubscription? _wsMessagesSubscription;
  StreamSubscription? _wsConnectionStateSubscription;
  final Map<int, String?> _userAvatarCache = {};
  List<File> _pickedImageFiles = [];
  bool _showEmojiPicker = false;
  String _currentWsConnectionState = 'disconnected';

  @override
  void initState() {
    super.initState();
    _messageFocusNode.addListener(_onFocusChange);
    if (widget.eventId != null) {
      _currentRoomType = 'event';
      _currentRoomId = widget.eventId!;
      _currentRoomName = widget.eventName ?? 'Event Chat';
    } else {
      _currentRoomType = 'community';
      _currentRoomId = widget.communityId!;
      _currentRoomName = widget.communityName ?? 'Community Chat';
    }
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
    _messageController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _messageFocusNode.removeListener(_onFocusChange);
    _messageFocusNode.dispose();
    _wsMessagesSubscription?.cancel();
    _wsConnectionStateSubscription?.cancel();
    final wsService = Provider.of<WebSocketService>(context, listen: false);
    if (wsService.currentRoomKey ==
        getRoomKey(_currentRoomType, _currentRoomId)) {
      wsService.disconnect();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (_messageFocusNode.hasFocus && _showEmojiPicker && mounted)
      setState(() => _showEmojiPicker = false);
  }

  Future<void> _initializeChat() async {
    /* ... Same as before, just ensure class names are right ... */
    if (!mounted) return;
    setState(() => _isLoadingRoomDetails = true);
    bool nameWasProvided =
        (_currentRoomType == 'event' && widget.eventName != null) ||
            (_currentRoomType == 'community' && widget.communityName != null);
    if (!nameWasProvided)
      await _fetchRoomDetails();
    else {
      if (mounted) setState(() => _isLoadingRoomDetails = false);
    }
    await _loadUserCommunitiesForDrawer();
    if (mounted) {
      await _loadChatHistory(isInitialLoad: true);
      _connectWebSocket();
    }
  }

  Future<void> _fetchRoomDetails() async {
    /* ... Same as before, just ensure class names for services are correct ... */
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      if (mounted) setState(() => _isLoadingRoomDetails = false);
      return;
    }
    try {
      if (_currentRoomType == 'event') {
        final eventService =
            Provider.of<EventService>(context, listen: false);
        final eventData = await eventService.getEventDetails(_currentRoomId,
            token: authProvider.token!);
        if (mounted) {
          _currentEventDetails = EventModel.fromJson(eventData);
          setState(() =>
              _currentRoomName = _currentEventDetails?.title ?? 'Event Chat');
        }
      } else {
        final communityService =
            Provider.of<CommunityService>(context, listen: false);
        final communityData = await communityService
            .getCommunityDetails(_currentRoomId, token: authProvider.token!);
        if (mounted)
          setState(() =>
              _currentRoomName = communityData['name'] ?? 'Community Chat');
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Could not load room details: ${e.toString().substring(0, (e.toString().length < 30 ? e.toString().length : 30))}...')));
    } finally {
      if (mounted) setState(() => _isLoadingRoomDetails = false);
    }
  }

  void _setupWebSocketListener() {
    /* ... Same as before ... */
    if (!mounted) return;
    final wsService = Provider.of<WebSocketService>(context, listen: false);
    _wsMessagesSubscription?.cancel();
    _wsMessagesSubscription = wsService.rawMessages.listen((messageMap) async {
      if (!mounted) return;
      final String? messageRoomKey = getRoomKey(
          messageMap['event_id'] != null ? 'event' : 'community',
          messageMap['event_id'] ?? messageMap['community_id']);
      final String? activeChatRoomKey =
          getRoomKey(_currentRoomType, _currentRoomId);
      if (messageMap.containsKey('message_id') &&
          messageRoomKey == activeChatRoomKey) {
        try {
          final chatMessage = ChatMessageData.fromJson(messageMap);
          await _ensureAvatarCached(chatMessage.user_id);
          setState(() {
            if (!_messages.any((m) => m.message_id == chatMessage.message_id)) {
              _messages.add(chatMessage);
              _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _scrollToBottom());
            }
          });
        } catch (e) {/* print("Error parsing WS message: $e"); */}
      }
    }, onError: (error) {/* print("Error on WS stream: $error"); */});
    _wsConnectionStateSubscription?.cancel();
    _wsConnectionStateSubscription = wsService.connectionState.listen((state) {
      if (mounted) setState(() => _currentWsConnectionState = state);
    });
  }

  Future<void> _ensureAvatarCached(int userId) async {
    /* ... Same as before ... */
    if (_userAvatarCache.containsKey(userId) || !mounted) return;
    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userProfile =
          await userService.getUserProfile(userId, token: authProvider.token);
      if (mounted)
        _userAvatarCache[userId] = userProfile['image_url'] as String?;
    } catch (e) {
      if (mounted) _userAvatarCache[userId] = null;
    }
  }

  Future<void> _loadUserCommunitiesForDrawer() async {
    /* ... Same as before ... */
    if (!mounted) return;
    final userService = Provider.of<UserService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      if (mounted) setState(() => _userCommunities = []);
      return;
    }
    try {
      final communitiesData =
          await userService.getMyJoinedCommunities(authProvider.token!);
      if (mounted)
        setState(() => _userCommunities =
            List<Map<String, dynamic>>.from(communitiesData));
    } catch (e) {/* print('Error loading communities: $e'); */}
  }

  Future<void> _loadChatHistory(
      {bool isInitialLoad = false, int? beforeMessageId}) async {
    /* ... Same as before, ensure ChatApiService is used ... */
    if (!mounted) return;
    if (isInitialLoad) {
      setState(() {
        _isLoadingMessages = true;
        _messages = [];
        _canLoadMoreMessages = true;
      });
    } else if (_isLoadingMessages || !_canLoadMoreMessages) {
      return;
    } else {
      setState(() => _isLoadingMessages = true);
    }
    final chatService = Provider.of<ChatService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      if (mounted)
        setState(() {
          _isLoadingMessages = false;
          _messages = [];
        });
      return;
    }
    try {
      final List<dynamic> messagesData = await chatService.getChatMessages(
        token: authProvider.token!,
        communityId: _currentRoomType == 'community' ? _currentRoomId : null,
        eventId: _currentRoomType == 'event' ? _currentRoomId : null,
        limit: 50,
        beforeId: beforeMessageId,
      );
      if (!mounted) return;
      final newMessages = messagesData
          .map((m) => ChatMessageData.fromJson(m as Map<String, dynamic>))
          .toList();
      for (var msg in newMessages) {
        await _ensureAvatarCached(msg.user_id);
      }
      newMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      setState(() {
        if (isInitialLoad)
          _messages = newMessages;
        else
          _messages.insertAll(0, newMessages);
        _isLoadingMessages = false;
        _canLoadMoreMessages = newMessages.length >= 50;
      });
      if (isInitialLoad)
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom(true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Error loading messages: ${e.toString().replaceFirst("Exception: ", "")}')));
        setState(() {
          _isLoadingMessages = false;
        });
      }
    }
  }

  void _scrollListener() {
    /* ... Same as before ... */ if (_scrollController.hasClients &&
        _scrollController.position.pixels < 100 &&
        !_isLoadingMessages &&
        _canLoadMoreMessages) {
      final oldestMessageId =
          _messages.isNotEmpty ? _messages.first.message_id : null;
      if (oldestMessageId != null)
        _loadChatHistory(beforeMessageId: oldestMessageId);
    }
  }

  void _connectWebSocket() {
    /* ... Same as before ... */ final token =
        Provider.of<AuthProvider>(context, listen: false).token;
    final wsService = Provider.of<WebSocketService>(context, listen: false);
    if (token != null)
      wsService.connect(_currentRoomType, _currentRoomId, token);
    else
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Auth error for chat.')));
  }

  void _toggleDrawer() {
    /* ... Same as before ... */ if (_scaffoldKey.currentState?.isDrawerOpen ??
        false)
      Navigator.of(context).pop();
    else
      _scaffoldKey.currentState?.openDrawer();
  }

  void _switchToRoom(String newRoomType, int newRoomId, String newRoomName) {
    /* ... Same as before ... */ if (!mounted) return;
    if (_currentRoomType == newRoomType && _currentRoomId == newRoomId) {
      Navigator.of(context).pop();
      return;
    }
    final wsService = Provider.of<WebSocketService>(context, listen: false);
    if (wsService.isConnected) wsService.disconnect();
    setState(() {
      _currentRoomType = newRoomType;
      _currentRoomId = newRoomId;
      _currentRoomName = newRoomName;
      _messages = [];
      _currentEventDetails = null;
      _isLoadingMessages = true;
      _isLoadingRoomDetails = true;
      _canLoadMoreMessages = true;
      _pickedImageFiles = [];
      _showEmojiPicker = false;
    });
    Navigator.of(context).pop();
    _initializeChat();
  }

  Future<void> _pickChatImages() async {
    /* ... Same as before ... */ final picker = ImagePicker();
    try {
      final List<XFile> pickedXFiles =
          await picker.pickMultiImage(imageQuality: 70, maxWidth: 1080);
      if (pickedXFiles.isNotEmpty && mounted) {
        setState(() {
          for (var xfile in pickedXFiles) {
            if (_pickedImageFiles.length < 3)
              _pickedImageFiles.add(File(xfile.path));
            else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Max 3 images.'),
                  backgroundColor: Colors.orange));
              break;
            }
          }
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Error picking images.'),
            backgroundColor: Colors.red));
    }
  }

  void _removePickedImage(int index) {
    /* ... Same as before ... */ if (mounted &&
        index >= 0 &&
        index < _pickedImageFiles.length)
      setState(() => _pickedImageFiles.removeAt(index));
  }

  void _toggleEmojiPicker() {
    /* ... Same as before ... */ if (mounted) {
      if (_showEmojiPicker)
        setState(() => _showEmojiPicker = false);
      else {
        if (_messageFocusNode.hasFocus) {
          _messageFocusNode.unfocus();
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) setState(() => _showEmojiPicker = true);
          });
        } else
          setState(() => _showEmojiPicker = true);
      }
    }
  }

  Future<void> _sendMessage() async {
    /* ... Same as before, ensure ChatApiService is used ... */ final messageText =
        _messageController.text.trim();
    if ((messageText.isEmpty && _pickedImageFiles.isEmpty) ||
        !mounted ||
        _isSendingMessage) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Log in to send.')));
      return;
    }
    final chatService = Provider.of<ChatService>(context, listen: false);
    setState(() => _isSendingMessage = true);
    try {
      await chatService.sendChatMessageWithMedia(
        token: authProvider.token!,
        content: messageText,
        communityId: _currentRoomType == 'community' ? _currentRoomId : null,
        eventId: _currentRoomType == 'event' ? _currentRoomId : null,
        files: _pickedImageFiles.isNotEmpty ? _pickedImageFiles : null,
      );
      _messageController.clear();
      if (mounted) setState(() => _pickedImageFiles = []);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Failed to send: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSendingMessage = false);
    }
  }

  void _scrollToBottom([bool jump = false]) {
    /* ... Same as before ... */ if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (jump)
          _scrollController.jumpTo(maxScroll);
        else {
          final currentScroll = _scrollController.position.pixels;
          if ((maxScroll - currentScroll) < 200)
            _scrollController.animateTo(maxScroll,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut);
        }
      }
    });
  }

  String? getRoomKey(String? type, int? id) {
    /* ... Same as before ... */ if (type == null || id == null || id <= 0)
      return null;
    return "${type}_$id";
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);

    return WillPopScope(
      onWillPop: () async {
        if (_showEmojiPicker) {
          setState(() => _showEmojiPicker = false);
          return false;
        }
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(
            _isLoadingRoomDetails ? "Loading Chat..." : _currentRoomName,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            tooltip: "Select Room",
            onPressed: _toggleDrawer,
          ),
        ),
        drawer: ChatDrawer(
          // Use the new widget
          userCommunities: _userCommunities,
          currentRoomType: _currentRoomType,
          currentRoomId: _currentRoomId,
          switchToRoom: _switchToRoom,
          isDark: isDark,
        ),
        body: !authProvider.isAuthenticated
            ? ChatNotLoggedInView(isDark: isDark) // Use the new widget
            : Column(
                children: [
                  if (_currentRoomType == 'event')
                    ChatSelectedEventCard(
                      // Use the new widget
                      currentEventDetails: _currentEventDetails,
                      isLoadingRoomDetails: _isLoadingRoomDetails,
                      switchToRoom: _switchToRoom,
                      userCommunities: _userCommunities,
                    ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_showEmojiPicker && mounted)
                          setState(() => _showEmojiPicker = false);
                        FocusScope.of(context).unfocus();
                      },
                      child: ChatMessagesList(
                        // Use the new widget
                        isLoadingMessages: _isLoadingMessages,
                        messages: _messages,
                        canLoadMoreMessages: _canLoadMoreMessages,
                        scrollController: _scrollController,
                        userAvatarCache: _userAvatarCache,
                      ),
                    ),
                  ),
                  if (_pickedImageFiles.isNotEmpty)
                    ChatImagePreviews(
                        // Use the new widget
                        pickedImageFiles: _pickedImageFiles,
                        onRemoveImage: _removePickedImage),
                  ChatMessageInputBar(
                    // Use the new widget
                    messageController: _messageController,
                    messageFocusNode: _messageFocusNode,
                    isSendingMessage: _isSendingMessage,
                    showEmojiPicker: _showEmojiPicker,
                    canSendMessage: (_currentWsConnectionState == 'connected' ||
                            _pickedImageFiles.isNotEmpty) &&
                        !_isSendingMessage &&
                        (_messageController.text.trim().isNotEmpty ||
                            _pickedImageFiles.isNotEmpty),
                    onSendMessage: _sendMessage,
                    onToggleEmojiPicker: _toggleEmojiPicker,
                    onPickImages: _pickChatImages,
                  ),
                  Offstage(
                    // Emoji Picker (Keep direct implementation)
                    offstage: !_showEmojiPicker,
                    child: SizedBox(
                      height: 250,
                      child: EmojiPicker(
                        onEmojiSelected: (Category? category, Emoji emoji) {
                          _messageController
                            ..text += emoji.emoji
                            ..selection = TextSelection.fromPosition(
                                TextPosition(
                                    offset: _messageController.text.length));
                        },
                        onBackspacePressed: () {
                          _messageController
                            ..text = _messageController.text.characters
                                .skipLast(1)
                                .toString()
                            ..selection = TextSelection.fromPosition(
                                TextPosition(
                                    offset: _messageController.text.length));
                        },
                        config: Config(
                          checkPlatformCompatibility: true,
                          emojiSizeMax: 32 * (Platform.isIOS ? 1.30 : 1.0),
                          columns: 7,
                          verticalSpacing: 0,
                          horizontalSpacing: 0,
                          gridPadding: EdgeInsets.zero,
                          initCategory: Category.RECENT,
                          bgColor: isDark
                              ? ThemeConstants.backgroundDarker
                              : Colors.grey.shade100,
                          indicatorColor: ThemeConstants.accentColor,
                          iconColor: Colors.grey,
                          iconColorSelected: ThemeConstants.accentColor,
                          backspaceColor: ThemeConstants.accentColor,
                          skinToneDialogBgColor: Colors.white,
                          skinToneIndicatorColor: Colors.grey,
                          enableSkinTones: true,
                          recentTabBehavior: RecentTabBehavior.RECENT,
                          recentsLimit: 28,
                          replaceEmojiOnLimitExceed: false,
                          noRecents: Text('No Recents',
                              style: TextStyle(
                                  fontSize: 20, color: Colors.grey.shade600),
                              textAlign: TextAlign.center),
                          loadingIndicator: const SizedBox.shrink(),
                          tabIndicatorAnimDuration: kTabScrollDuration,
                          categoryIcons: const CategoryIcons(),
                          buttonMode: ButtonMode.MATERIAL,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
