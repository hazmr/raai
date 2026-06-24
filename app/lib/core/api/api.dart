import 'package:dio/dio.dart';

import 'dio_client.dart';
import 'models.dart';

/// Thin typed wrappers over /api/v1. Every method runs through [guardApi] so
/// failures surface as the single ApiException (§6.1).
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

  // Registration creates a farm with the user as its admin.
  Future<AuthTokens> register(String phone, String password, String farmName) =>
      guardApi(() async {
        final r = await _dio.post('/auth/register', data: {
          'phoneNumber': phone,
          'password': password,
          'farmName': farmName,
        });
        return AuthTokens.fromJson(r.data as Map<String, dynamic>);
      });

  Future<void> logout() => guardApi(() => _dio.post('/auth/logout'));

  Future<User> me() => guardApi(() async {
        final r = await _dio.get('/me');
        return User.fromJson(r.data as Map<String, dynamic>);
      });

  // Doctor redeems a QR invite secret for a (re-issuable) session.
  Future<DoctorSession> redeemDoctor(String token) => guardApi(() async {
        final r = await _dio.post('/doctor/redeem', data: {'token': token});
        return DoctorSession.fromJson(r.data as Map<String, dynamic>);
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

  Future<Animal> animal(int id) => guardApi(() async {
        final r = await _dio.get('/animals/$id');
        return Animal.fromJson(r.data as Map<String, dynamic>);
      });

  Future<Animal> createAnimal(String barcode, {String? idempotencyKey}) =>
      guardApi(() async {
        final r = await _dio.post('/animals',
            data: {'barcode': barcode}, options: _idem(idempotencyKey));
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

  // Author (member vs doctor) is set server-side from the token.
  Future<Note> createNote(int animalId, String body, {String? idempotencyKey}) =>
      guardApi(() async {
        final r = await _dio.post('/animals/$animalId/notes',
            data: {'body': body}, options: _idem(idempotencyKey));
        return Note.fromJson(r.data as Map<String, dynamic>);
      });

  // --- farm members (admin) ---
  Future<List<Member>> members() => guardApi(() async {
        final r = await _dio.get('/farm/members');
        final data = (r.data as Map<String, dynamic>)['data'] as List? ?? const [];
        return data.map((e) => Member.fromJson(e as Map<String, dynamic>)).toList();
      });

  Future<Member> addMember(String phone, String password) => guardApi(() async {
        final r = await _dio.post('/farm/members',
            data: {'phoneNumber': phone, 'password': password});
        return Member.fromJson(r.data as Map<String, dynamic>);
      });

  Future<void> removeMember(int userId) =>
      guardApi(() => _dio.delete('/farm/members/$userId'));

  // --- doctor invites (admin) ---
  Future<List<Invite>> invites() => guardApi(() async {
        final r = await _dio.get('/invites');
        final data = (r.data as Map<String, dynamic>)['data'] as List? ?? const [];
        return data.map((e) => Invite.fromJson(e as Map<String, dynamic>)).toList();
      });

  Future<Invite> createInvite(String doctorLabel, {DateTime? expiresAt}) =>
      guardApi(() async {
        final r = await _dio.post('/invites', data: {
          'doctorLabel': doctorLabel,
          if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
        });
        return Invite.fromJson(r.data as Map<String, dynamic>);
      });

  Future<Invite> endInvite(int id) => guardApi(() async {
        final r = await _dio.post('/invites/$id/end');
        return Invite.fromJson(r.data as Map<String, dynamic>);
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
