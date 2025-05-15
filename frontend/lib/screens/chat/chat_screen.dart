// frontend/lib/screens/chat/chat_screen.dart

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
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
import '../../services/api/community_service.dart'; 

// --- Model Imports ---
import '../../models/chat_message_data.dart';
import '../../models/event_model.dart';
import '../../models/message_model.dart'; 

// --- Widget Imports ---
import '../../widgets/chat_message_bubble.dart';
import '../../widgets/chat_event_card.dart';

// --- Theme and Constants ---
import '../../theme/theme_constants.dart';
import '../../app_constants.dart';


class ChatScreen extends StatefulWidget {
  final int? communityId;
  final String? communityName;
  final int? eventId;
  final String? eventName;

  const ChatScreen({
    Key? key,
    this.communityId,
    this.communityName,
    this.eventId,
    this.eventName,
  }) : assert(communityId != null || eventId != null, 'Either communityId or eventId must be provided.'),
       assert(communityId == null || eventId == null, 'Cannot provide both communityId and eventId.'),
       super(key: key);

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

  late String _currentRoomType;
  late int _currentRoomId;
  String _currentRoomName = "Chat";

  List<ChatMessageData> _messages = [];
  List<Map<String, dynamic>> _userCommunities = []; 
  EventModel? _currentEventDetails;

  bool _isLoadingMessages = false;
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
    print("ChatScreen disposing for $_currentRoomType $_currentRoomId...");
    _messageController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _messageFocusNode.removeListener(_onFocusChange);
    _messageFocusNode.dispose();
    _wsMessagesSubscription?.cancel();
    _wsConnectionStateSubscription?.cancel();

    final wsService = Provider.of<WebSocketService>(context, listen: false);
    if (wsService.currentRoomKey == getRoomKey(_currentRoomType, _currentRoomId)) {
      print("ChatScreen dispose: Disconnecting WebSocket for room ${wsService.currentRoomKey}");
      wsService.disconnect();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (_messageFocusNode.hasFocus && _showEmojiPicker && mounted) {
      setState(() => _showEmojiPicker = false);
    }
  }

  Future<void> _initializeChat() async {
    if (!mounted) return;
    setState(() => _isLoadingRoomDetails = true);

    bool nameWasProvided = (_currentRoomType == 'event' && widget.eventName != null) ||
                           (_currentRoomType == 'community' && widget.communityName != null);

    if (!nameWasProvided) {
      await _fetchRoomDetails();
    } else {
       if(mounted) setState(() => _isLoadingRoomDetails = false);
    }

    await _loadUserCommunitiesForDrawer(); 
    if (mounted) {
      await _loadChatHistory(isInitialLoad: true);
      _connectWebSocket();
    }
  }

  Future<void> _fetchRoomDetails() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      if(mounted) setState(() => _isLoadingRoomDetails = false);
      return;
    }

    try {
      if (_currentRoomType == 'event') {
        final eventService = Provider.of<EventService>(context, listen: false);
        final eventData = await eventService.getEventDetails(_currentRoomId, token: authProvider.token!);
        if (mounted) {
          _currentEventDetails = EventModel.fromJson(eventData);
          setState(() => _currentRoomName = _currentEventDetails?.title ?? 'Event Chat');
        }
      } else { 
        final communityService = Provider.of<CommunityService>(context, listen: false);
        final communityData = await communityService.getCommunityDetails(_currentRoomId, token: authProvider.token!);
        if (mounted) {
          setState(() => _currentRoomName = communityData['name'] ?? 'Community Chat');
        }
      }
    } catch (e) {
      print("ChatScreen: Error fetching room details for $_currentRoomType $_currentRoomId: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load room details: ${e.toString().substring(0, (e.toString().length < 30 ? e.toString().length : 30))}...')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingRoomDetails = false);
    }
  }

  void _setupWebSocketListener() {
    if (!mounted) return;
    final wsService = Provider.of<WebSocketService>(context, listen: false);
    _wsMessagesSubscription?.cancel(); 
    _wsMessagesSubscription = wsService.rawMessages.listen((messageMap) async {
      if (!mounted) return;
      final String? messageRoomKey = getRoomKey(
          messageMap['event_id'] != null ? 'event' : 'community',
          messageMap['event_id'] ?? messageMap['community_id']
      );
      final String? activeChatRoomKey = getRoomKey(_currentRoomType, _currentRoomId);

      if (messageMap.containsKey('message_id') && messageRoomKey == activeChatRoomKey) {
        try {
          final chatMessage = ChatMessageData.fromJson(messageMap);
          await _ensureAvatarCached(chatMessage.user_id);
          setState(() {
            if (!_messages.any((m) => m.message_id == chatMessage.message_id)) {
              _messages.add(chatMessage);
              _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
            }
          });
        } catch (e) { print("ChatScreen: Error parsing incoming chat message: $e"); }
      }
    }, onError: (error) { print("ChatScreen: Error on WS messages stream: $error"); });

    _wsConnectionStateSubscription?.cancel();
    _wsConnectionStateSubscription = wsService.connectionState.listen((state) {
      if (mounted) {
        setState(() {
          _currentWsConnectionState = state; 
        }); 
      }
    });
  }

  Future<void> _ensureAvatarCached(int userId) async {
    if (_userAvatarCache.containsKey(userId) || !mounted) return;
    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userProfile = await userService.getUserProfile(userId, token: authProvider.token);
      if (mounted) _userAvatarCache[userId] = userProfile['image_url'] as String?;
    } catch (e) { if (mounted) _userAvatarCache[userId] = null; }
  }

  Future<void> _loadUserCommunitiesForDrawer() async {
    if (!mounted) return;
    final userService = Provider.of<UserService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      if (mounted) setState(() => _userCommunities = []);
      return;
    }
    try {
      final communitiesData = await userService.getMyJoinedCommunities(authProvider.token!);
      if (mounted) setState(() => _userCommunities = List<Map<String, dynamic>>.from(communitiesData));
    } catch (e) { print('ChatScreen Drawer: Error loading communities: $e'); }
  }

  Future<void> _loadChatHistory({bool isInitialLoad = false, int? beforeMessageId}) async {
    if (!mounted) return;
    if (isInitialLoad) { setState(() { _isLoadingMessages = true; _messages = []; _canLoadMoreMessages = true; });}
    else if (_isLoadingMessages || !_canLoadMoreMessages) { return; }
    else { setState(() => _isLoadingMessages = true); }

    final chatService = Provider.of<ChatService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      if (mounted) setState(() { _isLoadingMessages = false; _messages = []; });
      return;
    }

    try {
      final List<dynamic> messagesData = await chatService.getChatMessages(
        token: authProvider.token!,
        communityId: _currentRoomType == 'community' ? _currentRoomId : null,
        eventId: _currentRoomType == 'event' ? _currentRoomId : null,
        limit: 50, beforeId: beforeMessageId,
      );
      if (!mounted) return;
      final newMessages = messagesData.map((m) => ChatMessageData.fromJson(m as Map<String, dynamic>)).toList();
      for (var msg in newMessages) { await _ensureAvatarCached(msg.user_id); }
      newMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp)); 
      setState(() {
        if (isInitialLoad) _messages = newMessages;
        else _messages.insertAll(0, newMessages); 
        _isLoadingMessages = false;
        _canLoadMoreMessages = newMessages.length >= 50;
      });
      if (isInitialLoad) WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(true));
    } catch (e) {
      if (mounted) {
        print("ChatScreen: Error loading chat history: $e");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading messages: ${e.toString().replaceFirst("Exception: ", "")}')));
        setState(() { _isLoadingMessages = false; });
      }
    }
  }

  void _scrollListener() {
    if (_scrollController.hasClients && _scrollController.position.pixels < 100 && 
        !_isLoadingMessages &&
        _canLoadMoreMessages) {
      final oldestMessageId = _messages.isNotEmpty ? _messages.first.message_id : null;
      if (oldestMessageId != null) {
        _loadChatHistory(beforeMessageId: oldestMessageId);
      }
    }
  }

  void _connectWebSocket() {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    final wsService = Provider.of<WebSocketService>(context, listen: false);
    if (token != null) {
      print("ChatScreen: Attempting WS connect to $_currentRoomType / $_currentRoomId");
      wsService.connect(_currentRoomType, _currentRoomId, token);
    } else {
       print("ChatScreen: Cannot connect WebSocket, token is null.");
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication error. Cannot connect to chat.')));
    }
  }

  void _toggleDrawer() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) Navigator.of(context).pop();
    else _scaffoldKey.currentState?.openDrawer();
  }

  void _switchToRoom(String newRoomType, int newRoomId, String newRoomName) {
    if (!mounted) return;
    if (_currentRoomType == newRoomType && _currentRoomId == newRoomId) {
      Navigator.of(context).pop(); return;
    }
    final wsService = Provider.of<WebSocketService>(context, listen: false);
    if (wsService.isConnected) {
      print("ChatScreen: Switching room, disconnecting from ${wsService.currentRoomKey}");
      wsService.disconnect();
    }
    setState(() {
      _currentRoomType = newRoomType; _currentRoomId = newRoomId; _currentRoomName = newRoomName;
      _messages = []; _currentEventDetails = null;
      _isLoadingMessages = true; _isLoadingRoomDetails = true; _canLoadMoreMessages = true;
      _pickedImageFiles = []; _showEmojiPicker = false;
    });
    Navigator.of(context).pop();
    _initializeChat();
  }

  Future<void> _pickChatImages() async {
    final picker = ImagePicker();
    try {
      final List<XFile> pickedXFiles = await picker.pickMultiImage(imageQuality: 70, maxWidth: 1080);
      if (pickedXFiles.isNotEmpty && mounted) {
        setState(() {
          for (var xfile in pickedXFiles) {
            if (_pickedImageFiles.length < 3) _pickedImageFiles.add(File(xfile.path));
            else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Max 3 images per message.'), backgroundColor: Colors.orange)); break; }
          }
        });
      }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error picking images.'), backgroundColor: Colors.red)); }
  }

  void _removePickedImage(int index) {
    if (mounted && index >= 0 && index < _pickedImageFiles.length) {
      setState(() => _pickedImageFiles.removeAt(index));
    }
  }

  void _toggleEmojiPicker() {
    if (mounted) {
      if (_showEmojiPicker) { setState(() => _showEmojiPicker = false); }
      else {
        if (_messageFocusNode.hasFocus) {
          _messageFocusNode.unfocus();
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) setState(() => _showEmojiPicker = true);
          });
        } else {
          setState(() => _showEmojiPicker = true);
        }
      }
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if ((messageText.isEmpty && _pickedImageFiles.isEmpty) || !mounted || _isSendingMessage) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to send messages.')));
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSendingMessage = false);
    }
  }

  void _scrollToBottom([bool jump = false]) {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (jump) _scrollController.jumpTo(maxScroll);
        else {
          final currentScroll = _scrollController.position.pixels;
          if ((maxScroll - currentScroll) < 200) { 
            _scrollController.animateTo(maxScroll, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
          }
        }
      }
    });
  }

  String? getRoomKey(String? type, int? id) {
    if (type == null || id == null || id <= 0) return null;
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
            title: Text(_isLoadingRoomDetails ? "Loading Chat..." : _currentRoomName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            leading: IconButton(icon: const Icon(Icons.menu), tooltip: "Select Room", onPressed: _toggleDrawer)
          ),
          drawer: _buildDrawer(isDark),
          body: !authProvider.isAuthenticated
              ? _buildNotLoggedInView(isDark)
              : Column(children: [
                  // Corrected conditional rendering logic
                  if (_currentRoomType == 'event') ...[
                    if (_isLoadingRoomDetails)
                      const Padding(padding: EdgeInsets.all(8.0), child: Center(child: LinearProgressIndicator(minHeight: 2)))
                    else if (_currentEventDetails != null)
                       _buildSelectedEventCardContainer(isDark, authProvider.userId)
                    // else const SizedBox.shrink(), // Or some placeholder if details couldn't load
                  ],
                  Expanded(child: GestureDetector(
                      onTap: () { if (_showEmojiPicker && mounted) setState(() => _showEmojiPicker = false); FocusScope.of(context).unfocus(); },
                      child: _buildMessagesListContainer(isDark, authProvider.userId ?? '')
                  )),
                  if (_pickedImageFiles.isNotEmpty) _buildImagePreviews(),
                  _buildMessageInput(isDark),
                  Offstage(
                    offstage: !_showEmojiPicker, 
                    child: SizedBox(
                      height: 250, 
                      child: EmojiPicker(
                        onEmojiSelected: (Category? category, Emoji emoji) { 
                          _messageController
                            ..text += emoji.emoji
                            ..selection = TextSelection.fromPosition(TextPosition(offset: _messageController.text.length));
                        },
                        onBackspacePressed: () { 
                          _messageController
                            ..text = _messageController.text.characters.skipLast(1).toString()
                            ..selection = TextSelection.fromPosition(TextPosition(offset: _messageController.text.length));
                        },
                        config: Config(
                          //height: 250, // Define height for the EmojiPicker itself
                          checkPlatformCompatibility: true,
                          emojiSizeMax: 32 * (Platform.isIOS ? 1.30 : 1.0),
                          columns: 7,
                          verticalSpacing: 0,
                          horizontalSpacing: 0,
                          gridPadding: EdgeInsets.zero,
                          initCategory: Category.RECENT,
                          bgColor: isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade100,
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
                          noRecents: Text('No Recents', style: TextStyle(fontSize: 20, color: Colors.grey.shade600), textAlign: TextAlign.center),
                          loadingIndicator: const SizedBox.shrink(), // Needs to be const
                          tabIndicatorAnimDuration: kTabScrollDuration,
                          categoryIcons: const CategoryIcons(),
                          buttonMode: ButtonMode.MATERIAL,
                        ),
                      ),
                    ),
                  ),
                ],
          ),
        )
    );
  }

  Widget _buildDrawer(bool isDark) {
    return Drawer(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.8)),
              child: Text('Switch Chat Room', style: Theme.of(context).primaryTextTheme.titleLarge?.copyWith(color: Colors.white))
          ),
          Expanded(
            child: _userCommunities.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Join communities to chat.')))
                : ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _userCommunities.length,
              itemBuilder: (context, index) {
                final community = _userCommunities[index];
                final communityIdInt = community['id'] as int;
                final communityNameStr = community['name'] as String? ?? 'Community';
                final isSelected = (_currentRoomType == 'community' && _currentRoomId == communityIdInt);
                final String? logoUrl = community['logo_url'];
                return ListTile(
                  leading: CircleAvatar(
                      backgroundColor: isSelected ? ThemeConstants.accentColor.withOpacity(0.2) : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                      backgroundImage: logoUrl != null && logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
                      child: logoUrl == null || logoUrl.isEmpty ? Text(communityNameStr[0].toUpperCase(), style: TextStyle(color: isSelected ? ThemeConstants.accentColor : null, fontWeight: FontWeight.bold)) : null
                  ),
                  title: Text(communityNameStr, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? ThemeConstants.accentColor : null)),
                  selected: isSelected,
                  selectedTileColor: ThemeConstants.accentColor.withOpacity(0.05),
                  onTap: () => _switchToRoom('community', communityIdInt, communityNameStr),
                );
              },
            ),
          ),
        ])
    );
  }

  Widget _buildSelectedEventCardContainer(bool isDark, String? currentUserId) {
    if (_currentEventDetails == null) {
      return _isLoadingRoomDetails 
        ? const Padding(padding: EdgeInsets.all(8.0), child: Center(child: LinearProgressIndicator(minHeight: 2)))
        : const SizedBox.shrink(); 
    }

    final event = _currentEventDetails!;
    final bool isJoined = event.isParticipatingByViewer ?? false; 

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ChatEventCard( 
        event: event,
        isJoined: isJoined,
        isSelected: true, 
        showJoinButton: false, 
        trailingWidget: TextButton(
          onPressed: () {
            if(_currentEventDetails != null) {
              // Corrected: Ensure communityId is parsed to int
              int? parentCommunityId = int.tryParse(_currentEventDetails!.communityId.toString()); 
              String parentCommunityName = "Community Chat"; 
              
              final communityContext = _userCommunities.firstWhereOrNull((c) => c['id'] == parentCommunityId);
              if(communityContext != null && communityContext['name'] != null) {
                parentCommunityName = communityContext['name'];
              }

              if (parentCommunityId != null) {
                 _switchToRoom('community', parentCommunityId, parentCommunityName);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not determine parent community.')));
              }
            }
          },
          child: const Text('Back to Community', style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildMessagesListContainer(bool isDark, String currentUserId) {
    bool showTopLoader = _isLoadingMessages && _messages.isNotEmpty && _canLoadMoreMessages;
    return Column(children: [
      if (showTopLoader) const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
      Expanded(child: (_isLoadingMessages && _messages.isEmpty)
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
          : _messages.isEmpty
            ? Center(child: Text('No messages yet. Be the first!', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)))
            : ListView.builder(
                controller: _scrollController,
                reverse: false, 
                padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.smallPadding, vertical: 8.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final messageData = _messages[index];
                  final bool isCurrentUserMessage = currentUserId.isNotEmpty && (messageData.user_id.toString() == currentUserId);
                  String? senderAvatarUrl = _userAvatarCache[messageData.user_id];
                  if (isCurrentUserMessage) senderAvatarUrl = Provider.of<AuthProvider>(context, listen: false).userImageUrl ?? senderAvatarUrl;

                  List<MediaItem>? uiMediaItems;
                  if (messageData.media.isNotEmpty) {
                    uiMediaItems = messageData.media.map((backendMedia) => MediaItem(
                      id: backendMedia.id.toString(),
                      url: backendMedia.url,
                      mimeType: backendMedia.mimeType,
                      originalFilename: backendMedia.originalFilename,
                      fileSize: backendMedia.fileSizeBytes,
                    )).toList();
                  }
                  final displayMessage = MessageModel(
                      id: messageData.message_id.toString(),
                      senderId: messageData.user_id.toString(),
                      senderName: messageData.username,
                      content: messageData.content,
                      timestamp: messageData.timestamp,
                      profileImageUrl: senderAvatarUrl,
                      media: uiMediaItems
                  );
                  return ChatMessageBubble(message: displayMessage, isMe: isCurrentUserMessage);
                },
              ),
      ),
    ]);
  }

  Widget _buildImagePreviews() {
    if (_pickedImageFiles.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? ThemeConstants.backgroundDark.withOpacity(0.5) : Colors.grey.shade100,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5))
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _pickedImageFiles.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.file(_pickedImageFiles[index], width: 70, height: 70, fit: BoxFit.cover)
                ),
                InkWell(
                    onTap: () => _removePickedImage(index),
                    child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 14)
                    )
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageInput(bool isDark) {
    final wsService = Provider.of<WebSocketService>(context, listen: true); 
    // final connectionState = wsService.connectionState.valueOrNull ?? 'disconnected'; // Original error here
    final connectionState = _currentWsConnectionState; // Use local state updated by stream listener
    final String? targetRoomKey = getRoomKey(_currentRoomType, _currentRoomId);
    final String? connectedRoomKey = wsService.currentRoomKey; 
    
    final bool isConnectedToCorrectRoom = connectionState == 'connected' && (connectedRoomKey == targetRoomKey) && targetRoomKey != null;
    final bool canSendViaHttp = _pickedImageFiles.isNotEmpty || _messageController.text.trim().isNotEmpty;
    final bool canTrySend = (isConnectedToCorrectRoom || _pickedImageFiles.isNotEmpty) && !_isSendingMessage;

    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
            color: isDark ? ThemeConstants.backgroundDarker : Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, -2))]
        ),
        child: SafeArea( 
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              IconButton(icon: Icon(_showEmojiPicker ? Icons.keyboard_alt_outlined : Icons.emoji_emotions_outlined, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600), tooltip: "Toggle Emojis", onPressed: _toggleEmojiPicker),
              IconButton(icon: Icon(Icons.add_photo_alternate_outlined, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600), tooltip: "Attach Images", onPressed: _pickChatImages),
              Expanded(child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                decoration: InputDecoration(
                    hintText: (isConnectedToCorrectRoom || _pickedImageFiles.isNotEmpty) ? 'Type a message...' : 'Connecting to chat...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    filled: true, fillColor: isDark ? ThemeConstants.backgroundDark : Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    isDense: true
                ),
                minLines: 1, maxLines: 5, textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: canTrySend && canSendViaHttp ? (_) => _sendMessage() : null,
                enabled: canTrySend,
                onTap: () { if (_showEmojiPicker && mounted) setState(() => _showEmojiPicker = false); },
              )),
              const SizedBox(width: 8),
              CircleAvatar(
                  radius: 22,
                  backgroundColor: canTrySend && canSendViaHttp ? ThemeConstants.accentColor : Colors.grey,
                  child: _isSendingMessage
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : IconButton(
                          icon: const Icon(Icons.send), color: Colors.white,
                          tooltip: "Send Message",
                          onPressed: canTrySend && canSendViaHttp ? _sendMessage : null
                      )
              )
            ])
        )
    );
  }

  Widget _buildNotLoggedInView(bool isDark) {
    final theme = Theme.of(context);
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.chat_bubble_outline, size: 80, color: isDark ? Colors.grey.shade700 : Colors.grey.shade400),
              const SizedBox(height: 20),
              Text('Login to Chat', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Join communities and events to start chatting!', style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600), textAlign: TextAlign.center),
              const SizedBox(height: 30),
              ElevatedButton.icon(icon: const Icon(Icons.login), label: const Text('Go to Login'), onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false), style: ElevatedButton.styleFrom(backgroundColor: ThemeConstants.accentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), textStyle: const TextStyle(fontSize: 16))),
            ])
        )
    );
  }
}
