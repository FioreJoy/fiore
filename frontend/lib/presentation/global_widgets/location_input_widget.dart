import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

// --- Data Layer Imports ---
import '../../data/datasources/remote/location_api.dart'; // For LocationApiService

// --- Core Imports ---
import '../../core/theme/theme_constants.dart';

class LocationInputWidget extends StatefulWidget {
  final Function(String address, String coords) onLocationSelected;
  final String? initialAddress;
  final String? initialCoords;

  const LocationInputWidget({
    Key? key,
    required this.onLocationSelected,
    this.initialAddress,
    this.initialCoords,
  }) : super(key: key);

  @override
  _LocationInputWidgetState createState() => _LocationInputWidgetState();
}

class _LocationInputWidgetState extends State<LocationInputWidget> {
  final TextEditingController _searchController = TextEditingController();
  final SuggestionsBoxController _suggestionsBoxController =
      SuggestionsBoxController();
  final FocusNode _searchFocusNode = FocusNode();

  String? _displayAddress;
  String? _selectedCoords;
  bool _isFetchingCurrentLocation = false;
  String? _errorMessage;
  late LocationService _locationService; // Changed from LocationService

  @override
  void initState() {
    super.initState();
    // print("--- LocationInputWidget initState ---"); // Debug removed
    _displayAddress = widget.initialAddress;
    _selectedCoords = widget.initialCoords;
    _searchController.text = _displayAddress ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // print("--- LocationInputWidget didChangeDependencies ---"); // Debug removed
    _locationService =
        Provider.of<LocationService>(context, listen: false); // Use typedef
  }

  @override
  void dispose() {
    // print("--- LocationInputWidget dispose ---"); // Debug removed
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    /* ... logic unchanged ... */
    // print("--- LocationInputWidget _getCurrentLocation START ---"); // Debug removed
    setState(() {
      _isFetchingCurrentLocation = true;
      _errorMessage = null;
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && mounted)
        throw Exception('Location services disabled.');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied && mounted)
          throw Exception('Location permissions denied.');
      }
      if (permission == LocationPermission.deniedForever && mounted)
        throw Exception('Location permissions permanently denied.');
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10));
      final addressData = await _locationService.getAddressFromCoordinates(
          position.latitude, position.longitude);
      if (mounted) {
        final coordsString =
            '(${position.longitude.toStringAsFixed(6)},${position.latitude.toStringAsFixed(6)})';
        String finalAddress;
        if (addressData != null && addressData['display_name'] is String) {
          finalAddress = addressData['display_name'];
          _errorMessage = null;
        } else {
          finalAddress =
              'Lat: ${position.latitude.toStringAsFixed(4)}, Lon: ${position.longitude.toStringAsFixed(4)}';
          _errorMessage = 'Could not determine address name.';
        }
        setState(() {
          _displayAddress = finalAddress;
          _selectedCoords = coordsString;
          _searchController.text = finalAddress;
          _isFetchingCurrentLocation = false;
          _errorMessage = _errorMessage;
        });
        widget.onLocationSelected(finalAddress, coordsString);
      }
    } catch (e) {
      /* print("--- LocationInputWidget _getCurrentLocation ERROR: $e ---"); */ if (mounted)
        setState(() {
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
          _isFetchingCurrentLocation = false;
        });
    }
    // print("--- LocationInputWidget _getCurrentLocation END ---"); // Debug removed
  }

  Future<List<Map<String, dynamic>>> _searchLocations(String query) async {
    /* ... logic unchanged ... */
    if (!mounted || query.trim().length < 3) return [];
    // print("--- _searchLocations called with query: '$query' ---"); // Debug removed
    try {
      final results = await _locationService.searchPlaces(query.trim());
      List<Map<String, dynamic>> formattedResults = [];
      try {
        formattedResults = results
            .map((feature) => _locationService.formatPhotonResult(feature))
            .where((formatted) => formatted != null)
            .cast<Map<String, dynamic>>()
            .toList();
      } catch (e, stackTrace) {
        /* print("--- _searchLocations FORMATTING ERROR: $e $stackTrace ---"); */
      }
      return formattedResults;
    } catch (e) {
      /* print("--- _searchLocations API/Network ERROR: $e ---"); */ throw Exception(
          "Failed to fetch locations.");
    }
  }

  @override
  Widget build(BuildContext context) {
    /* ... UI build logic unchanged ... */
    // _buildCounter++; print("--- LocationInputWidget build method called ($_buildCounter) ---"); // Debug removed
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TypeAheadFormField<Map<String, dynamic>?>(
          debounceDuration: const Duration(milliseconds: 600),
          textFieldConfiguration: TextFieldConfiguration(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              labelText: 'Location',
              hintText: 'Search address or use current',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      tooltip: 'Clear Location',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _displayAddress = null;
                          _selectedCoords = null;
                          _errorMessage = null;
                        });
                        widget.onLocationSelected('', '(0,0)');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(ThemeConstants.borderRadius)),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 15),
            ),
          ),
          suggestionsBoxController: _suggestionsBoxController,
          suggestionsCallback: (pattern) async => _searchLocations(pattern),
          itemBuilder: (context, suggestion) {
            if (suggestion == null) return const SizedBox.shrink();
            return ListTile(
              leading:
                  const Icon(Icons.location_pin, size: 20, color: Colors.grey),
              title: Text(suggestion['display_name'] ?? 'Unknown'),
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            );
          },
          onSuggestionSelected: (suggestion) {
            if (suggestion == null) return;
            final formatted = _locationService.formatPhotonResult(suggestion);
            if (formatted != null) {
              final String displayName = formatted['display_name'];
              final double lat = formatted['latitude'];
              final double lon = formatted['longitude'];
              final coordsString = '($lon,$lat)';
              setState(() {
                _displayAddress = displayName;
                _selectedCoords = coordsString;
                _searchController.text = displayName;
                _errorMessage = null;
              });
              _suggestionsBoxController.close();
              _searchFocusNode.unfocus();
              widget.onLocationSelected(displayName, coordsString);
            }
          },
          noItemsFoundBuilder: (context) => const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('No results.', style: TextStyle(color: Colors.grey))),
          loadingBuilder: (context) => const Padding(
              padding: EdgeInsets.all(12.0),
              child: Center(
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5)))),
          errorBuilder: (context, error) => Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                  'Search error: ${error.toString().replaceFirst("Exception: ", "")}',
                  style: const TextStyle(color: Colors.redAccent))),
          hideOnLoading: false,
          hideOnError: false,
          keepSuggestionsOnLoading: false,
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          icon: _isFetchingCurrentLocation
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.my_location,
                  size: 18,
                  color:
                      isDark ? Colors.white70 : Theme.of(context).primaryColor),
          label: Text(
              _isFetchingCurrentLocation
                  ? 'Getting Location...'
                  : 'Use Current Location',
              style: TextStyle(
                  color: isDark
                      ? Colors.white70
                      : Theme.of(context).primaryColor)),
          onPressed: _isFetchingCurrentLocation ? null : _getCurrentLocation,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            alignment: Alignment.centerLeft,
          ),
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 12.0),
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                  color: ThemeConstants.errorColor, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
