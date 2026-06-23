// Plain DTOs mirroring the backend's camelCase JSON (SYSTEM_DESIGN.md §6).

class AuthTokens {
  AuthTokens({required this.accessToken, required this.refreshToken});
  final String accessToken;
  final String refreshToken;

  factory AuthTokens.fromJson(Map<String, dynamic> j) => AuthTokens(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
      );
}

class User {
  User({
    required this.id,
    required this.phoneNumber,
    required this.role,
    required this.isAdmin,
  });
  final int id;
  final String phoneNumber;
  final String role; // farmer | vet
  final bool isAdmin;

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as int,
        phoneNumber: j['phoneNumber'] as String,
        role: j['role'] as String? ?? 'farmer',
        isAdmin: j['isAdmin'] as bool? ?? false,
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
  Animal({
    required this.id,
    required this.barcode,
    required this.noteCount,
  });
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
    required this.authorRole,
    required this.createdAt,
    this.visitId,
  });
  final int id;
  final int animalId;
  final String body;
  final String authorRole; // farmer | vet
  final DateTime createdAt;
  final int? visitId;

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as int,
        animalId: j['animalId'] as int,
        body: j['body'] as String,
        authorRole: j['authorRole'] as String? ?? 'farmer',
        createdAt: DateTime.parse(j['createdAt'] as String),
        visitId: j['visitId'] as int?,
      );
}

class Visit {
  Visit({
    required this.id,
    required this.locationType,
    required this.status,
    required this.openedAt,
    this.vetId,
    this.locationLabel,
  });
  final int id;
  final String locationType; // clinic | farm
  final String status; // open | closed
  final DateTime openedAt;
  final int? vetId;
  final String? locationLabel;

  factory Visit.fromJson(Map<String, dynamic> j) => Visit(
        id: j['id'] as int,
        locationType: j['locationType'] as String,
        status: j['status'] as String,
        openedAt: DateTime.parse(j['openedAt'] as String),
        vetId: j['vetId'] as int?,
        locationLabel: j['locationLabel'] as String?,
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
