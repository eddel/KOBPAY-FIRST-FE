import "dart:async";
import "dart:convert";
import "package:http/http.dart" as http;
import "../config/app_config.dart";

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final dynamic details;

  @override
  String toString() => "ApiException($statusCode): $message";
}

class ApiClient {
  ApiClient({
    required this.getAccessToken,
    required this.getRefreshToken,
    required this.onTokensUpdated
  });

  final String? Function() getAccessToken;
  final String? Function() getRefreshToken;
  final Future<void> Function(String accessToken, String refreshToken) onTokensUpdated;

  final http.Client _client = http.Client();

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool auth = true
  }) {
    return _request("GET", path, query: query, auth: auth);
  }

  Future<dynamic> post(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool auth = true
  }) {
    return _request("POST", path, query: query, body: body, auth: auth);
  }

  Future<dynamic> delete(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool auth = true
  }) {
    return _request("DELETE", path, query: query, body: body, auth: auth);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool auth = true,
    bool retry = true
  }) async {
    final uri = _buildUri(path, query);
    final headers = <String, String>{
      "Content-Type": "application/json",
      "Accept": "application/json"
    };
    if (auth) {
      final token = getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers["Authorization"] = "Bearer $token";
      }
    }

    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null && method != "GET") {
      request.body = jsonEncode(body);
    }
    http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ApiException("Request timed out", statusCode: 408);
    }

    final responseBody = await http.Response.fromStream(response);
    final decoded = _decodeBody(responseBody.body);

    if (responseBody.statusCode == 401 && retry && getRefreshToken() != null) {
      final refreshed = await _refreshTokens();
      if (refreshed) {
        return _request(method, path,
            query: query, body: body, auth: auth, retry: false);
      }
    }

    if (responseBody.statusCode >= 400) {
      throw ApiException(
        _extractMessage(decoded) ?? "Request failed",
        statusCode: responseBody.statusCode,
        details: decoded
      );
    }

    if (decoded is Map && decoded["ok"] == false) {
      throw ApiException(
        _extractMessage(decoded) ?? "Request failed",
        statusCode: responseBody.statusCode,
        details: decoded
      );
    }

    return decoded;
  }

  Uri _buildUri(String path, Map<String, String>? query) {
    final base = AppConfig.apiBaseUrl;
    final uri = Uri.parse("$base$path");
    if (query == null || query.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: query);
  }

  dynamic _decodeBody(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  String? _extractMessage(dynamic decoded) {
    if (decoded is Map) {
      final error = decoded["error"];
      if (error is Map && error["message"] is String) {
        return error["message"] as String;
      }
      if (decoded["message"] is String) {
        return decoded["message"] as String;
      }
    }
    return null;
  }

  Future<bool> _refreshTokens() async {
    final refreshToken = getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    final uri = _buildUri("/api/auth/refresh", null);
    final response = await _client.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: jsonEncode({"refreshToken": refreshToken})
    );

    final decoded = _decodeBody(response.body);
    if (response.statusCode >= 400 || decoded is! Map) {
      return false;
    }

    final access = decoded["accessToken"];
    final refresh = decoded["refreshToken"];
    if (access is String && refresh is String) {
      await onTokensUpdated(access, refresh);
      return true;
    }

    return false;
  }
}
