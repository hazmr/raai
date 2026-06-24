// Plain DTOs mirroring the backend's camelCase JSON (farm-tenant model).

class AuthTokens {
  AuthTokens({required this.accessToken, required this.refreshToken});
  final String accessToken;
  final String refreshToken;

  factory AuthTokens.fromJson(Map<String, dynamic> j) => AuthTokens(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
      );
}

class Farm {
  Farm({required this.id, required this.name});
  final int id;
  final String name;

  factory Farm.fromJson(Map<String, dynamic> j) =>
      Farm(id: j['id'] as int, name: j['name'] as String? ?? '');
}

class User {
  User({
    required this.id,
    required this.phoneNumber,
    required this.isAdmin,
    required this.farm,
    required this.farmRole,
  });
  final int id;
  final String phoneNumber;
  final bool isAdmin; // app super-admin
  final Farm farm;
  final String farmRole; // admin | farmer

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as int,
        phoneNumber: j['phoneNumber'] as String,
        isAdmin: j['isAdmin'] as bool? ?? false,
        farm: Farm.fromJson((j['farm'] as Map<String, dynamic>?) ?? const {'id': 0}),
        farmRole: j['farmRole'] as String? ?? 'farmer',
      );
}

/// What a doctor gets back from redeeming an invite QR.
class DoctorSession {
  DoctorSession({
    required this.accessToken,
    required this.farm,
    required this.doctorLabel,
  });
  final String accessToken;
  final Farm farm;
  final String doctorLabel;

  factory DoctorSession.fromJson(Map<String, dynamic> j) => DoctorSession(
        accessToken: j['accessToken'] as String,
        farm: Farm.fromJson((j['farm'] as Map<String, dynamic>?) ?? const {'id': 0}),
        doctorLabel: j['doctorLabel'] as String? ?? '',
      );
}

class Page<T> {
  Page({required this.data, this.nextCursor});
  final List<T> data;
  final String? nextCursor;

  factory Page.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) item) => Page(
        data: ((j['data'] as List?) ?? const [])
            .map((e) => item(e as Map<String, dynamic>))
            .toList(),
        nextCursor: j['nextCursor'] as String?,
      );
}

class Animal {
  Animal({required this.id, required this.barcode, required this.noteCount});
  final int id;
  final String barcode;
  final int noteCount;

  factory Animal.fromJson(Map<String, dynamic> j) => Animal(
        id: j['id'] as int,
        barcode: j['barcode'] as String,
        noteCount: (j['noteCount'] as int?) ?? 0,
      );
}

class Note {
  Note({
    required this.id,
    required this.animalId,
    required this.body,
    required this.authorKind,
    required this.authorLabel,
    required this.createdAt,
  });
  final int id;
  final int animalId;
  final String body;
  final String authorKind; // member | doctor
  final String authorLabel; // display name stamped at write time
  final DateTime createdAt;

  bool get isDoctor => authorKind == 'doctor';

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as int,
        animalId: j['animalId'] as int,
        body: j['body'] as String,
        authorKind: j['authorKind'] as String? ?? 'member',
        authorLabel: j['authorLabel'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// A farm member (farmer or admin).
class Member {
  Member({
    required this.userId,
    required this.phoneNumber,
    required this.role,
  });
  final int userId;
  final String phoneNumber;
  final String role; // admin | farmer

  factory Member.fromJson(Map<String, dynamic> j) => Member(
        userId: j['userId'] as int,
        phoneNumber: j['phoneNumber'] as String,
        role: j['role'] as String? ?? 'farmer',
      );
}

/// A temporary doctor invite in the farm's history.
class Invite {
  Invite({
    required this.id,
    required this.doctorLabel,
    required this.status,
    required this.noteCount,
    required this.createdAt,
    this.token,
    this.endedAt,
  });
  final int id;
  final String doctorLabel;
  final String status; // active | ended
  final int noteCount;
  final DateTime createdAt;
  final String? token; // the QR secret (present on create)
  final DateTime? endedAt;

  bool get isActive => status == 'active';

  factory Invite.fromJson(Map<String, dynamic> j) => Invite(
        id: j['id'] as int,
        doctorLabel: j['doctorLabel'] as String? ?? '',
        status: j['status'] as String? ?? 'active',
        noteCount: (j['noteCount'] as int?) ?? 0,
        createdAt: DateTime.parse(j['createdAt'] as String),
        token: j['token'] as String?,
        endedAt: j['endedAt'] == null ? null : DateTime.parse(j['endedAt'] as String),
      );
}

class BillingStatus {
  BillingStatus({required this.status, this.plan, this.currentPeriodEnd});
  final String status; // none | pending | active | expired
  final String? plan;
  final DateTime? currentPeriodEnd;

  bool get isActive => status == 'active';

  factory BillingStatus.fromJson(Map<String, dynamic> j) => BillingStatus(
        status: j['status'] as String,
        plan: j['plan'] as String?,
        currentPeriodEnd: j['currentPeriodEnd'] == null
            ? null
            : DateTime.parse(j['currentPeriodEnd'] as String),
      );
}

class Plan {
  Plan({required this.id, required this.amountEgp});
  final String id; // monthly | yearly
  final int amountEgp;

  factory Plan.fromJson(Map<String, dynamic> j) =>
      Plan(id: j['id'] as String, amountEgp: j['amountEgp'] as int);
}

class PlansResponse {
  PlansResponse({
    required this.plans,
    required this.instapayIpa,
    required this.displayName,
    required this.currency,
  });
  final List<Plan> plans;
  final String instapayIpa;
  final String displayName;
  final String currency;

  factory PlansResponse.fromJson(Map<String, dynamic> j) => PlansResponse(
        plans: ((j['plans'] as List?) ?? const [])
            .map((e) => Plan.fromJson(e as Map<String, dynamic>))
            .toList(),
        instapayIpa: j['instapayIpa'] as String? ?? '',
        displayName: j['displayName'] as String? ?? '',
        currency: j['currency'] as String? ?? 'EGP',
      );
}
