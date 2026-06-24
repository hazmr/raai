import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/token_store.dart';
import 'api_exception.dart';

/// Base URL is injected at build time so dev/prod differ without code changes:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080/api/v1
/// Default targets the Android emulator's host alias (10.0.2.2).
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080/api/v1',
);

/// Owns the configured [Dio]: attaches the bearer token, and on a 401 refreshes
/// the token **once** before retrying; if refresh fails it clears the session and
/// calls [onSessionExpired] (the router then bounces to /login) — §5.1, §6.2.
class DioClient {
  DioClient({
    required this.tokens,
    required this.onSessionExpired,
    this.onPaywallRequired,
    String? baseUrl,
  }) {
    final options = BaseOptions(
      baseUrl: baseUrl ?? kApiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      contentType: Headers.jsonContentType,
    );
    dio = Dio(options);
    _refreshDio = Dio(options); // no interceptors → never recurses

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (req, handler) async {
        final access = await tokens.readAccess();
        if (access != null) {
          req.headers['Authorization'] = 'Bearer $access';
        }
        handler.next(req);
      },
      onError: (e, handler) async {
        if (e.response?.statusCode == 402) {
          onPaywallRequired?.call(); // §4: any 402 routes the farmer to /paywall
        }
        if (e.response?.statusCode == 401 && !_isRefreshCall(e)) {
          final ok = await _tryRefresh();
          if (ok) {
            try {
              handler.resolve(await _retry(e.requestOptions));
              return;
            } catch (_) {
              // fall through to reject below
            }
          } else {
            await tokens.clear();
            onSessionExpired();
          }
        }
        handler.next(e);
      },
    ));
  }

  final TokenStore tokens;
  final void Function() onSessionExpired;
  final void Function()? onPaywallRequired;

  late final Dio dio;
  late final Dio _refreshDio;

  Completer<bool>? _refreshing;

  bool _isRefreshCall(DioException e) =>
      e.requestOptions.path.contains('/auth/refresh') ||
      e.requestOptions.path.contains('/doctor/redeem');

  /// Refreshes the access token, coalescing concurrent 401s into one call. A user
  /// rotates via /auth/refresh; a doctor re-redeems the stored invite secret (an
  /// ended invite makes this fail → session ends).
  Future<bool> _tryRefresh() {
    if (_refreshing != null) return _refreshing!.future;
    final completer = Completer<bool>();
    _refreshing = completer;

    () async {
      try {
        final kind = await tokens.readKind();
        if (kind == 'doctor') {
          final invite = await tokens.readInviteToken();
          if (invite == null) {
            completer.complete(false);
            return;
          }
          final resp = await _refreshDio.post('/doctor/redeem', data: {'token': invite});
          await tokens.saveAccess((resp.data as Map)['accessToken'] as String);
          completer.complete(true);
          return;
        }
        final refresh = await tokens.readRefresh();
        if (refresh == null) {
          completer.complete(false);
          return;
        }
        final resp = await _refreshDio.post('/auth/refresh', data: {'refreshToken': refresh});
        final data = resp.data as Map;
        await tokens.saveUser(
          access: data['accessToken'] as String,
          refresh: data['refreshToken'] as String,
        );
        completer.complete(true);
      } catch (_) {
        completer.complete(false);
      } finally {
        _refreshing = null;
      }
    }();

    return completer.future;
  }

  Future<Response<dynamic>> _retry(RequestOptions req) async {
    final access = await tokens.readAccess();
    final headers = Map<String, dynamic>.from(req.headers);
    if (access != null) headers['Authorization'] = 'Bearer $access';
    return dio.request<dynamic>(
      req.path,
      data: req.data,
      queryParameters: req.queryParameters,
      options: Options(method: req.method, headers: headers),
    );
  }
}

/// Runs a dio call and converts any failure into the single [ApiException] funnel.
Future<T> guardApi<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
}
