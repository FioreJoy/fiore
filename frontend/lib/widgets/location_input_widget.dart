// frontend/lib/widgets/location_input_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart'; // Ensure this dependency is in pubspec.yaml and fetched
import 'package:geolocator/geolocator.dart';             // Ensure this dependency is in pubspec.yaml and fetched
import 'package:provider/provider.dart';

// Verify this path is correct relative to this file's location
import '../services/api/location_service.dart';
import '../theme/theme_constants.dart';

class LocationInputWidget extends StatefulWidget {
  // Callback to notify parent of selection (address string, coords string "(lon,lat)")
  final Function(String address, String coords) onLocationSelected;
  // Initial values to display when the widget loads
  final String? initialAddress;
  final String? initialCoords; // e.g., "(lon,lat)"

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
  final SuggestionsBoxController _suggestionsBoxController = SuggestionsBoxController();
  final FocusNode _searchFocusNode = FocusNode(); // For keyboard dismissal

  String? _displayAddress; // What's shown in the UI
  String? _selectedCoords; // "(lon,lat)" string to send to backend
  bool _isFetchingCurrentLocation = false;
  String? _errorMessage;
  late LocationService _locationService; // Initialized in didChangeDependencies

  // Debug counter for build method calls
  int _buildCounter = 0;

  @override
  void initState() {
    super.initState();
    print("--- LocationInputWidget initState ---");
    _displayAddress = widget.initialAddress;
    _selectedCoords = widget.initialCoords;
    _searchController.text = _displayAddress ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize service here, only once if not already done
    // Using Provider.of ensures it gets the instance provided higher up
    print("--- LocationInputWidget didChangeDependencies ---");
    _locationService = Provider.of<LocationService>(context, listen: false);
  }

  @override
  void dispose() {
    print("--- LocationInputWidget dispose ---");
    _searchController.dispose();
    _searchFocusNode.dispose();
    // SuggestionsBoxController dispose is handled by TypeAheadFormField
    super.dispose();
  }

  /// Fetches the device's current location, reverse geocodes it, and updates the state.
  Future<void> _getCurrentLocation() async {
    print("--- LocationInputWidget _getCurrentLocation START ---");
    setState(() { _isFetchingCurrentLocation = true; _errorMessage = null; });

    try {
      // 1. Check Location Service Enabled
      print("Checking location service...");
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && mounted) { throw Exception('Location services disabled.'); }
      print("Location service enabled.");

      // 2. Check and Request Permissions
      print("Checking location permission...");
      LocationPermission permission = await Geolocator.checkPermission();
      print("Initial permission: $permission");
      if (permission == LocationPermission.denied) {
        print("Requesting location permission...");
        permission = await Geolocator.requestPermission();
        print("Permission after request: $permission");
        if (permission == LocationPermission.denied && mounted) {
          throw Exception('Location permissions were denied.');
        }
      }
      if (permission == LocationPermission.deniedForever && mounted) {
        print("Location permissions permanently denied.");
        throw Exception('Location permissions are permanently denied.');
      }
      print("Location permission granted.");

      // 3. Get Current Position
      print("Getting current position...");
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium
      );
      print("Position received: Lat ${position.latitude}, Lon ${position.longitude}");

      // 4. Reverse Geocode using LocationService
      print("Reverse geocoding coordinates...");
      final addressData = await _locationService.getAddressFromCoordinates(
          position.latitude, position.longitude);

      if (mounted) {
        final coordsString = '(${position.longitude.toStringAsFixed(6)},${position.latitude.toStringAsFixed(6)})';
        String finalAddress;

        if (addressData != null && addressData['display_name'] is String) {
          finalAddress = addressData['display_name'];
          print("Reverse geocode successful: $finalAddress");
          _errorMessage = null;
        } else {
          finalAddress = 'Lat: ${position.latitude.toStringAsFixed(4)}, Lon: ${position.longitude.toStringAsFixed(4)}';
          _errorMessage = 'Could not determine address name.';
          print("Reverse geocode failed or returned invalid data. Fallback: $finalAddress");
        }

        // 5. Update State
        print("Updating state with fetched location...");
        setState(() {
          _displayAddress = finalAddress;
          _selectedCoords = coordsString;
          _searchController.text = finalAddress;
          _isFetchingCurrentLocation = false;
          _errorMessage = _errorMessage; // Keep error message if set
        });

        // 6. Notify Parent Widget
        print("Notifying parent: Address='$finalAddress', Coords='$coordsString'");
        widget.onLocationSelected(finalAddress, coordsString);
      }

    } catch (e) {
      print("--- LocationInputWidget _getCurrentLocation ERROR: $e ---");
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
          _isFetchingCurrentLocation = false;
        });
      }
    }
    print("--- LocationInputWidget _getCurrentLocation END ---");
  }

  /// Fetches location suggestions from Photon API based on query.
  Future<List<Map<String, dynamic>>> _searchLocations(String query) async {
    // Print statement moved inside the main logic
    // Basic check
    if (!mounted || query.trim().length < 3) {
      print("--- _searchLocations SKIPPING (query: '$query', mounted: $mounted) ---");
      return [];
    }

    print("--- _searchLocations called with query: '$query' ---"); // Log entry

    try {
      print("--- _searchLocations calling locationService.searchPlaces ---");
      // Directly call the service method
      final results = await _locationService.searchPlaces(query.trim());
      print("--- _searchLocations received ${results.length} raw results from service ---");

      // Format results - Keep try-catch here as formatting might fail
      List<Map<String, dynamic>> formattedResults = [];
      try {
        formattedResults = results
            .map((feature) => _locationService.formatPhotonResult(feature))
            .where((formatted) => formatted != null) // Filter nulls
            .cast<Map<String, dynamic>>() // Cast
            .toList();
        print("--- _searchLocations formatted ${formattedResults.length} results ---");
      } catch(e, stackTrace) {
        print("--- _searchLocations FORMATTING ERROR: $e ---");
        print(stackTrace);
        // Optionally rethrow or just return empty
        // throw Exception("Formatting error");
      }
      return formattedResults;
    } catch (e) {
      print("--- _searchLocations API/Network ERROR: $e ---");
      // Re-throw so TypeAhead's errorBuilder is triggered
      throw Exception("Failed to fetch locations.");
    }
  }


  @override
  Widget build(BuildContext context) {
    _buildCounter++;
    print("--- LocationInputWidget build method called ($_buildCounter) ---"); // Debug build calls

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Field with TypeAhead
        TypeAheadFormField<Map<String, dynamic>?>(
          debounceDuration: const Duration(milliseconds: 600), // Increased debounce
          textFieldConfiguration: TextFieldConfiguration(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              labelText: 'Location',
              hintText: 'Search address or use current location',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                tooltip: 'Clear Location',
                onPressed: () {
                  print("Clear button pressed");
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
                  borderRadius: BorderRadius.circular(ThemeConstants.borderRadius)),
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 15),
            ),
            // Log text changes directly from the controller listener if needed
            // onChanged: (value) {
            //   print("Search field text changed: $value");
            // }
          ),
          suggestionsBoxController: _suggestionsBoxController,
          suggestionsCallback: (pattern) async {
            print("SuggestionsCallback triggered with pattern: '$pattern'");
            // Directly return the Future from _searchLocations
            return _searchLocations(pattern);
          },
          itemBuilder: (context, suggestion) {
            print("ItemBuilder called for suggestion: ${suggestion?['display_name']}");
            if (suggestion == null) return const SizedBox.shrink();
            return ListTile(
              leading: const Icon(Icons.location_pin, size: 20, color: Colors.grey),
              title: Text(suggestion['display_name'] ?? 'Unknown location'),
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            );
          },
          onSuggestionSelected: (suggestion) {
            print("Suggestion Selected: ${suggestion?['display_name']}");
            if (suggestion == null) return;
            // Ensure _locationService is accessible (should be due to late/didChangeDependencies)
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
              _searchFocusNode.unfocus(); // Dismiss keyboard
              widget.onLocationSelected(displayName, coordsString);
              print("State updated after selection: Address='$displayName', Coords='$coordsString'");
            } else {
              print("Error: Selected suggestion could not be formatted.");
              // Optionally show an error to the user
            }
          },
          noItemsFoundBuilder: (context) {
            print("NoItemsFoundBuilder called");
            return const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('No results found.', style: TextStyle(color: Colors.grey)),
            );
          },
          loadingBuilder: (context) {
            print("LoadingBuilder called");
            return const Padding(
              padding: EdgeInsets.all(12.0),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
            );
          },
          errorBuilder: (context, error) {
            print("ErrorBuilder called with error: $error");
            return Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text('Search error: ${error.toString().replaceFirst("Exception: ", "")}',
                  style: const TextStyle(color: Colors.redAccent)),
            );
          },
          // Keep these settings
          hideOnLoading: false,
          hideOnError: false, // Keep false to show error in dropdown
          keepSuggestionsOnLoading: false,
        ),

        const SizedBox(height: 12),

        // "Use Current Location" Button
        TextButton.icon(
          icon: _isFetchingCurrentLocation
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.my_location, size: 18, color: isDark ? Colors.white70 : Theme.of(context).primaryColor),
          label: Text(
              _isFetchingCurrentLocation ? 'Getting Location...' : 'Use Current Location',
              style: TextStyle(color: isDark ? Colors.white70 : Theme.of(context).primaryColor)
          ),
          onPressed: _isFetchingCurrentLocation ? null : _getCurrentLocation,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            alignment: Alignment.centerLeft,
          ),
        ),

        // Error Message Display Area
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 12.0),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: ThemeConstants.errorColor, fontSize: 12),
            ),
          ),
      ],
    );
  }
}