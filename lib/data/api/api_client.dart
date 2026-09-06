import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../../core/constants/app_config.dart';
import 'api_exception.dart';
import 'token_store.dart';

/// Every call to the Kudi9ja server goes through here.
///
/// Four things live in this class because they must hold for *every* request,
/// and scattering them across call sites is how one endpoint quietly ends up
/// without them:
///
///   * **The bearer token**, attached when there is one.
///   * **Refresh on expiry.** An access token lasts fifteen minutes; a refresh
///     token thirty days and rotates on every use. When a request comes back
///     `TOKEN_EXPIRED`, the token is refreshed once and the request retried. A
///     second failure signs the customer out rather than looping.
///   * **The error envelope**, decoded into [ApiException] so no caller ever
///     matches on a status code or a message string.
///   * **Idempotency keys** on anything that moves money.
class ApiClient {
  ApiClient({
    required TokenStore tokens,
    http.Client? httpClient,
    String? baseUrl,
    this.onSessionLost,
  })  : _tokens = tokens,
        _http = httpClient ?? http.Client(),
        _baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).replaceAll(RegExp(r'/+$'), '');

  final TokenStore _tokens;
  final http.Client _http;
  final String _baseUrl;

  /// Called when the session is gone for good and the customer has to sign in
  /// again. Fires once per loss, not once per failed request.
  final void Function()? onSessionLost;

  /// How long to wait for the server.
  ///
  /// Generous, because the free Render tier sleeps and a first request after
  /// idle can take the best part of a minute to wake it. A shorter timeout
  /// would show a connection error to a customer whose connection is fine.
  static const _timeout = Duration(seconds: 60);

  /// Serialises refreshes. Without this, six screens loading at once on a cold
  /// start each notice the expired token and fire their own refresh — and since
  /// the server rotates the refresh token on use, five of them present a token
  /// that has already been spent and the session is destroyed.
  Future<void>? _refreshing;

  TokenStore get tokens => _tokens;
  bool get hasSession => _tokens.hasSession;

  // ───────────────────────────────────────────────────────────────────────────
  // Verbs
  // ───────────────────────────────────────────────────────────────────────────

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    String? idempotencyKey,
    bool authenticated = true,
  }) =>
      _send('POST', path,
          body: body,
          query: query,
          idempotencyKey: idempotencyKey,
          authenticated: authenticated);

  Future<dynamic> patch(String path, {Object? body, String? idempotencyKey}) =>
      _send('PATCH', path, body: body, idempotencyKey: idempotencyKey);

  Future<dynamic> put(String path, {Object? body, String? idempotencyKey}) =>
      _send('PUT', path, body: body, idempotencyKey: idempotencyKey);

  Future<dynamic> delete(String path, {Object? body}) =>
      _send('DELETE', path, body: body);

  /// A multipart upload — used for the pay-in receipt, which is the only place
  /// the app sends a file.
  Future<dynamic> upload(
    String path, {
    required String fieldName,
    required List<int> bytes,
    required String filename,
    String? contentType,
    Map<String, String> fields = const {},
    String? idempotencyKey,
  }) async {
    Future<http.Response> attempt() async {
      final request = http.MultipartRequest('POST', _uri(path, null))
        ..fields.addAll(fields)
        ..files.add(http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: filename,
          contentType: _mediaType(contentType),
        ));
      request.headers.addAll(await _headers(
        json: false,
        idempotencyKey: idempotencyKey,
        authenticated: true,
      ));
      final streamed = await _http.send(request).timeout(_timeout);
      return http.Response.fromStream(streamed);
    }

    return _withRefresh(attempt);
  }

  void close() => _http.close();

  // ───────────────────────────────────────────────────────────────────────────
  // Transport
  // ───────────────────────────────────────────────────────────────────────────

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    String? idempotencyKey,
    bool authenticated = true,
  }) {
    Future<http.Response> attempt() async {
      final uri = _uri(path, query);
      final headers = await _headers(
        json: body != null,
        idempotencyKey: idempotencyKey,
        authenticated: authenticated,
      );
      final encoded = body == null ? null : jsonEncode(body);

      final request = http.Request(method, uri)..headers.addAll(headers);
      if (encoded != null) request.body = encoded;

      final streamed = await _http.send(request).timeout(_timeout);
      return http.Response.fromStream(streamed);
    }

    return _withRefresh(attempt, authenticated: authenticated);
  }

  /// How long to wait before a second try at a server that was not ready.
  ///
  /// Short, because the failures this covers come back fast: a proxy answering
  /// 502 while the instance behind it starts does so in about a second.
  static const _retryPause = Duration(seconds: 3);

  /// Runs an attempt, and tries once more if the server was not ready.
  ///
  /// A sleeping instance does not refuse a request politely — it produces a
  /// timeout, a dropped connection, or the hosting proxy's own 502/503 while
  /// the container starts. All three are indistinguishable from being offline
  /// to the code that reads them, and all three are cured by asking again a
  /// moment later.
  ///
  /// Only once, and only for those. A refusal from the application itself —
  /// a wrong password, insufficient funds — is an answer, and asking again
  /// would get the same answer more slowly.
  ///
  /// Safe for money, because every money-moving request carries an idempotency
  /// key: if the first attempt reached the server after all, the second is
  /// recognised as the same request and returns the original result rather
  /// than moving the money twice.
  Future<http.Response> _attemptWithRetry(
      Future<http.Response> Function() attempt) async {
    try {
      final response = await attempt();
      if (!_serverNotReady(response)) return response;
      await Future<void>.delayed(_retryPause);
      return attempt();
    } on TimeoutException {
      await Future<void>.delayed(_retryPause);
      return attempt();
    } on SocketException {
      await Future<void>.delayed(_retryPause);
      return attempt();
    } on http.ClientException {
      await Future<void>.delayed(_retryPause);
      return attempt();
    }
  }

  /// Whether this is the host saying "not yet" rather than the application
  /// saying anything at all.
  ///
  /// Checked on the body as well as the status, because the application does
  /// legitimately return 503 for maintenance mode — and that one is a real
  /// answer, in the usual envelope, which must reach the customer rather than
  /// being retried behind their back.
  static bool _serverNotReady(http.Response response) {
    if (response.statusCode != 502 &&
        response.statusCode != 503 &&
        response.statusCode != 504) {
      return false;
    }
    final type = response.headers['content-type'] ?? '';
    return !type.contains('json');
  }

  /// Runs a request, refreshing the session once if the server says the access
  /// token has expired.
  Future<dynamic> _withRefresh(
    Future<http.Response> Function() attempt, {
    bool authenticated = true,
  }) async {
    // Refresh proactively when the token is known to be spent, so the common
    // case costs one round trip rather than a guaranteed failure and a retry.
    if (authenticated && _tokens.hasSession && _tokens.isAccessExpired) {
      await _refreshSession();
    }

    http.Response response;
    try {
      response = await _attemptWithRetry(attempt);
    } on TimeoutException {
      throw ApiException.offline('timed out after ${_timeout.inSeconds}s');
    } on SocketException catch (e) {
      throw ApiException.offline(e.message);
    } on http.ClientException catch (e) {
      throw ApiException.offline(e.message);
    }

    if (response.statusCode != 401 || !authenticated) {
      return _decode(response);
    }

    // A 401 on a request we thought was authenticated. Refresh once and retry;
    // if it fails again the session is genuinely gone.
    final error = _errorFrom(response);
    if (!_tokens.hasSession || !error.isAuthFailure) {
      throw error;
    }

    final refreshed = await _refreshSession();
    if (!refreshed) throw error;

    try {
      return _decode(await _attemptWithRetry(attempt));
    } on TimeoutException {
      throw ApiException.offline('timed out after ${_timeout.inSeconds}s');
    } on SocketException catch (e) {
      throw ApiException.offline(e.message);
    }
  }

  /// Exchanges the refresh token for a new pair.
  ///
  /// Returns whether there is a usable session afterwards. Concurrent callers
  /// all wait on the same in-flight refresh rather than starting their own,
  /// because the server rotates the refresh token and a second use of a spent
  /// one is treated as theft — it destroys the whole session.
  Future<bool> _refreshSession() {
    final running = _refreshing;
    if (running != null) return running.then((_) => _tokens.hasSession);

    final future = _doRefresh();
    _refreshing = future;
    return future.whenComplete(() => _refreshing = null).then((_) => _tokens.hasSession);
  }

  Future<void> _doRefresh() async {
    final refresh = _tokens.refreshToken;
    if (refresh == null) return;

    http.Response response;
    try {
      response = await _http
          .post(
            _uri('/auth/refresh', null),
            headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({'refreshToken': refresh}),
          )
          .timeout(_timeout);
    } catch (_) {
      // Offline. The session may still be perfectly good, so it is left alone —
      // signing the customer out because their train went into a tunnel would
      // lose their place for no reason.
      return;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = _decode(response);
      if (body is Map<String, dynamic>) {
        await _tokens.save(
          accessToken: body['accessToken'] as String,
          refreshToken: body['refreshToken'] as String,
          expiresInSeconds: (body['expiresInSeconds'] as num?)?.toInt() ?? 900,
          sessionId: body['sessionId'] as String?,
        );
        return;
      }
    }

    // The server refused the refresh token: it has expired, been rotated away,
    // or the session was signed out elsewhere. This is the one case where the
    // customer really does have to sign in again.
    await _tokens.clear();
    onSessionLost?.call();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Requests and responses
  // ───────────────────────────────────────────────────────────────────────────

  Uri _uri(String path, Map<String, dynamic>? query) {
    final normalised = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$_baseUrl$normalised');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      for (final entry in query.entries)
        if (entry.value != null) entry.key: '${entry.value}',
    });
  }

  Future<Map<String, String>> _headers({
    required bool json,
    required bool authenticated,
    String? idempotencyKey,
  }) async {
    await _tokens.load();
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      if (authenticated && _tokens.accessToken != null)
        'Authorization': 'Bearer ${_tokens.accessToken}',
    };
  }

  dynamic _decode(http.Response response) {
    final ok = response.statusCode >= 200 && response.statusCode < 300;

    if (response.bodyBytes.isEmpty) {
      if (ok) return null;
      throw ApiException(
        code: ApiErrorCode.unknown,
        message: 'Something went wrong. Please try again.',
        status: response.statusCode,
      );
    }

    dynamic body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      // Not JSON. Almost always an infrastructure page rather than the
      // application — a proxy's 502, or Render's own error while the service
      // wakes — so it is reported as unreachable rather than as a server bug.
      if (ok) return null;
      throw ApiException.offline('server returned ${response.statusCode}');
    }

    if (ok) return body;
    throw body is Map<String, dynamic>
        ? ApiException.fromBody(body, status: response.statusCode)
        : ApiException.offline('server returned ${response.statusCode}');
  }

  ApiException _errorFrom(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        return ApiException.fromBody(body, status: response.statusCode);
      }
    } catch (_) {
      // fall through
    }
    return ApiException(
      code: ApiErrorCode.unauthenticated,
      message: 'Please sign in again.',
      status: response.statusCode,
    );
  }

  /// The receipt's declared type, so the server stores it as what it is.
  ///
  /// A bad or missing value is dropped rather than guessed: `http` then omits
  /// the header, and the server falls back to the filename extension, which is
  /// exactly what it does for a browser upload.
  static MediaType? _mediaType(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return MediaType.parse(value);
    } catch (_) {
      return null;
    }
  }
}
