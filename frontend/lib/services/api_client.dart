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
  String? _authToken;

  /// Creates a new ApiClient instance.
  /// [client] can be provided for testing purposes.
  ApiClient({http.Client? client})
      : _httpClient = client ?? http.Client(),
        apiKey = _apiKey {
    if (apiKey.isEmpty) {
      const errorMessage = "API_KEY environment variable not set during build. Cannot initialize ApiClient.";
      print("FATAL ERROR: $errorMessage");
      throw Exception(errorMessage);
    }
    print("ApiClient initialized with base URL: $baseUrl and API Key (truncated): ${apiKey.substring(0, 5)}...");
  }

  // --- Core Helper Methods ---

  /// Returns the base URL.
  String getBaseUrl() {
    return baseUrl;
  }

  /// Constructs standard headers for API requests, including Auth and API Key.
  Map<String, String> _getHeaders(String? token, {bool isJsonContent = true}) {
    final headers = <String, String>{};
    if (isJsonContent) {
      headers['Content-Type'] = 'application/json; charset=UTF-8';
    }
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    } else {
      print("ApiClient: Warning - Token is missing for an authenticated request.");
    }
    headers['X-API-Key'] = apiKey;
    return headers;
  }

  /// Public method to get headers using current auth token.
  Map<String, String> getHeaders({bool isJson = true}) {
    return _getHeaders(_authToken, isJsonContent: isJson);
  }

  /// Sets or clears the auth token for future requests.
  void setAuthToken(String? token) {
    _authToken = token;
    print("ApiClient: Auth token ${token == null ? 'cleared' : 'set'}.");
  }

  // --- HTTP Methods ---

  /// Performs an HTTP GET request.
  Future<dynamic> get(String endpoint, {Map<String, String>? queryParameters}) async {
    final url = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParameters);
    print("ApiClient GET: $url");
    try {
      final response = await _httpClient.get(
        url,
        headers: getHeaders(isJson: false), // GET usually doesn't need JSON headers
      );
      return _handleResponse(response);
    } on TimeoutException catch (e) {
      print("ApiClient GET Error (Timeout): $e");
      throw Exception("Request timed out. Please check your connection.");
    } catch (e) {
      print("ApiClient GET Error: $e");
      throw Exception("An unexpected error occurred during GET request: $e");
    }
  }

  /// Performs an HTTP POST request.
  Future<dynamic> post(String endpoint, {dynamic body}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print("ApiClient POST: $url");
    try {
      final response = await _httpClient.post(
        url,
        headers: getHeaders(isJson: true),
        body: json.encode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      print("ApiClient POST Error: $e");
      throw Exception("An unexpected error occurred during POST request: $e");
    }
  }

  /// Performs an HTTP PUT request.
  Future<dynamic> put(String endpoint, {dynamic body}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print("ApiClient PUT: $url");
    try {
      final response = await _httpClient.put(
        url,
        headers: getHeaders(isJson: true),
        body: json.encode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      print("ApiClient PUT Error: $e");
      throw Exception("An unexpected error occurred during PUT request: $e");
    }
  }

  /// Performs an HTTP DELETE request.
  Future<dynamic> delete(String endpoint, {dynamic body}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print("ApiClient DELETE: $url");
    try {
      final request = http.Request('DELETE', url);
      request.headers.addAll(getHeaders(isJson: body != null));
      if (body != null) {
        request.body = json.encode(body);
      }
      final streamedResponse = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } catch (e) {
      print("ApiClient DELETE Error: $e");
      throw Exception("An unexpected error occurred during DELETE request: $e");
    }
  }

  /// Handles multipart/form-data requests (e.g., file uploads).
  Future<http.StreamedResponse> multipartRequest(
      String method,
      String endpoint, {
        Map<String, String>? fields,
        List<http.MultipartFile>? files,
      }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print('$method (Multipart) Request to: $url');
    var request = http.MultipartRequest(method, url);

    // Use getHeaders but remove Content-Type as multipart sets its own
    final headers = getHeaders(isJson: false);
    request.headers.addAll(headers);

    if (fields != null) {
      request.fields.addAll(fields);
    }
    if (files != null) {
      request.files.addAll(files);
    }

    try {
      return await request.send();
    } catch (e) {
      print("ApiClient: Error sending multipart request: $e");
      throw Exception("Failed to send multipart request: $e");
    }
  }

  // --- Response Handler ---

  /// Handles standard API responses, decoding JSON or throwing exceptions on error.
  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    print("ApiClient Response: Status $statusCode, Path: ${response.request?.url.path}");

    if (statusCode >= 200 && statusCode < 300) {
      if (response.bodyBytes.isEmpty) {
        print("ApiClient Response: Empty body (e.g., 204 No Content).");
        return null;
      }
      try {
        final dynamic decodedBody = json.decode(response.body);
        return decodedBody;
      } on FormatException catch (e) {
        print("ApiClient Response Error (Format): Failed to decode JSON for success response ($statusCode).");
        throw Exception("Invalid JSON response from server: $e");
      }
    } else {
      String errorMessage = 'API request failed with status $statusCode';
      String? errorDetail;
      try {
        if (response.body.isNotEmpty) {
          final errorBody = json.decode(response.body);
          errorDetail = errorBody['detail'] ?? 'Unknown API error detail';
          errorMessage = 'API Error $statusCode: $errorDetail';
        } else {
          errorMessage = 'API Error $statusCode: No response body';
        }
      } catch (e) {
        errorMessage = 'API Error $statusCode: Invalid response format';
      }

      print("ApiClient Response Error ($statusCode): $errorMessage");
      throw Exception(errorMessage);
    }
  }

  /// Closes the underlying HTTP client. Call this when the service is no longer needed.
  void dispose() {
    _httpClient.close();
    print("ApiClient disposed, HTTP client closed.");
  }
}
