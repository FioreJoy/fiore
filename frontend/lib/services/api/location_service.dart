// frontend/lib/services/api/location_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  // ... (rest of the class: _nominatimBase, _photonBase, _headers, getAddressFromCoordinates, searchPlaces) ...
  final String _nominatimBase = 'https://nominatim.openstreetmap.org';
  final String _photonBase = 'https://photon.komoot.io/api';
  final Map<String, String> _headers = {
    'User-Agent': 'ConnectionsApp/1.0 (Fiore Contact: divanshthebest@gmail.com)' // Replace placeholders
  };

  Future<Map<String, dynamic>?> getAddressFromCoordinates(double latitude, double longitude) async {
    final url = Uri.parse('$_nominatimBase/reverse?format=jsonv2&lat=$latitude&lon=$longitude&accept-language=en');
    print("LocationService: Calling Nominatim Reverse: $url");
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("LocationService: Nominatim Reverse Result: $data");
        if (data is Map<String, dynamic>) {
          return data;
        } else {
          print('Nominatim Error: Unexpected response format.');
          return null;
        }
      } else {
        print('Nominatim Error (${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e) {
      print('LocationService: Error calling Nominatim reverse geocode: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    if (query.trim().length < 3) {
      return [];
    }
    final url = Uri.parse('$_photonBase/?q=${Uri.encodeComponent(query)}&limit=5&lang=en');
    print("LocationService: Calling Photon Search: $url");

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['features'] is List) {
          final features = data['features'] as List;
          return List<Map<String, dynamic>>.from(features.whereType<Map<String, dynamic>>());
        } else {
          print('Photon Error: Unexpected response format. Received: $data');
          return [];
        }
      } else {
        print('Photon Search Error (${response.statusCode}): ${response.body}');
        return [];
      }
    } catch (e) {
      print('LocationService: Error calling Photon search: $e');
      return [];
    }
  }


  // --- *** CORRECTED formatPhotonResult *** ---
  Map<String, dynamic>? formatPhotonResult(Map<String, dynamic> feature) {
    try {
      final properties = feature['properties'];
      final geometry = feature['geometry'];

      if (properties is! Map<String, dynamic> || geometry is! Map<String, dynamic>) {
        print("LocationService Format Error: properties or geometry is not a Map. Feature: $feature");
        return null;
      }

      final coordinates = geometry['coordinates'];
      if (coordinates is! List || coordinates.length < 2) {
        print("LocationService Format Error: Missing or invalid coordinates list. Feature: $feature");
        return null;
      }

      final lonRaw = coordinates[0];
      final latRaw = coordinates[1];
      final double? lon = (lonRaw is num) ? lonRaw.toDouble() : double.tryParse(lonRaw.toString());
      final double? lat = (latRaw is num) ? latRaw.toDouble() : double.tryParse(latRaw.toString());

      if (lon == null || lat == null) {
        print("LocationService Format Error: Could not parse coordinates to double. Feature: $feature");
        return null;
      }

      // Build display name parts list (still List<String?>)
      final List<String?> namePartsNullable = [
        properties['name']?.toString(),
        properties['street']?.toString(),
        properties['housenumber']?.toString(),
        properties['city']?.toString(),
        properties['county']?.toString(),
        properties['state']?.toString(),
        properties['postcode']?.toString(),
        properties['country']?.toString(),
      ];

      // Filter out null/empty and THEN explicitly cast to List<String>
      final List<String> nameParts = namePartsNullable
          .where((s) => s != null && s.isNotEmpty) // Filter nulls/empties
          .cast<String>() // **** ADDED CAST ****
          .toList(); // Now this creates a List<String>

      final String displayName = nameParts.join(', ');

      return {
        'display_name': displayName.isEmpty ? 'Unnamed Location (Photon)' : displayName,
        'latitude': lat,
        'longitude': lon,
      };

    } catch (e, stackTrace) {
      print("LocationService: EXCEPTION formatting Photon feature: $e");
      print(stackTrace);
      print("Problematic Feature Data: $feature");
      return null;
    }
  }
// --- *** END CORRECTED formatPhotonResult *** ---

} // End of LocationService class