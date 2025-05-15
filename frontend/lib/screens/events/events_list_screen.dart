// frontend/lib/screens/events/events_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:geolocator/geolocator.dart';

// --- Service Imports ---
import '../../services/api/event_service.dart';
import '../../services/api/user_service.dart';
import '../../services/auth_provider.dart';

// --- Widget Imports (Updated Paths) ---
import '../../widgets/event_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/create_event_dialog.dart';

// --- Model Imports ---
import '../../models/event_model.dart';

// --- Theme and Constants ---
import '../../theme/theme_constants.dart';

// --- Navigation ---
import '../chat/chat_screen.dart'; // Import ChatScreen for navigation

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({Key? key}) : super(key: key);

  @override
  _EventsListScreenState createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<List<EventModel>>? _loadEventsFuture;
  String? _error;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _isFetchingLocation = false;
  bool _canLoadMore = true;
  List<EventModel> _events = [];
  int _currentPage = 0;
  final int _limit = 10;

  String _selectedFilter = 'nearby'; // Default filter
  final List<Map<String, dynamic>> _filterTabs = [
    {'id': 'nearby', 'label': 'Nearby', 'icon': Icons.near_me_outlined},
    {'id': 'all', 'label': 'Discover', 'icon': Icons.explore_outlined},
    {'id': 'joined', 'label': 'Joined', 'icon': Icons.event_available_outlined},
  ];

  Position? _currentPosition;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Initialize based on the default filter
        if (_selectedFilter == 'nearby') {
          _initializeNearbyAndRefresh();
        } else {
          _refreshEvents(isInitialLoad: true);
        }
      }
    });
  }

  Future<void> _initializeNearbyAndRefresh() async {
    await _getCurrentDeviceLocation(showMessages: false); // Attempt to get location
    _refreshEvents(isInitialLoad: true); // Then refresh events (which will use location if available)
  }


  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _canLoadMore) {
      _fetchEventsData(isPaginating: true);
    }
  }

  Future<void> _refreshEvents({bool isInitialLoad = false}) async {
    if (!mounted) return;
    _currentPage = 0;
    if (isInitialLoad || _events.isEmpty) { // Clear only if it's a true initial load or list is empty
      _events.clear();
    }
    _canLoadMore = true;
    setState(() {
      _error = null;
      _locationError = null; // Clear location error on generic refresh too
      // Re-assign the future to trigger FutureBuilder
      _loadEventsFuture = _fetchEventsData(isInitialLoad: isInitialLoad || _events.isEmpty);
    });
  }

  Future<bool> _getCurrentDeviceLocation({bool showMessages = true}) async {
    if (!mounted) return false;
    setState(() => _isFetchingLocation = true);
    _locationError = null; // Clear previous location error
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Location permission denied.');
      }
      if (permission == LocationPermission.deniedForever) throw Exception('Location permission permanently denied. Enable in settings.');
      _currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 10));
      if(mounted && showMessages) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current location obtained.'), duration: Duration(seconds: 1)));
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _locationError = e.toString().replaceFirst("Exception: ", ""));
      }
      _currentPosition = null;
      return false;
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<List<EventModel>> _fetchEventsData({bool isInitialLoad = false, bool isPaginating = false}) async {
    if (!mounted) return _events; // Return current events if widget is disposed
    // Prevent concurrent fetches
    if (isPaginating && _isLoadingMore) return _events;
    // If it's not paginating (i.e., a tab switch or refresh) and not an initial load,
    // and still loading more from a previous pagination, prevent new fetch.
    if (!isPaginating && !isInitialLoad && _isLoadingMore) return _events;


    final eventService = Provider.of<EventService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userService = Provider.of<UserService>(context, listen: false);

    if (isPaginating) {
      setState(() => _isLoadingMore = true);
    } else if (isInitialLoad) {
      // For initial load, _loadEventsFuture handles the global loading state
      // but we ensure _isLoadingMore is false
      _isLoadingMore = false;
    }


    List<dynamic> fetchedRawEvents = [];
    try {
      final currentOffset = isInitialLoad ? 0 : _currentPage * _limit;
      // Ensure page is reset for initial loads or filter changes
      if (isInitialLoad) _currentPage = 0;

      if (_selectedFilter == 'nearby') {
        if (_currentPosition == null) {
          if (mounted && !isInitialLoad && !_isFetchingLocation) { // Only show error if not already trying to fetch location
            _error = "Current location needed for 'Nearby' events.";
          }
          _canLoadMore = false; // Can't load if no position
        } else {
          fetchedRawEvents = await eventService.getNearbyEvents(
            token: authProvider.token, latitude: _currentPosition!.latitude, longitude: _currentPosition!.longitude,
            radiusKm: 50, limit: _limit, offset: currentOffset,
          );
        }
      } else if (_selectedFilter == 'joined') {
        if (!authProvider.isAuthenticated || authProvider.token == null) {
          if (mounted) setState(() { _error = "Log in to see events you've joined."; _canLoadMore = false; });
        } else {
          // "Joined" events are typically not paginated heavily, fetch all relevant ones
          if (currentOffset == 0) { // Only fetch on first page for 'joined'
            fetchedRawEvents = await userService.getMyJoinedEvents(authProvider.token!, limit: 100); // Fetch a larger batch
          }
          _canLoadMore = false; // Assume all joined events are fetched
        }
      } else { // 'all' (Discover)
        fetchedRawEvents = await eventService.getCommunityEvents(
            1, // Placeholder community ID for "all events", backend needs generic endpoint
            token: authProvider.token, limit: _limit, offset: currentOffset
        );
      }

      if (!mounted) return _events;
      final List<EventModel> newEvents = fetchedRawEvents.map((data) => EventModel.fromJson(data as Map<String, dynamic>)).toList();

      if (newEvents.length < _limit && (_selectedFilter != 'joined')) { // 'joined' pagination handled differently
        _canLoadMore = false;
      }

      if (isInitialLoad || currentOffset == 0) {
        _events = newEvents;
      } else {
        final existingEventIds = _events.map((e) => e.id).toSet();
        _events.addAll(newEvents.where((e) => !existingEventIds.contains(e.id)));
      }
      // Sort events by timestamp (ascending for upcoming)
      _events.sort((a,b) => a.eventTimestamp.compareTo(b.eventTimestamp));

      if (newEvents.isNotEmpty && _canLoadMore) {
        _currentPage++;
      }
      _error = null; // Clear error on successful fetch
    } catch (e) {
      if (mounted) {
        _error = "Failed to load events: ${e.toString().replaceFirst("Exception: ", "")}";
        _canLoadMore = false;
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
    return _events;
  }

  void _selectFilter(String filterId) async {
    if (!mounted || _selectedFilter == filterId) return;
    if (filterId == 'nearby' && _currentPosition == null) {
      bool gotLocation = await _getCurrentDeviceLocation(); // Attempt to get location first
      if (!gotLocation && mounted) {
        // If failed, don't switch tab or show error through _locationError
        // The UI will show _locationError message if _selectedFilter is 'nearby'
        return;
      }
    }
    setState(() {
      _selectedFilter = filterId;
      // Reset pagination and data for new filter
      _currentPage = 0;
      _events.clear();
      _canLoadMore = true;
      _error = null; // Clear general error
      _locationError = null; // Clear location-specific error
      _loadEventsFuture = _fetchEventsData(isInitialLoad: true); // Trigger new fetch
    });
  }

  Future<void> _handleJoinLeaveEvent(EventModel event) async {
    if (!mounted) return;
    final eventService = Provider.of<EventService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to join or leave events.')));
      return;
    }
    final bool currentlyParticipating = event.isParticipatingByViewer ?? false;
    final String action = currentlyParticipating ? "leave" : "join";

    // Optimistic UI update
    final originalEventIndex = _events.indexWhere((e) => e.id == event.id);
    EventModel? originalEventData;
    if (originalEventIndex != -1) {
      originalEventData = _events[originalEventIndex];
      if(mounted) {
        setState(() {
          _events[originalEventIndex] = EventModel(
              id: event.id, title: event.title, description: event.description,
              locationAddress: event.locationAddress, eventTimestamp: event.eventTimestamp,
              maxParticipants: event.maxParticipants,
              participantCount: currentlyParticipating ? (event.participantCount - 1).clamp(0, event.maxParticipants) : (event.participantCount + 1).clamp(0, event.maxParticipants),
              creatorId: event.creatorId, communityId: event.communityId, imageUrl: event.imageUrl,
              locationCoords: event.locationCoords, isParticipatingByViewer: !currentlyParticipating
          );
        });
      }
    }

    try {
      if (currentlyParticipating) {
        await eventService.leaveEvent(int.parse(event.id), authProvider.token!);
      } else {
        if (event.participantCount >= event.maxParticipants) { // Check before trying to join
          throw Exception("Event is full.");
        }
        await eventService.joinEvent(int.parse(event.id), authProvider.token!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully ${action}ed event: ${event.title}')));
        // Optionally refresh the specific event or the whole list to get exact counts from server
        // For now, optimistic update is handled, a full refresh might be too much
        // _refreshEvents(isInitialLoad: false); // Could do this, or just update counts from response if API provides it
      }
    } catch (e) {
      if (mounted) {
        // Rollback optimistic update if API call failed
        if (originalEventIndex != -1 && originalEventData != null) {
          setState(() => _events[originalEventIndex] = originalEventData!);
        } else if (originalEventIndex != -1) {
          // If original data wasn't stored, a full refresh might be needed to correct UI
           _refreshEvents(isInitialLoad: true);
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to $action event: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: ThemeConstants.errorColor));
      }
    }
  }

  void _showCreateEventDialog() {
    final String tempCommunityIdForDialog = "1"; // Placeholder: Needs a way to select community
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to create events.')));
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) => CreateEventDialog(
        communityId: tempCommunityIdForDialog, // Needs a mechanism to select community
        onSubmit: (title, description, locationAddress, dateTime, maxParticipants, imageFile, latitude, longitude) async {
          if (!mounted) return;
          final eventService = Provider.of<EventService>(context, listen: false);
          final currentToken = Provider.of<AuthProvider>(context, listen: false).token;
          if (currentToken == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication error.')));
            return;
          }
          try {
            // TODO: Confirm if createCommunityEvent uses communityId from path or body.
            // Assuming it's from path based on current ApiEndpoints
            await eventService.createCommunityEvent(
              token: currentToken,
              communityId: int.parse(tempCommunityIdForDialog), // Path param
              title: title, description: description, locationAddress: locationAddress,
              eventTimestamp: dateTime, maxParticipants: maxParticipants,
              image: imageFile, latitude: latitude, longitude: longitude,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event created successfully!'), backgroundColor: ThemeConstants.successColor,));
              _refreshEvents(isInitialLoad: true); // Refresh list after creation
            }
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create event: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: ThemeConstants.errorColor,));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context, listen: false); // Use listen:false if only for initial check

    return Scaffold(
      // AppBar is handled by ExploreScreen's TabBar for this tab
      // If this screen can be navigated to directly, it might need its own AppBar:
      // appBar: AppBar(title: const Text('Events')),
      body: Column(
        children: [
          _buildFilterTabs(isDark, authProvider.isAuthenticated),
          if (_isFetchingLocation && _selectedFilter == 'nearby')
            const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: LinearProgressIndicator(minHeight: 2)),
          if (_locationError != null && _selectedFilter == 'nearby')
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent.shade200, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_locationError!, style: TextStyle(color: Colors.orangeAccent.shade200, fontSize: 12))),
                  TextButton(onPressed: () async { await _getCurrentDeviceLocation(); _refreshEvents(); }, child: const Text("Retry Loc", style: TextStyle(fontSize: 12)))
                ]),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refreshEvents(isInitialLoad: true),
              child: FutureBuilder<List<EventModel>>(
                future: _loadEventsFuture,
                builder: (context, snapshot) {
                  final bool isLoadingSnapshot = snapshot.connectionState == ConnectionState.waiting;

                  if (isLoadingSnapshot && _events.isEmpty && !_isFetchingLocation /* only show global shimmer if not already fetching location */) {
                    return _buildLoadingShimmer();
                  }
                  if (_error != null && _events.isEmpty) {
                    return _buildErrorUI(_error, isDark);
                  }
                  // Show snapshot error only if local _error is not already set and list is empty
                  if (snapshot.hasError && _events.isEmpty && _error == null) {
                    return _buildErrorUI(snapshot.error, isDark);
                  }
                  if (_events.isEmpty && !_isLoadingMore && !isLoadingSnapshot && !_isFetchingLocation) {
                    return _buildEmptyUI(isDark, filter: _selectedFilter);
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
                    itemCount: _events.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _events.length && _isLoadingMore) {
                        return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2.0)));
                      }
                      if (index >= _events.length) return const SizedBox.shrink(); // Should not happen

                      final event = _events[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: ThemeConstants.mediumPadding),
                        child: EventCard(
                          key: ValueKey("event_card_${event.id}"),
                          event: event,
                          onTap: () {
                            // TODO: Navigate to a detailed event screen
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tapped Event: ${event.title}')));
                          },
                          onJoinLeave: authProvider.isAuthenticated ? () => _handleJoinLeaveEvent(event) : null,
                          // --- ADDED: onChat callback ---
                          onChat: (authProvider.isAuthenticated && (event.isParticipatingByViewer ?? false))
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      eventId: int.tryParse(event.id),
                                      eventName: event.title,
                                      // Pass communityId as well if your EventModel contains it
                                      communityId: int.tryParse(event.communityId),
                                      // communityName: event.communityName, // if available
                                    ),
                                  ),
                                );
                              }
                            : null,
                          // --- END ADDED ---
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateEventDialog,
        label: const Text('New Event'),
        icon: const Icon(Icons.add_location_alt_outlined),
        // Style can be inherited or customized further
      ),
    );
  }

  Widget _buildFilterTabs(bool isDark, bool isAuthenticated) {
    return Container(
      height: 50,
      color: isDark ? ThemeConstants.backgroundDarker : Colors.grey.shade100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filterTabs.length,
        padding: const EdgeInsets.symmetric(horizontal: ThemeConstants.smallPadding, vertical: 8),
        itemBuilder: (context, index) {
          final filter = _filterTabs[index];
          final bool isSelected = _selectedFilter == filter['id'];
          final bool isEnabled = !( (filter['id'] == 'joined') && !isAuthenticated );

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(filter['label']),
              avatar: Icon(filter['icon'], size: 16, color: isEnabled ? (isSelected ? ThemeConstants.primaryColor : (isDark ? Colors.white70 : Colors.black54)) : Colors.grey.shade500),
              selected: isSelected,
              onSelected: isEnabled
                  ? (selected) {
                      if (selected && _selectedFilter != filter['id']) {
                        _selectFilter(filter['id'] as String);
                      }
                    }
                  : null,
              selectedColor: isEnabled ? ThemeConstants.accentColor : Colors.grey.shade300,
              backgroundColor: isEnabled ? (isDark ? ThemeConstants.backgroundDark : Colors.white) : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              labelStyle: TextStyle(
                  color: isEnabled ? (isSelected ? ThemeConstants.primaryColor : (isDark ? Colors.white : Colors.black87)) : Colors.grey.shade600,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
              ),
              disabledColor: isDark ? Colors.grey.shade800.withOpacity(0.5) : Colors.grey.shade300.withOpacity(0.5),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(ThemeConstants.mediumPadding),
        itemCount: 3, // Number of shimmer items
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: ThemeConstants.mediumPadding),
          child: Container(
            height: 250, // Approximate height of EventCard
            decoration: BoxDecoration(
              color: Colors.white, // Base for shimmer
              borderRadius: BorderRadius.circular(ThemeConstants.cardBorderRadius),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyUI(bool isDark, {String? filter}) {
    String message = 'No events found for "${_filterTabs.firstWhere((f) => f['id'] == filter, orElse: () => {'label': filter})['label']}".';
    String suggestion = 'Try a different filter or check back later!';
    if ((filter == 'joined') && !Provider.of<AuthProvider>(context, listen:false).isAuthenticated) {
      message = 'Log in to see events you have joined.';
      suggestion = '';
    }
    if (filter == 'nearby' && _currentPosition == null && !_isFetchingLocation) {
       message = 'Enable location or search to find nearby events.';
       suggestion = 'You can also check out events in communities you follow.';
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ThemeConstants.largePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_outlined, size: 64, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(message, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600), textAlign: TextAlign.center),
            if (suggestion.isNotEmpty) const SizedBox(height: 8),
            if (suggestion.isNotEmpty) Text(
              suggestion,
              style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (!Provider.of<AuthProvider>(context, listen:false).isAuthenticated && (filter == 'joined'))
              CustomButton(
                text: 'Log In',
                icon: Icons.login,
                onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                type: ButtonType.primary,
              ),
            if (filter == 'nearby' && _currentPosition == null && !_isFetchingLocation && !_isLoadingMore)
             CustomButton(
                text: 'Enable/Retry Location',
                icon: Icons.location_searching,
                onPressed: () async {
                  await _getCurrentDeviceLocation();
                  _refreshEvents(); // Refresh after attempting to get location
                },
                type: ButtonType.outline,
             )
          ],
        ),
      ),
    );
  }

  Widget _buildErrorUI(Object? error, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThemeConstants.largePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: ThemeConstants.errorColor, size: 48),
            const SizedBox(height: ThemeConstants.mediumPadding),
            Text('Failed to load events', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: ThemeConstants.smallPadding),
            Text(
              error.toString().replaceFirst("Exception: ",""),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)
            ),
            const SizedBox(height: ThemeConstants.largePadding),
            CustomButton(
              text: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: () => _refreshEvents(isInitialLoad: true),
              type: ButtonType.secondary,
            ),
          ],
        ),
      ),
    );
  }
}
