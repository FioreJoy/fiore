// frontend/lib/widgets/location_input_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
// REMOVED: import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

// Verify this path is correct relative to this file's location
import '../services/api/location_service.dart'; // Assuming LocationService doesn't directly depend on TypeAhead
import '../theme/theme_constants.dart';

class LocationInputWidget extends StatefulWidget {
  // Callback still required: notifies parent of selection (address string, coords string "(lon,lat)")
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
  // REMOVED: SuggestionsBoxController is no longer needed
  final FocusNode _searchFocusNode = FocusNode(); // Keep for keyboard management

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
    print("--- LocationInputWidget initState (TypeAhead REMOVED) ---");
    _displayAddress = widget.initialAddress;
    _selectedCoords = widget.initialCoords;
    _searchController.text = _displayAddress ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print("--- LocationInputWidget didChangeDependencies ---");
    _locationService = Provider.of<LocationService>(context, listen: false);
  }

  @override
  void dispose() {
    print("--- LocationInputWidget dispose ---");
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Fetches the device's current location, reverse geocodes it, and updates the state.
  /// This function remains largely unchanged.
  Future<void> _getCurrentLocation() async {
    print("--- LocationInputWidget _getCurrentLocation START ---");
    setState(() { _isFetchingCurrentLocation = true; _errorMessage = null; });

    try {
      // ... (Keep existing permission checks and Geolocator calls) ...
      print("Checking location service...");
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && mounted) { throw Exception('Location services disabled.'); }
      print("Location service enabled.");

      print("Checking location permission...");
      LocationPermission permission = await Geolocator.checkPermission();
      // ... (rest of permission handling) ...
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
         if (permission == LocationPermission.denied && mounted) {
           throw Exception('Location permissions were denied.');
         }
      }
      if (permission == LocationPermission.deniedForever && mounted) {
        throw Exception('Location permissions are permanently denied.');
      }
      print("Location permission granted.");

      print("Getting current position...");
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium
      );
      print("Position received: Lat ${position.latitude}, Lon ${position.longitude}");

      print("Reverse geocoding coordinates...");
      // NOTE: Ensure LocationService doesn't have breaking changes itself
      final addressData = await _locationService.getAddressFromCoordinates(
          position.latitude, position.longitude);

      if (mounted) {
        final coordsString = '(${position.longitude.toStringAsFixed(6)},${position.latitude.toStringAsFixed(6)})';
        String finalAddress;

        // Use the same logic to determine the display address
        if (addressData != null && addressData['display_name'] is String) {
          finalAddress = addressData['display_name'];
          print("Reverse geocode successful: $finalAddress");
          _errorMessage = null;
        } else {
          finalAddress = 'Lat: ${position.latitude.toStringAsFixed(4)}, Lon: ${position.longitude.toStringAsFixed(4)}';
          _errorMessage = 'Could not determine address name.';
          print("Reverse geocode failed or returned invalid data. Fallback: $finalAddress");
        }

        // Update State - This now updates the standard TextFormField
        print("Updating state with fetched location...");
        setState(() {
          _displayAddress = finalAddress;
          _selectedCoords = coordsString;
          _searchController.text = finalAddress; // Update the controller
          _isFetchingCurrentLocation = false;
          _errorMessage = _errorMessage;
        });

        // Notify Parent Widget - Still essential
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

  // REMOVED: _searchLocations method is no longer needed as TypeAhead is gone.
  // Future<List<Map<String, dynamic>>> _searchLocations(String query) async { ... }

  @override
  Widget build(BuildContext context) {
    _buildCounter++;
    print("--- LocationInputWidget build method called ($_buildCounter) (TypeAhead REMOVED) ---");

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Replaced TypeAheadFormField with a standard TextFormField
        TextFormField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          // readOnly: true, // Optional: Make it read-only if you ONLY want selection via button
          decoration: InputDecoration(
            labelText: 'Location',
            // Hint text might be less relevant now, but kept for structure
            hintText: 'Use button below or clear selection',
            prefixIcon: const Icon(Icons.location_pin, size: 20), // Changed icon slightly
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    tooltip: 'Clear Location',
                    onPressed: () {
                      print("Clear button pressed");
                      _searchController.clear(); // Clear the text field
                      _searchFocusNode.unfocus(); // Dismiss keyboard
                      setState(() {
                        _displayAddress = null; // Clear internal state
                        _selectedCoords = null;
                        _errorMessage = null;
                      });
                      // Notify parent that location is cleared (provide empty/default values)
                      widget.onLocationSelected('', '(0,0)'); // Adjust default coords if needed
                    },
                  )
                : null, // No clear button if field is empty
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ThemeConstants.borderRadius)),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 15),
          ),
          // This field won't actively search, only display/clear
          onChanged: (value) {
            // If user types manually, we don't automatically validate or search.
            // We could potentially parse coords here if desired, but keeping it simple.
            // If they clear it manually, the suffixIcon handles the state update.
            // If they type something else, it won't trigger onLocationSelected unless they
            // manually clear it again or use the button.
             print("Manual text change (no action taken): $value");
             // If the text becomes empty due to manual deletion, ensure state is cleared
             if (value.isEmpty && _displayAddress != null) {
                setState(() {
                   _displayAddress = null;
                   _selectedCoords = null;
                   _errorMessage = null;
                 });
                 // Notify parent that location is cleared
                 widget.onLocationSelected('', '(0,0)');
             }
          },
        ),

        const SizedBox(height: 12),

        // "Use Current Location" Button - This remains the primary selection method
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

        // Error Message Display Area - Still relevant for _getCurrentLocation errors
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