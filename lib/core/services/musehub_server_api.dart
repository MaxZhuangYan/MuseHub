import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/muse_user.dart';
import 'music_api.dart';

class MuseHubAuthResult {
  const MuseHubAuthResult({
    required this.user,
    required this.token,
  });

  final MuseUser user;
  final String token;
}

class MuseHubServerException implements Exception {
  const MuseHubServerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MuseHubServerApi {
  MuseHubServerApi({
    http.Client? client,
    String baseUrl = defaultBaseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = MusicApi.normalizeBaseUrl(baseUrl);

  static const defaultBaseUrl = 'http://127.0.0.1:30490';
  static const _timeout = Duration(seconds: 8);

  final http.Client _client;
  String _baseUrl;

  String get baseUrl => _baseUrl;

  set baseUrl(String value) {
    _baseUrl = MusicApi.normalizeBaseUrl(value);
  }

  Future<MuseHubAuthResult> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    return _auth(
      '/auth/register',
      {
        'email': email,
        'password': password,
        if (displayName != null && displayName.trim().isNotEmpty)
          'displayName': displayName.trim(),
      },
    );
  }

  Future<MuseHubAuthResult> login({
    required String email,
    required String password,
  }) {
    return _auth('/auth/login', {
      'email': email,
      'password': password,
    });
  }

  Future<MuseUser> me(String token) async {
    final data = await _requestJson(
      '/me',
      method: 'GET',
      token: token,
    );
    final user = data['user'];
    if (user is! Map<String, dynamic>) {
      throw const MuseHubServerException('Invalid user response');
    }
    return MuseUser.fromJson(user);
  }

  Future<void> logout(String token) async {
    await _requestJson(
      '/auth/logout',
      method: 'POST',
      token: token,
    );
  }

  Future<MuseHubAuthResult> _auth(
    String path,
    Map<String, Object?> body,
  ) async {
    final data = await _requestJson(path, method: 'POST', body: body);
    final user = data['user'];
    final token = data['token']?.toString();
    if (user is! Map<String, dynamic> || token == null || token.isEmpty) {
      throw const MuseHubServerException('Invalid auth response');
    }
    return MuseHubAuthResult(
      user: MuseUser.fromJson(user),
      token: token,
    );
  }

  Future<Map<String, dynamic>> _requestJson(
    String path, {
    required String method,
    Map<String, Object?>? body,
    String? token,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{
      'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
    };

    try {
      final response = switch (method) {
        'GET' => await _client.get(uri, headers: headers).timeout(_timeout),
        'POST' => await _client
            .post(uri, headers: headers, body: jsonEncode(body ?? const {}))
            .timeout(_timeout),
        'PATCH' => await _client
            .patch(uri, headers: headers, body: jsonEncode(body ?? const {}))
            .timeout(_timeout),
        'DELETE' =>
          await _client.delete(uri, headers: headers).timeout(_timeout),
        _ => throw MuseHubServerException('Unsupported method $method'),
      };
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const MuseHubServerException('Invalid server response');
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }
      throw MuseHubServerException(
        decoded['error']?.toString() ??
            'Server request failed (${response.statusCode})',
      );
    } on TimeoutException {
      throw const MuseHubServerException('Server request timed out');
    } on http.ClientException {
      throw const MuseHubServerException('Server is unreachable');
    } on FormatException {
      throw const MuseHubServerException('Invalid server response');
    }
  }
}
