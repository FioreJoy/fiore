// frontend/lib/services/api_client.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../app_constants.dart';

// Define API Key as a constant (load from environment ideally using --dart-define)
// Compile using: flutter run --dart-define=API_KEY=YOUR_ACTUAL_API_KEY
const String _apiKey = String.fromEnvironment('API_KEY');

/// A base client for making authenticated API requests.
/// Handles adding Authorization (Bearer Token) and X-API-Key headers.
class ApiClient {
  final String baseUrl = AppConstants.baseUrl;
  final String apiKey;
  final http.Client _httpClient;

  /// Creates a new ApiClient instance.
  /// [client] can be provided for testing purposes.
  ApiClient({http.Client? client})
      : _httpClient = client ?? http.Client(),
        apiKey = _apiKey {
    // Validate that the API key was provided during the build process
    if (apiKey.isEmpty) {
      const errorMessage = "API_KEY environment variable not set during build. Cannot initialize ApiClient.";
      print("FATAL ERROR: $errorMessage");
      // In a real app, you might want a more graceful shutdown or error screen
      throw Exception(errorMessage);
    }
    print("ApiClient initialized with base URL: $baseUrl and API Key (truncated): ${apiKey.substring(0, 5)}...");
  }

  // --- Header Helper ---
  /// Constructs standard headers for API requests, including Auth and API Key.
  Map<String, String> _getHeaders(String? token, {bool isJsonContent = true}) {
    final headers = <String, String>{};
    if (isJsonContent) {
      headers['Content-Type'] = 'application/json; charset=UTF-8';
    }
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    } else {
       // This warning is okay for login/signup calls, but potentially indicates an issue elsewhere
       print("ApiClient: Warning - Token is missing for an authenticated request.");
    }
    // API Key is always added if available (checked in constructor)
    headers['X-API-Key'] = apiKey;
    return headers;
  }

   /// Constructs headers specifically for FormData requests (no Content-Type needed).
   Map<String, String> _getAuthApiHeadersOnly(String? token) {
     final headers = <String, String>{};
     if (token != null && token.isNotEmpty) {
       headers['Authorization'] = 'Bearer $token';
     } else {
       print("ApiClient: Warning - Token is missing for a multipart authenticated request.");
     }
     headers['X-API-Key'] = apiKey;
     return headers;
   }

  // --- Core HTTP Methods ---

  /// Performs an HTTP GET request.
  Future<dynamic> get(String endpoint, {String? token, Map<String, dynamic>? queryParams}) async {
    final url = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams?.map((key, value) => MapEntry(key, value?.toString()))); // Ensure query params are strings
    print("ApiClient GET: $url");
    try {
      final response = await _httpClient.get(
        url,
        headers: _getHeaders(token, isJsonContent: false), // GET requests typically don't send JSON body
      );
      return _handleResponse(response);
    } on TimeoutException catch (e) {
        print("ApiClient GET Error (Timeout): $e");
        throw Exception("Request timed out. Please check your connection.");
    } on SocketException catch (e) {
        print("ApiClient GET Error (Socket): $e");
        throw Exception("Network error. Could not reach the server.");
    } on TlsException catch (e) { // Handle TLS/SSL errors
        print("ApiClient GET Error (TLS): $e");
        throw Exception("Secure connection failed. Certificate issue?");
    } on http.ClientException catch (e) {
         print("ApiClient GET Error (Client): $e");
         throw Exception("HTTP client error: $e");
    } catch (e) {
       print("ApiClient GET Error (Unknown): $e");
       throw Exception("An unexpected error occurred during GET request: $e");
    }
  }

  /// Performs an HTTP POST request.
  Future<dynamic> post(String endpoint, {String? token, dynamic body}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print("ApiClient POST: $url");
     try {
        final response = await _httpClient.post(
          url,
          headers: _getHeaders(token, isJsonContent: true), // Assume JSON body for standard POST
          body: json.encode(body), // Encode body as JSON
        );
        return _handleResponse(response);
     } on TimeoutException catch (e) {
        print("ApiClient POST Error (Timeout): $e"); throw Exception("Request timed out. Please check your connection.");
     } on SocketException catch (e) {
         print("ApiClient POST Error (Socket): $e"); throw Exception("Network error. Could not reach the server.");
     } on TlsException catch (e) {
         print("ApiClient POST Error (TLS): $e"); throw Exception("Secure connection failed. Certificate issue?");
     } on http.ClientException catch (e) {
          print("ApiClient POST Error (Client): $e"); throw Exception("HTTP client error: $e");
     } catch (e) {
        print("ApiClient POST Error (Unknown): $e"); throw Exception("An unexpected error occurred during POST request: $e");
     }
  }

  /// Performs an HTTP PUT request.
  Future<dynamic> put(String endpoint, {String? token, dynamic body}) async {
     final url = Uri.parse('$baseUrl$endpoint');
     print("ApiClient PUT: $url");
      try {
        final response = await _httpClient.put(
          url,
          headers: _getHeaders(token, isJsonContent: true),
          body: json.encode(body),
        );
        return _handleResponse(response);
     } on TimeoutException catch (e) {
        print("ApiClient PUT Error (Timeout): $e"); throw Exception("Request timed out. Please check your connection.");
     } on SocketException catch (e) {
         print("ApiClient PUT Error (Socket): $e"); throw Exception("Network error. Could not reach the server.");
     } on TlsException catch (e) {
         print("ApiClient PUT Error (TLS): $e"); throw Exception("Secure connection failed. Certificate issue?");
     } on http.ClientException catch (e) {
          print("ApiClient PUT Error (Client): $e"); throw Exception("HTTP client error: $e");
     } catch (e) {
        print("ApiClient PUT Error (Unknown): $e"); throw Exception("An unexpected error occurred during PUT request: $e");
     }
  }

  /// Performs an HTTP DELETE request.
  Future<dynamic> delete(String endpoint, {String? token, dynamic body}) async {
      final url = Uri.parse('$baseUrl$endpoint');
      print("ApiClient DELETE: $url");
      try {
          final request = http.Request('DELETE', url);
          // Use getHeaders, set isJsonContent based on if body exists
          request.headers.addAll(_getHeaders(token, isJsonContent: body != null));
          if (body != null) {
              request.body = json.encode(body); // Add body if provided
          }
          final streamedResponse = await _httpClient.send(request);
          final response = await http.Response.fromStream(streamedResponse);
          return _handleResponse(response);
       } on TimeoutException catch (e) {
          print("ApiClient DELETE Error (Timeout): $e"); throw Exception("Request timed out. Please check your connection.");
       } on SocketException catch (e) {
           print("ApiClient DELETE Error (Socket): $e"); throw Exception("Network error. Could not reach the server.");
       } on TlsException catch (e) {
           print("ApiClient DELETE Error (TLS): $e"); throw Exception("Secure connection failed. Certificate issue?");
       } on http.ClientException catch (e) {
            print("ApiClient DELETE Error (Client): $e"); throw Exception("HTTP client error: $e");
       } catch (e) {
          print("ApiClient DELETE Error (Unknown): $e"); throw Exception("An unexpected error occurred during DELETE request: $e");
       }
  }


  /// Performs a Multipart HTTP request (POST or PUT) for file uploads.
  Future<dynamic> multipartRequest(
    String method, // 'POST' or 'PUT'
    String endpoint, {
    required String? token,
    required Map<String, String> fields,
    List<http.MultipartFile>? files,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print("ApiClient Multipart $method: $url");
    try {
        var request = http.MultipartRequest(method, url);
        request.headers.addAll(_getAuthApiHeadersOnly(token)); // Use specific headers for multipart
        request.fields.addAll(fields);

        if (files != null) {
          request.files.addAll(files);
        }

        final streamedResponse = await _httpClient.send(request);
        final response = await http.Response.fromStream(streamedResponse);
        return _handleResponse(response);
    } on TimeoutException catch (e) {
        print("ApiClient Multipart Error (Timeout): $e"); throw Exception("Request timed out. Please check your connection.");
    } on SocketException catch (e) {
        print("ApiClient Multipart Error (Socket): $e"); throw Exception("Network error. Could not reach the server.");
    } on TlsException catch (e) {
         print("ApiClient Multipart Error (TLS): $e"); throw Exception("Secure connection failed. Certificate issue?");
    } on http.ClientException catch (e) {
       print("ApiClient Multipart Error (Client): $e"); throw Exception("HTTP client error: $e");
    } catch (e) {
       print("ApiClient Multipart Error (Unknown): $e"); throw Exception("An unexpected error occurred during multipart request: $e");
    }
  }


  // --- Response Handler ---
  /// Handles standard API responses, decoding JSON or throwing exceptions on error.
  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    print("ApiClient Response: Status $statusCode, Path: ${response.request?.url.path}");

    if (statusCode >= 200 && statusCode < 300) {
      // Success case
      if (response.bodyBytes.isEmpty) { // Check bytes for empty body (correct for 204)
         print("ApiClient Response: Empty body (e.g., 204 No Content).");
        return null;
      }
      try {
         final dynamic decodedBody = json.decode(response.body);
         // print("ApiClient Response Body: $decodedBody"); // Avoid logging sensitive data
         return decodedBody; // Decode JSON body
      } on FormatException catch(e) {
           print("ApiClient Response Error (Format): Failed to decode JSON for success response ($statusCode). Body: ${response.body.substring(0, response.body.length < 100 ? response.body.length : 100)}...");
           // Return raw body or throw error depending on expected behavior
           throw Exception("Invalid JSON response from server: $e");
      } catch(e) {
           print("ApiClient Response Error (Unknown Decode): Error decoding body for success response ($statusCode): $e. Body: ${response.body.substring(0, response.body.length < 100 ? response.body.length : 100)}...");
            throw Exception("Error processing successful response: $e");
      }
    } else {
      // Error case (4xx or 5xx)
      String errorMessage = 'API request failed with status $statusCode';
      String? errorDetail;
      try {
        if (response.body.isNotEmpty) {
            final errorBody = json.decode(response.body);
             // Check for common FastAPI error structure {'detail': '...'}
            errorDetail = errorBody['detail'] ?? 'Unknown API error detail';
            errorMessage = 'API Error $statusCode: $errorDetail';
        } else {
            errorMessage = 'API Error $statusCode: No response body';
        }
      } on FormatException {
           // Body was not JSON
          errorMessage = 'API Error $statusCode: Invalid response format';
          if (response.body.isNotEmpty) {
             errorMessage += ' - Body: ${response.body.substring(0, response.body.length < 100 ? response.body.length : 100)}...';
          }
      } catch (e) {
           // Other error during parsing
           errorMessage = 'API Error $statusCode: Failed to parse error response: $e';
      }

      print("ApiClient Response Error ($statusCode): $errorMessage");
      // Throw a specific exception type if needed, or just a general one
      // Can include errorDetail in the exception if desired
      throw Exception(errorMessage);
    }
  }

  /// Closes the underlying HTTP client. Call this when the service is no longer needed.
  void dispose() {
    _httpClient.close();
    print("ApiClient disposed, HTTP client closed.");
  }
}
