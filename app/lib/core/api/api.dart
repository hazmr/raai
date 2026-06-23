import 'package:dio/dio.dart';

import 'dio_client.dart';
import 'models.dart';

/// Thin typed wrappers over /api/v1. Every method runs through [guardApi] so
/// failures surface as the single ApiException (§6.1). Handlers/notifiers call
/// these; widgets never touch dio.
class RaaiApi {
  RaaiApi(this._client);
  final DioClient _client;
  Dio get _dio => _client.dio;

  // --- auth ---
  Future<AuthTokens> login(String phone, String password) => guardApi(() async {
        final r = await _dio.post('/auth/login', data: {
          'phoneNumber': phone,
          'password': password,
        });
        return AuthTokens.fromJson(r.data as Map<String, dynamic>);
      });

  Future<AuthTokens> register(String phone, String password, String role) => guardApi(() async {
        final r = await _dio.post('/auth/register', data: {
          'phoneNumber': phone,
          'password': password,
          'role': role,
        });
        return AuthTokens.fromJson(r.data as Map<String, dynamic>);
      });

  Future<void> logout() => guardApi(() => _dio.post('/auth/logout'));

  Future<User> me() => guardApi(() async {
        final r = await _dio.get('/me');
        return User.fromJson(r.data as Map<String, dynamic>);
      });

  // --- animals ---
  Future<Page<Animal>> animals({String? cursor, String? barcode, int limit = 50}) =>
      guardApi(() async {
        final r = await _dio.get('/animals', queryParameters: {
          'limit': limit,
          if (cursor != null) 'cursor': cursor,
          if (barcode != null) 'barcode': barcode,
        });
        return Page.fromJson(r.data as Map<String, dynamic>, Animal.fromJson);
      });

  Future<Animal> createAnimal(String barcode, {int? visitId, String? idempotencyKey}) =>
      guardApi(() async {
        final r = await _dio.post(
          '/animals',
          data: {'barcode': barcode, if (visitId != null) 'visitId': visitId},
          options: _idem(idempotencyKey),
        );
        return Animal.fromJson(r.data as Map<String, dynamic>);
      });

  // --- notes ---
  Future<Page<Note>> notes(int animalId, {String? cursor, int limit = 50}) =>
      guardApi(() async {
        final r = await _dio.get('/animals/$animalId/notes', queryParameters: {
          'limit': limit,
          if (cursor != null) 'cursor': cursor,
        });
        return Page.fromJson(r.data as Map<String, dynamic>, Note.fromJson);
      });

  Future<Note> createNote(int animalId, String body, {int? visitId, String? idempotencyKey}) =>
      guardApi(() async {
        final r = await _dio.post(
          '/animals/$animalId/notes',
          data: {'body': body, if (visitId != null) 'visitId': visitId},
          options: _idem(idempotencyKey),
        );
        return Note.fromJson(r.data as Map<String, dynamic>);
      });

  // --- visits ---
  Future<Page<Visit>> visits({String? status, String? cursor}) => guardApi(() async {
        final r = await _dio.get('/visits', queryParameters: {
          if (status != null) 'status': status,
          if (cursor != null) 'cursor': cursor,
        });
        return Page.fromJson(r.data as Map<String, dynamic>, Visit.fromJson);
      });

  Future<Visit> openVisit({String? vetPhone, required String locationType, String? locationLabel}) =>
      guardApi(() async {
        final r = await _dio.post('/visits', data: {
          if (vetPhone != null) 'vetPhone': vetPhone,
          'locationType': locationType,
          if (locationLabel != null) 'locationLabel': locationLabel,
        });
        return Visit.fromJson(r.data as Map<String, dynamic>);
      });

  Future<Visit> closeVisit(int id) => guardApi(() async {
        final r = await _dio.post('/visits/$id/close');
        return Visit.fromJson(r.data as Map<String, dynamic>);
      });

  Future<Page<Animal>> visitAnimals(int visitId, {String? cursor}) => guardApi(() async {
        final r = await _dio.get('/visits/$visitId/animals', queryParameters: {
          if (cursor != null) 'cursor': cursor,
        });
        return Page.fromJson(r.data as Map<String, dynamic>, Animal.fromJson);
      });

  // --- billing ---
  Future<BillingStatus> billingStatus() => guardApi(() async {
        final r = await _dio.get('/billing/status');
        return BillingStatus.fromJson(r.data as Map<String, dynamic>);
      });

  Future<PlansResponse> billingPlans() => guardApi(() async {
        final r = await _dio.get('/billing/plans');
        return PlansResponse.fromJson(r.data as Map<String, dynamic>);
      });

  Future<void> submitPayment({
    required String plan,
    required String instapayRef,
    required double amountEgp,
    String? screenshotUrl,
    String? idempotencyKey,
  }) =>
      guardApi(() => _dio.post(
            '/billing/payments',
            data: {
              'plan': plan,
              'instapayRef': instapayRef,
              'amountEgp': amountEgp,
              if (screenshotUrl != null) 'screenshotUrl': screenshotUrl,
            },
            options: _idem(idempotencyKey),
          ));

  Options? _idem(String? key) =>
      key == null ? null : Options(headers: {'Idempotency-Key': key});
}
