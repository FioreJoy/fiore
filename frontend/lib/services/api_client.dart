// frontend/lib/services/api_client.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io'; // For File, SocketException, TlsException

import 'package:http/http.dart' as http;
// http_parser is not directly used here, but MultipartFile uses it.

import '../app_constants.dart'; // For AppConstants.baseUrl

// Define API Key as a constant (load from environment ideally using --dart-define)
// Compile using: flutter run --dart-define=API_KEY=YOUR_ACTUAL_API_KEY
const String _apiKeyFromEnv = String.fromEnvironment('API_KEY');

/// A base client for making authenticated API requests.
/// Handles adding Authorization (Bearer Token) and X-API-Key headers.
class ApiClient {
  final String baseUrl = AppConstants.baseUrl;
  final String apiKey;
  final http.Client _httpClient;

  /// Default timeout duration for requests.
  static const Duration _defaultTimeout = Duration(seconds: 20);
  static const Duration _uploadTimeout = Duration(seconds: 60);


  ApiClient({http.Client? client})
      : _httpClient = client ?? http.Client(),
        apiKey = _apiKeyFromEnv {
    if (apiKey.isEmpty) {
      const errorMessage = "FATAL ERROR: API_KEY environment variable not set during build. ApiClient cannot operate.";
      print(errorMessage);
      // In a real app, you might want a more graceful shutdown or error screen
      // For development, throwing an exception is appropriate.
      throw Exception(errorMessage);
    }
    print("ApiClient initialized. Base URL: $baseUrl, API Key Set: ${apiKey.isNotEmpty}");
  }

  // --- Header Helper ---
  Map<String, String> _getBaseHeaders(String? token) {
    final headers = <String, String>{
      'Accept': 'application/json', // We always expect JSON responses
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    // API Key is always added if available (checked in constructor)
    headers['X-API-Key'] = apiKey;
    return headers;
  }

  Map<String, String> _getJsonHeaders(String? token) {
    final headers = _getBaseHeaders(token);
    headers['Content-Type'] = 'application/json; charset=UTF-8';
    return headers;
  }

  // For multipart, Content-Type is set by http.MultipartRequest
  Map<String, String> _getMultipartAuthHeaders(String? token) {
    return _getBaseHeaders(token);
  }


  // --- Core HTTP Methods ---
  Future<dynamic> get(String endpoint, {String? token, Map<String, dynamic>? queryParams}) async {
    final url = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams?.map((key, value) => MapEntry(key, value?.toString())));
    print("ApiClient GET: $url");
    try {
      final response = await _httpClient.get(
        url,
        headers: _getBaseHeaders(token),
      ).timeout(_defaultTimeout);
      return _handleResponse(response, "GET $endpoint");
    } on TimeoutException catch (e) {
      print("ApiClient GET Error (Timeout) for $endpoint: $e");
      throw Exception("Request timed out. Please check your connection.");
    } on SocketException catch (e) {
      print("ApiClient GET Error (Socket) for $endpoint: $e");
      throw Exception("Network error. Could not reach the server.");
    } on TlsException catch (e) {
      print("ApiClient GET Error (TLS) for $endpoint: $e");
      throw Exception("Secure connection failed. Please check your network or try again later.");
    } on http.ClientException catch (e) {
      print("ApiClient GET Error (Client) for $endpoint: $e");
      throw Exception("A problem occurred with the request: ${e.message}");
    } catch (e) {
      print("ApiClient GET Error (Unknown) for $endpoint: $e");
      throw Exception("An unexpected error occurred: $e");
    }
  }

  Future<dynamic> post(String endpoint, {String? token, dynamic body}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print("ApiClient POST: $url, Body: ${body != null ? json.encode(body).substring(0, (json.encode(body).length < 100 ? json.encode(body).length : 100)) : 'null'}...");
    try {
      final response = await _httpClient.post(
        url,
        headers: _getJsonHeaders(token),
        body: json.encode(body),
      ).timeout(_defaultTimeout);
      return _handleResponse(response, "POST $endpoint");
    } on TimeoutException catch (e) {
      print("ApiClient POST Error (Timeout) for $endpoint: $e"); throw Exception("Request timed out.");
    } on SocketException catch (e) {
      print("ApiClient POST Error (Socket) for $endpoint: $e"); throw Exception("Network error.");
    } on TlsException catch (e) {
      print("ApiClient POST Error (TLS) for $endpoint: $e"); throw Exception("Secure connection failed.");
    } on http.ClientException catch (e) {
      print("ApiClient POST Error (Client) for $endpoint: $e"); throw Exception("HTTP client error: ${e.message}");
    } catch (e) {
      print("ApiClient POST Error (Unknown) for $endpoint: $e"); throw Exception("An unexpected error occurred: $e");
    }
  }

  Future<dynamic> put(String endpoint, {String? token, dynamic body}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    print("ApiClient PUT: $url, Body: ${body != null ? json.encode(body).substring(0, (json.encode(body).length < 100 ? json.encode(body).length : 100)) : 'null'}...");
    try {
      final response = await _httpClient.put(
        url,
        headers: _getJsonHeaders(token),
        body: json.encode(body),
      ).timeout(_defaultTimeout);
      return _handleResponse(response, "PUT $endpoint");
    } on TimeoutException catch (e) {
      print("ApiClient PUT Error (Timeout) for $endpoint: $e"); throw Exception("Request timed out.");
    } on SocketException catch (e) {
      print("ApiClient PUT Error (Socket) for $endpoint: $e"); throw Exception("Network error.");
    } on TlsException catch (e) {
      print("ApiClient PUT Error (TLS) for $endpoint: $e"); throw Exception("Secure connection failed.");
    } on http.ClientException catch (e) {
      print("ApiClient PUT Error (Client) for $endpoint: $e"); throw Exception("HTTP client error: ${e.message}");
    } catch (e) {
      print("ApiClient PUT Error (Unknown) for $endpoint: $e"); throw Exception("An unexpected error occurred: $e");
    }
  }

  Future<dynamic> delete(String endpoint, {String? token, dynamic body, Map<String, String>? queryParams}) async {
    final Uri initialUrl = Uri.parse('$baseUrl$endpoint');
    final Uri urlWithParams = queryParams != null && queryParams.isNotEmpty
        ? initialUrl.replace(queryParameters: queryParams)
        : initialUrl;
    print("ApiClient DELETE: $urlWithParams, Body: ${body != null ? json.encode(body).substring(0, (json.encode(body).length < 100 ? json.encode(body).length : 100)) : 'null'}...");
    try {
      final request = http.Request('DELETE', urlWithParams);
      request.headers.addAll(_getJsonHeaders(token));
      if (body != null) {
        request.body = json.encode(body);
      }
      final streamedResponse = await _httpClient.send(request).timeout(_defaultTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response, "DELETE $endpoint");
    } on TimeoutException catch (e) {
      print("ApiClient DELETE Error (Timeout) for $endpoint: $e"); throw Exception("Request timed out.");
    } on SocketException catch (e) {
      print("ApiClient DELETE Error (Socket) for $endpoint: $e"); throw Exception("Network error.");
    } on TlsException catch (e) {
      print("ApiClient DELETE Error (TLS) for $endpoint: $e"); throw Exception("Secure connection failed.");
    } on http.ClientException catch (e) {
      print("ApiClient DELETE Error (Client) for $endpoint: $e"); throw Exception("HTTP client error: ${e.message}");
    } catch (e) {
      print("ApiClient DELETE Error (Unknown) for $endpoint: $e"); throw Exception("An unexpected error occurred: $e");
    }
  }

  Future<dynamic> multipartRequest(
      String method, // 'POST' or 'PUT'
      String endpoint, {
        required String? token,
        required Map<String, String> fields,
        List<http.MultipartFile>? files,
        Map<String, String>? queryParams,
      }) async {
    Uri url = Uri.parse('$baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      url = url.replace(queryParameters: queryParams);
    }
    print("ApiClient Multipart $method: $url, Fields: $fields, Files: ${files?.length ?? 0}");
    try {
      var request = http.MultipartRequest(method, url);
      request.headers.addAll(_getMultipartAuthHeaders(token));
      request.fields.addAll(fields);

      if (files != null) {
        request.files.addAll(files);
      }

      final streamedResponse = await _httpClient.send(request).timeout(_uploadTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response, "Multipart $method $endpoint");
    } on TimeoutException catch (e) {
      print("ApiClient Multipart Error (Timeout) for $endpoint: $e"); throw Exception("Upload timed out. Please check your connection and try again.");
    } on SocketException catch (e) {
      print("ApiClient Multipart Error (Socket) for $endpoint: $e"); throw Exception("Network error during upload.");
    } on TlsException catch (e) {
      print("ApiClient Multipart Error (TLS) for $endpoint: $e"); throw Exception("Secure connection failed during upload.");
    } on http.ClientException catch (e) {
      print("ApiClient Multipart Error (Client) for $endpoint: $e"); throw Exception("HTTP client error during upload: ${e.message}");
    } catch (e) {
      print("ApiClient Multipart Error (Unknown) for $endpoint: $e"); throw Exception("An unexpected error occurred during upload: $e");
    }
  }

  dynamic _handleResponse(http.Response response, String requestInfo) {
    final statusCode = response.statusCode;
    final responseBodySnippet = response.body.substring(0, (response.body.length < 200 ? response.body.length : 200));
    print("ApiClient Response for $requestInfo: Status $statusCode, Body snippet: $responseBodySnippet...");

    if (statusCode >= 200 && statusCode < 300) {
      if (response.bodyBytes.isEmpty) {
        print("ApiClient Response: Empty body (e.g., 204 No Content).");
        return null;
      }
      try {
        final dynamic decodedBody = json.decode(response.body);
        return decodedBody;
      } on FormatException catch(e) {
        print("ApiClient Response Error (Format): Failed to decode JSON for success response ($statusCode) from $requestInfo. Error: $e");
        throw Exception("Invalid response format from server.");
      } catch(e) {
        print("ApiClient Response Error (Unknown Decode): Error decoding body for success response ($statusCode) from $requestInfo: $e.");
        throw Exception("Error processing server response.");
      }
    } else {
      String errorMessage = 'API request to $requestInfo failed with status $statusCode';
      String? errorDetail;
      try {
        if (response.body.isNotEmpty) {
          final errorBody = json.decode(response.body);
          errorDetail = errorBody['detail']?.toString() ?? 'Unknown API error detail';
          errorMessage = '$errorDetail (Code: $statusCode)';
        } else {
          errorMessage = 'Server error $statusCode: No additional details.';
        }
      } on FormatException {
        errorMessage = 'Server error $statusCode: Invalid error response format.';
        if (response.body.isNotEmpty) {
          errorMessage += ' Body: $responseBodySnippet...';
        }
      } catch (e) {
        errorMessage = 'Server error $statusCode: Failed to parse error response: $e';
      }
      print("ApiClient Response Error ($statusCode) from $requestInfo: $errorMessage. Full Body if relevant: ${response.body}");
      throw Exception(errorMessage);
    }
  }

  void dispose() {
    _httpClient.close();
    print("ApiClient disposed, HTTP client closed.");
  }
}