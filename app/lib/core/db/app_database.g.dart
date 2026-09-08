// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedAnimalsTable extends CachedAnimals
    with TableInfo<$CachedAnimalsTable, CachedAnimal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedAnimalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta =
      const VerificationMeta('localId');
  @override
  late final GeneratedColumn<int> localId = GeneratedColumn<int>(
      'local_id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _serverIdMeta =
      const VerificationMeta('serverId');
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
      'server_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _barcodeMeta =
      const VerificationMeta('barcode');
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
      'barcode', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _noteCountMeta =
      const VerificationMeta('noteCount');
  @override
  late final GeneratedColumn<int> noteCount = GeneratedColumn<int>(
      'note_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _pendingMeta =
      const VerificationMeta('pending');
  @override
  late final GeneratedColumn<bool> pending = GeneratedColumn<bool>(
      'pending', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("pending" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [localId, serverId, barcode, noteCount, createdAt, pending];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_animals';
  @override
  VerificationContext validateIntegrity(Insertable<CachedAnimal> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(_localIdMeta,
          localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta));
    }
    if (data.containsKey('server_id')) {
      context.handle(_serverIdMeta,
          serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta));
    }
    if (data.containsKey('barcode')) {
      context.handle(_barcodeMeta,
          barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta));
    } else if (isInserting) {
      context.missing(_barcodeMeta);
    }
    if (data.containsKey('note_count')) {
      context.handle(_noteCountMeta,
          noteCount.isAcceptableOrUnknown(data['note_count']!, _noteCountMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('pending')) {
      context.handle(_pendingMeta,
          pending.isAcceptableOrUnknown(data['pending']!, _pendingMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {barcode},
      ];
  @override
  CachedAnimal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedAnimal(
      localId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}local_id'])!,
      serverId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}server_id']),
      barcode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}barcode'])!,
      noteCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}note_count'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      pending: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}pending'])!,
    );
  }

  @override
  $CachedAnimalsTable createAlias(String alias) {
    return $CachedAnimalsTable(attachedDatabase, alias);
  }
}

class CachedAnimal extends DataClass implements Insertable<CachedAnimal> {
  final int localId;
  final int? serverId;
  final String barcode;
  final int noteCount;
  final DateTime createdAt;

  /// True while this animal has not reached the server yet.
  final bool pending;
  const CachedAnimal(
      {required this.localId,
      this.serverId,
      required this.barcode,
      required this.noteCount,
      required this.createdAt,
      required this.pending});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<int>(localId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['barcode'] = Variable<String>(barcode);
    map['note_count'] = Variable<int>(noteCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['pending'] = Variable<bool>(pending);
    return map;
  }

  CachedAnimalsCompanion toCompanion(bool nullToAbsent) {
    return CachedAnimalsCompanion(
      localId: Value(localId),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      barcode: Value(barcode),
      noteCount: Value(noteCount),
      createdAt: Value(createdAt),
      pending: Value(pending),
    );
  }

  factory CachedAnimal.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedAnimal(
      localId: serializer.fromJson<int>(json['localId']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      barcode: serializer.fromJson<String>(json['barcode']),
      noteCount: serializer.fromJson<int>(json['noteCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      pending: serializer.fromJson<bool>(json['pending']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<int>(localId),
      'serverId': serializer.toJson<int?>(serverId),
      'barcode': serializer.toJson<String>(barcode),
      'noteCount': serializer.toJson<int>(noteCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'pending': serializer.toJson<bool>(pending),
    };
  }

  CachedAnimal copyWith(
          {int? localId,
          Value<int?> serverId = const Value.absent(),
          String? barcode,
          int? noteCount,
          DateTime? createdAt,
          bool? pending}) =>
      CachedAnimal(
        localId: localId ?? this.localId,
        serverId: serverId.present ? serverId.value : this.serverId,
        barcode: barcode ?? this.barcode,
        noteCount: noteCount ?? this.noteCount,
        createdAt: createdAt ?? this.createdAt,
        pending: pending ?? this.pending,
      );
  CachedAnimal copyWithCompanion(CachedAnimalsCompanion data) {
    return CachedAnimal(
      localId: data.localId.present ? data.localId.value : this.localId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      noteCount: data.noteCount.present ? data.noteCount.value : this.noteCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      pending: data.pending.present ? data.pending.value : this.pending,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedAnimal(')
          ..write('localId: $localId, ')
          ..write('serverId: $serverId, ')
          ..write('barcode: $barcode, ')
          ..write('noteCount: $noteCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('pending: $pending')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(localId, serverId, barcode, noteCount, createdAt, pending);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedAnimal &&
          other.localId == this.localId &&
          other.serverId == this.serverId &&
          other.barcode == this.barcode &&
          other.noteCount == this.noteCount &&
          other.createdAt == this.createdAt &&
          other.pending == this.pending);
}

class CachedAnimalsCompanion extends UpdateCompanion<CachedAnimal> {
  final Value<int> localId;
  final Value<int?> serverId;
  final Value<String> barcode;
  final Value<int> noteCount;
  final Value<DateTime> createdAt;
  final Value<bool> pending;
  const CachedAnimalsCompanion({
    this.localId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.barcode = const Value.absent(),
    this.noteCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.pending = const Value.absent(),
  });
  CachedAnimalsCompanion.insert({
    this.localId = const Value.absent(),
    this.serverId = const Value.absent(),
    required String barcode,
    this.noteCount = const Value.absent(),
    required DateTime createdAt,
    this.pending = const Value.absent(),
  })  : barcode = Value(barcode),
        createdAt = Value(createdAt);
  static Insertable<CachedAnimal> custom({
    Expression<int>? localId,
    Expression<int>? serverId,
    Expression<String>? barcode,
    Expression<int>? noteCount,
    Expression<DateTime>? createdAt,
    Expression<bool>? pending,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (serverId != null) 'server_id': serverId,
      if (barcode != null) 'barcode': barcode,
      if (noteCount != null) 'note_count': noteCount,
      if (createdAt != null) 'created_at': createdAt,
      if (pending != null) 'pending': pending,
    });
  }

  CachedAnimalsCompanion copyWith(
      {Value<int>? localId,
      Value<int?>? serverId,
      Value<String>? barcode,
      Value<int>? noteCount,
      Value<DateTime>? createdAt,
      Value<bool>? pending}) {
    return CachedAnimalsCompanion(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      barcode: barcode ?? this.barcode,
      noteCount: noteCount ?? this.noteCount,
      createdAt: createdAt ?? this.createdAt,
      pending: pending ?? this.pending,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<int>(localId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (noteCount.present) {
      map['note_count'] = Variable<int>(noteCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (pending.present) {
      map['pending'] = Variable<bool>(pending.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedAnimalsCompanion(')
          ..write('localId: $localId, ')
          ..write('serverId: $serverId, ')
          ..write('barcode: $barcode, ')
          ..write('noteCount: $noteCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('pending: $pending')
          ..write(')'))
        .toString();
  }
}

class $CachedNotesTable extends CachedNotes
    with TableInfo<$CachedNotesTable, CachedNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta =
      const VerificationMeta('localId');
  @override
  late final GeneratedColumn<int> localId = GeneratedColumn<int>(
      'local_id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _serverIdMeta =
      const VerificationMeta('serverId');
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
      'server_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _animalLocalIdMeta =
      const VerificationMeta('animalLocalId');
  @override
  late final GeneratedColumn<int> animalLocalId = GeneratedColumn<int>(
      'animal_local_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES cached_animals (local_id) ON DELETE CASCADE'));
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _authorKindMeta =
      const VerificationMeta('authorKind');
  @override
  late final GeneratedColumn<String> authorKind = GeneratedColumn<String>(
      'author_kind', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('member'));
  static const VerificationMeta _authorLabelMeta =
      const VerificationMeta('authorLabel');
  @override
  late final GeneratedColumn<String> authorLabel = GeneratedColumn<String>(
      'author_label', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _pendingMeta =
      const VerificationMeta('pending');
  @override
  late final GeneratedColumn<bool> pending = GeneratedColumn<bool>(
      'pending', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("pending" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        localId,
        serverId,
        animalLocalId,
        body,
        authorKind,
        authorLabel,
        createdAt,
        pending
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_notes';
  @override
  VerificationContext validateIntegrity(Insertable<CachedNote> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(_localIdMeta,
          localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta));
    }
    if (data.containsKey('server_id')) {
      context.handle(_serverIdMeta,
          serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta));
    }
    if (data.containsKey('animal_local_id')) {
      context.handle(
          _animalLocalIdMeta,
          animalLocalId.isAcceptableOrUnknown(
              data['animal_local_id']!, _animalLocalIdMeta));
    } else if (isInserting) {
      context.missing(_animalLocalIdMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('author_kind')) {
      context.handle(
          _authorKindMeta,
          authorKind.isAcceptableOrUnknown(
              data['author_kind']!, _authorKindMeta));
    }
    if (data.containsKey('author_label')) {
      context.handle(
          _authorLabelMeta,
          authorLabel.isAcceptableOrUnknown(
              data['author_label']!, _authorLabelMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('pending')) {
      context.handle(_pendingMeta,
          pending.isAcceptableOrUnknown(data['pending']!, _pendingMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  CachedNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedNote(
      localId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}local_id'])!,
      serverId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}server_id']),
      animalLocalId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}animal_local_id'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      authorKind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author_kind'])!,
      authorLabel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author_label'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      pending: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}pending'])!,
    );
  }

  @override
  $CachedNotesTable createAlias(String alias) {
    return $CachedNotesTable(attachedDatabase, alias);
  }
}

class CachedNote extends DataClass implements Insertable<CachedNote> {
  final int localId;
  final int? serverId;
  final int animalLocalId;
  final String body;
  final String authorKind;
  final String authorLabel;
  final DateTime createdAt;
  final bool pending;
  const CachedNote(
      {required this.localId,
      this.serverId,
      required this.animalLocalId,
      required this.body,
      required this.authorKind,
      required this.authorLabel,
      required this.createdAt,
      required this.pending});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<int>(localId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['animal_local_id'] = Variable<int>(animalLocalId);
    map['body'] = Variable<String>(body);
    map['author_kind'] = Variable<String>(authorKind);
    map['author_label'] = Variable<String>(authorLabel);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['pending'] = Variable<bool>(pending);
    return map;
  }

  CachedNotesCompanion toCompanion(bool nullToAbsent) {
    return CachedNotesCompanion(
      localId: Value(localId),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      animalLocalId: Value(animalLocalId),
      body: Value(body),
      authorKind: Value(authorKind),
      authorLabel: Value(authorLabel),
      createdAt: Value(createdAt),
      pending: Value(pending),
    );
  }

  factory CachedNote.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedNote(
      localId: serializer.fromJson<int>(json['localId']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      animalLocalId: serializer.fromJson<int>(json['animalLocalId']),
      body: serializer.fromJson<String>(json['body']),
      authorKind: serializer.fromJson<String>(json['authorKind']),
      authorLabel: serializer.fromJson<String>(json['authorLabel']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      pending: serializer.fromJson<bool>(json['pending']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<int>(localId),
      'serverId': serializer.toJson<int?>(serverId),
      'animalLocalId': serializer.toJson<int>(animalLocalId),
      'body': serializer.toJson<String>(body),
      'authorKind': serializer.toJson<String>(authorKind),
      'authorLabel': serializer.toJson<String>(authorLabel),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'pending': serializer.toJson<bool>(pending),
    };
  }

  CachedNote copyWith(
          {int? localId,
          Value<int?> serverId = const Value.absent(),
          int? animalLocalId,
          String? body,
          String? authorKind,
          String? authorLabel,
          DateTime? createdAt,
          bool? pending}) =>
      CachedNote(
        localId: localId ?? this.localId,
        serverId: serverId.present ? serverId.value : this.serverId,
        animalLocalId: animalLocalId ?? this.animalLocalId,
        body: body ?? this.body,
        authorKind: authorKind ?? this.authorKind,
        authorLabel: authorLabel ?? this.authorLabel,
        createdAt: createdAt ?? this.createdAt,
        pending: pending ?? this.pending,
      );
  CachedNote copyWithCompanion(CachedNotesCompanion data) {
    return CachedNote(
      localId: data.localId.present ? data.localId.value : this.localId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      animalLocalId: data.animalLocalId.present
          ? data.animalLocalId.value
          : this.animalLocalId,
      body: data.body.present ? data.body.value : this.body,
      authorKind:
          data.authorKind.present ? data.authorKind.value : this.authorKind,
      authorLabel:
          data.authorLabel.present ? data.authorLabel.value : this.authorLabel,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      pending: data.pending.present ? data.pending.value : this.pending,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedNote(')
          ..write('localId: $localId, ')
          ..write('serverId: $serverId, ')
          ..write('animalLocalId: $animalLocalId, ')
          ..write('body: $body, ')
          ..write('authorKind: $authorKind, ')
          ..write('authorLabel: $authorLabel, ')
          ..write('createdAt: $createdAt, ')
          ..write('pending: $pending')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(localId, serverId, animalLocalId, body,
      authorKind, authorLabel, createdAt, pending);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedNote &&
          other.localId == this.localId &&
          other.serverId == this.serverId &&
          other.animalLocalId == this.animalLocalId &&
          other.body == this.body &&
          other.authorKind == this.authorKind &&
          other.authorLabel == this.authorLabel &&
          other.createdAt == this.createdAt &&
          other.pending == this.pending);
}

class CachedNotesCompanion extends UpdateCompanion<CachedNote> {
  final Value<int> localId;
  final Value<int?> serverId;
  final Value<int> animalLocalId;
  final Value<String> body;
  final Value<String> authorKind;
  final Value<String> authorLabel;
  final Value<DateTime> createdAt;
  final Value<bool> pending;
  const CachedNotesCompanion({
    this.localId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.animalLocalId = const Value.absent(),
    this.body = const Value.absent(),
    this.authorKind = const Value.absent(),
    this.authorLabel = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.pending = const Value.absent(),
  });
  CachedNotesCompanion.insert({
    this.localId = const Value.absent(),
    this.serverId = const Value.absent(),
    required int animalLocalId,
    required String body,
    this.authorKind = const Value.absent(),
    this.authorLabel = const Value.absent(),
    required DateTime createdAt,
    this.pending = const Value.absent(),
  })  : animalLocalId = Value(animalLocalId),
        body = Value(body),
        createdAt = Value(createdAt);
  static Insertable<CachedNote> custom({
    Expression<int>? localId,
    Expression<int>? serverId,
    Expression<int>? animalLocalId,
    Expression<String>? body,
    Expression<String>? authorKind,
    Expression<String>? authorLabel,
    Expression<DateTime>? createdAt,
    Expression<bool>? pending,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (serverId != null) 'server_id': serverId,
      if (animalLocalId != null) 'animal_local_id': animalLocalId,
      if (body != null) 'body': body,
      if (authorKind != null) 'author_kind': authorKind,
      if (authorLabel != null) 'author_label': authorLabel,
      if (createdAt != null) 'created_at': createdAt,
      if (pending != null) 'pending': pending,
    });
  }

  CachedNotesCompanion copyWith(
      {Value<int>? localId,
      Value<int?>? serverId,
      Value<int>? animalLocalId,
      Value<String>? body,
      Value<String>? authorKind,
      Value<String>? authorLabel,
      Value<DateTime>? createdAt,
      Value<bool>? pending}) {
    return CachedNotesCompanion(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      animalLocalId: animalLocalId ?? this.animalLocalId,
      body: body ?? this.body,
      authorKind: authorKind ?? this.authorKind,
      authorLabel: authorLabel ?? this.authorLabel,
      createdAt: createdAt ?? this.createdAt,
      pending: pending ?? this.pending,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<int>(localId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (animalLocalId.present) {
      map['animal_local_id'] = Variable<int>(animalLocalId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (authorKind.present) {
      map['author_kind'] = Variable<String>(authorKind.value);
    }
    if (authorLabel.present) {
      map['author_label'] = Variable<String>(authorLabel.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (pending.present) {
      map['pending'] = Variable<bool>(pending.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedNotesCompanion(')
          ..write('localId: $localId, ')
          ..write('serverId: $serverId, ')
          ..write('animalLocalId: $animalLocalId, ')
          ..write('body: $body, ')
          ..write('authorKind: $authorKind, ')
          ..write('authorLabel: $authorLabel, ')
          ..write('createdAt: $createdAt, ')
          ..write('pending: $pending')
          ..write(')'))
        .toString();
  }
}

class $OutboxEntriesTable extends OutboxEntries
    with TableInfo<$OutboxEntriesTable, OutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _idempotencyKeyMeta =
      const VerificationMeta('idempotencyKey');
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
      'idempotency_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _targetLocalIdMeta =
      const VerificationMeta('targetLocalId');
  @override
  late final GeneratedColumn<int> targetLocalId = GeneratedColumn<int>(
      'target_local_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _animalLocalIdMeta =
      const VerificationMeta('animalLocalId');
  @override
  late final GeneratedColumn<int> animalLocalId = GeneratedColumn<int>(
      'animal_local_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _failedMeta = const VerificationMeta('failed');
  @override
  late final GeneratedColumn<bool> failed = GeneratedColumn<bool>(
      'failed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("failed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        kind,
        idempotencyKey,
        targetLocalId,
        animalLocalId,
        payload,
        attempts,
        lastError,
        failed,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_entries';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
          _idempotencyKeyMeta,
          idempotencyKey.isAcceptableOrUnknown(
              data['idempotency_key']!, _idempotencyKeyMeta));
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('target_local_id')) {
      context.handle(
          _targetLocalIdMeta,
          targetLocalId.isAcceptableOrUnknown(
              data['target_local_id']!, _targetLocalIdMeta));
    } else if (isInserting) {
      context.missing(_targetLocalIdMeta);
    }
    if (data.containsKey('animal_local_id')) {
      context.handle(
          _animalLocalIdMeta,
          animalLocalId.isAcceptableOrUnknown(
              data['animal_local_id']!, _animalLocalIdMeta));
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('failed')) {
      context.handle(_failedMeta,
          failed.isAcceptableOrUnknown(data['failed']!, _failedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      idempotencyKey: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}idempotency_key'])!,
      targetLocalId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}target_local_id'])!,
      animalLocalId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}animal_local_id']),
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      failed: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}failed'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $OutboxEntriesTable createAlias(String alias) {
    return $OutboxEntriesTable(attachedDatabase, alias);
  }
}

class OutboxEntry extends DataClass implements Insertable<OutboxEntry> {
  final int id;

  /// [OutboxKind] name: what to replay.
  final String kind;

  /// Sent as the `Idempotency-Key` header; stable across retries.
  final String idempotencyKey;

  /// The local row this entry creates (an animal or a note).
  final int targetLocalId;

  /// For a note: the animal it belongs to, so the sync can wait for that
  /// animal's server id before sending.
  final int? animalLocalId;
  final String payload;
  final int attempts;
  final String? lastError;

  /// Set when the server rejected the write for a reason a retry won't fix; the
  /// entry stops blocking the queue and is surfaced to the user instead.
  final bool failed;
  final DateTime createdAt;
  const OutboxEntry(
      {required this.id,
      required this.kind,
      required this.idempotencyKey,
      required this.targetLocalId,
      this.animalLocalId,
      required this.payload,
      required this.attempts,
      this.lastError,
      required this.failed,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['target_local_id'] = Variable<int>(targetLocalId);
    if (!nullToAbsent || animalLocalId != null) {
      map['animal_local_id'] = Variable<int>(animalLocalId);
    }
    map['payload'] = Variable<String>(payload);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['failed'] = Variable<bool>(failed);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OutboxEntriesCompanion toCompanion(bool nullToAbsent) {
    return OutboxEntriesCompanion(
      id: Value(id),
      kind: Value(kind),
      idempotencyKey: Value(idempotencyKey),
      targetLocalId: Value(targetLocalId),
      animalLocalId: animalLocalId == null && nullToAbsent
          ? const Value.absent()
          : Value(animalLocalId),
      payload: Value(payload),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      failed: Value(failed),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEntry(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      targetLocalId: serializer.fromJson<int>(json['targetLocalId']),
      animalLocalId: serializer.fromJson<int?>(json['animalLocalId']),
      payload: serializer.fromJson<String>(json['payload']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      failed: serializer.fromJson<bool>(json['failed']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'targetLocalId': serializer.toJson<int>(targetLocalId),
      'animalLocalId': serializer.toJson<int?>(animalLocalId),
      'payload': serializer.toJson<String>(payload),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'failed': serializer.toJson<bool>(failed),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutboxEntry copyWith(
          {int? id,
          String? kind,
          String? idempotencyKey,
          int? targetLocalId,
          Value<int?> animalLocalId = const Value.absent(),
          String? payload,
          int? attempts,
          Value<String?> lastError = const Value.absent(),
          bool? failed,
          DateTime? createdAt}) =>
      OutboxEntry(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        idempotencyKey: idempotencyKey ?? this.idempotencyKey,
        targetLocalId: targetLocalId ?? this.targetLocalId,
        animalLocalId:
            animalLocalId.present ? animalLocalId.value : this.animalLocalId,
        payload: payload ?? this.payload,
        attempts: attempts ?? this.attempts,
        lastError: lastError.present ? lastError.value : this.lastError,
        failed: failed ?? this.failed,
        createdAt: createdAt ?? this.createdAt,
      );
  OutboxEntry copyWithCompanion(OutboxEntriesCompanion data) {
    return OutboxEntry(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      targetLocalId: data.targetLocalId.present
          ? data.targetLocalId.value
          : this.targetLocalId,
      animalLocalId: data.animalLocalId.present
          ? data.animalLocalId.value
          : this.animalLocalId,
      payload: data.payload.present ? data.payload.value : this.payload,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      failed: data.failed.present ? data.failed.value : this.failed,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntry(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('targetLocalId: $targetLocalId, ')
          ..write('animalLocalId: $animalLocalId, ')
          ..write('payload: $payload, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('failed: $failed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, idempotencyKey, targetLocalId,
      animalLocalId, payload, attempts, lastError, failed, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEntry &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.idempotencyKey == this.idempotencyKey &&
          other.targetLocalId == this.targetLocalId &&
          other.animalLocalId == this.animalLocalId &&
          other.payload == this.payload &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.failed == this.failed &&
          other.createdAt == this.createdAt);
}

class OutboxEntriesCompanion extends UpdateCompanion<OutboxEntry> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String> idempotencyKey;
  final Value<int> targetLocalId;
  final Value<int?> animalLocalId;
  final Value<String> payload;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<bool> failed;
  final Value<DateTime> createdAt;
  const OutboxEntriesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.targetLocalId = const Value.absent(),
    this.animalLocalId = const Value.absent(),
    this.payload = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.failed = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  OutboxEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    required String idempotencyKey,
    required int targetLocalId,
    this.animalLocalId = const Value.absent(),
    required String payload,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.failed = const Value.absent(),
    required DateTime createdAt,
  })  : kind = Value(kind),
        idempotencyKey = Value(idempotencyKey),
        targetLocalId = Value(targetLocalId),
        payload = Value(payload),
        createdAt = Value(createdAt);
  static Insertable<OutboxEntry> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? idempotencyKey,
    Expression<int>? targetLocalId,
    Expression<int>? animalLocalId,
    Expression<String>? payload,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<bool>? failed,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (targetLocalId != null) 'target_local_id': targetLocalId,
      if (animalLocalId != null) 'animal_local_id': animalLocalId,
      if (payload != null) 'payload': payload,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (failed != null) 'failed': failed,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OutboxEntriesCompanion copyWith(
      {Value<int>? id,
      Value<String>? kind,
      Value<String>? idempotencyKey,
      Value<int>? targetLocalId,
      Value<int?>? animalLocalId,
      Value<String>? payload,
      Value<int>? attempts,
      Value<String?>? lastError,
      Value<bool>? failed,
      Value<DateTime>? createdAt}) {
    return OutboxEntriesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      targetLocalId: targetLocalId ?? this.targetLocalId,
      animalLocalId: animalLocalId ?? this.animalLocalId,
      payload: payload ?? this.payload,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      failed: failed ?? this.failed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (targetLocalId.present) {
      map['target_local_id'] = Variable<int>(targetLocalId.value);
    }
    if (animalLocalId.present) {
      map['animal_local_id'] = Variable<int>(animalLocalId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (failed.present) {
      map['failed'] = Variable<bool>(failed.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntriesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('targetLocalId: $targetLocalId, ')
          ..write('animalLocalId: $animalLocalId, ')
          ..write('payload: $payload, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('failed: $failed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedAnimalsTable cachedAnimals = $CachedAnimalsTable(this);
  late final $CachedNotesTable cachedNotes = $CachedNotesTable(this);
  late final $OutboxEntriesTable outboxEntries = $OutboxEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [cachedAnimals, cachedNotes, outboxEntries];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('cached_animals',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('cached_notes', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$CachedAnimalsTableCreateCompanionBuilder = CachedAnimalsCompanion
    Function({
  Value<int> localId,
  Value<int?> serverId,
  required String barcode,
  Value<int> noteCount,
  required DateTime createdAt,
  Value<bool> pending,
});
typedef $$CachedAnimalsTableUpdateCompanionBuilder = CachedAnimalsCompanion
    Function({
  Value<int> localId,
  Value<int?> serverId,
  Value<String> barcode,
  Value<int> noteCount,
  Value<DateTime> createdAt,
  Value<bool> pending,
});

final class $$CachedAnimalsTableReferences
    extends BaseReferences<_$AppDatabase, $CachedAnimalsTable, CachedAnimal> {
  $$CachedAnimalsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CachedNotesTable, List<CachedNote>>
      _cachedNotesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.cachedNotes,
          aliasName: 'cached_animals__local_id__cached_notes__animal_local_id');

  $$CachedNotesTableProcessedTableManager get cachedNotesRefs {
    final manager = $$CachedNotesTableTableManager($_db, $_db.cachedNotes)
        .filter((f) =>
            f.animalLocalId.localId.sqlEquals($_itemColumn<int>('local_id')!));

    final cache = $_typedResult.readTableOrNull(_cachedNotesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$CachedAnimalsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedAnimalsTable> {
  $$CachedAnimalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get localId => $composableBuilder(
      column: $table.localId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get barcode => $composableBuilder(
      column: $table.barcode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get noteCount => $composableBuilder(
      column: $table.noteCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get pending => $composableBuilder(
      column: $table.pending, builder: (column) => ColumnFilters(column));

  Expression<bool> cachedNotesRefs(
      Expression<bool> Function($$CachedNotesTableFilterComposer f) f) {
    final $$CachedNotesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.localId,
        referencedTable: $db.cachedNotes,
        getReferencedColumn: (t) => t.animalLocalId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CachedNotesTableFilterComposer(
              $db: $db,
              $table: $db.cachedNotes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CachedAnimalsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedAnimalsTable> {
  $$CachedAnimalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get localId => $composableBuilder(
      column: $table.localId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get barcode => $composableBuilder(
      column: $table.barcode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get noteCount => $composableBuilder(
      column: $table.noteCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get pending => $composableBuilder(
      column: $table.pending, builder: (column) => ColumnOrderings(column));
}

class $$CachedAnimalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedAnimalsTable> {
  $$CachedAnimalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<int> get noteCount =>
      $composableBuilder(column: $table.noteCount, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get pending =>
      $composableBuilder(column: $table.pending, builder: (column) => column);

  Expression<T> cachedNotesRefs<T extends Object>(
      Expression<T> Function($$CachedNotesTableAnnotationComposer a) f) {
    final $$CachedNotesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.localId,
        referencedTable: $db.cachedNotes,
        getReferencedColumn: (t) => t.animalLocalId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CachedNotesTableAnnotationComposer(
              $db: $db,
              $table: $db.cachedNotes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CachedAnimalsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedAnimalsTable,
    CachedAnimal,
    $$CachedAnimalsTableFilterComposer,
    $$CachedAnimalsTableOrderingComposer,
    $$CachedAnimalsTableAnnotationComposer,
    $$CachedAnimalsTableCreateCompanionBuilder,
    $$CachedAnimalsTableUpdateCompanionBuilder,
    (CachedAnimal, $$CachedAnimalsTableReferences),
    CachedAnimal,
    PrefetchHooks Function({bool cachedNotesRefs})> {
  $$CachedAnimalsTableTableManager(_$AppDatabase db, $CachedAnimalsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedAnimalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedAnimalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedAnimalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> localId = const Value.absent(),
            Value<int?> serverId = const Value.absent(),
            Value<String> barcode = const Value.absent(),
            Value<int> noteCount = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> pending = const Value.absent(),
          }) =>
              CachedAnimalsCompanion(
            localId: localId,
            serverId: serverId,
            barcode: barcode,
            noteCount: noteCount,
            createdAt: createdAt,
            pending: pending,
          ),
          createCompanionCallback: ({
            Value<int> localId = const Value.absent(),
            Value<int?> serverId = const Value.absent(),
            required String barcode,
            Value<int> noteCount = const Value.absent(),
            required DateTime createdAt,
            Value<bool> pending = const Value.absent(),
          }) =>
              CachedAnimalsCompanion.insert(
            localId: localId,
            serverId: serverId,
            barcode: barcode,
            noteCount: noteCount,
            createdAt: createdAt,
            pending: pending,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CachedAnimalsTable, CachedAnimal>(table),
                    $$CachedAnimalsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({cachedNotesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (cachedNotesRefs) db.cachedNotes],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (cachedNotesRefs)
                    await $_getPrefetchedData<CachedAnimal, $CachedAnimalsTable,
                            CachedNote>(
                        currentTable: table,
                        referencedTable: $$CachedAnimalsTableReferences
                            ._cachedNotesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CachedAnimalsTableReferences(db, table, p0)
                                .cachedNotesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.animalLocalId == item.localId),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$CachedAnimalsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedAnimalsTable,
    CachedAnimal,
    $$CachedAnimalsTableFilterComposer,
    $$CachedAnimalsTableOrderingComposer,
    $$CachedAnimalsTableAnnotationComposer,
    $$CachedAnimalsTableCreateCompanionBuilder,
    $$CachedAnimalsTableUpdateCompanionBuilder,
    (CachedAnimal, $$CachedAnimalsTableReferences),
    CachedAnimal,
    PrefetchHooks Function({bool cachedNotesRefs})>;
typedef $$CachedNotesTableCreateCompanionBuilder = CachedNotesCompanion
    Function({
  Value<int> localId,
  Value<int?> serverId,
  required int animalLocalId,
  required String body,
  Value<String> authorKind,
  Value<String> authorLabel,
  required DateTime createdAt,
  Value<bool> pending,
});
typedef $$CachedNotesTableUpdateCompanionBuilder = CachedNotesCompanion
    Function({
  Value<int> localId,
  Value<int?> serverId,
  Value<int> animalLocalId,
  Value<String> body,
  Value<String> authorKind,
  Value<String> authorLabel,
  Value<DateTime> createdAt,
  Value<bool> pending,
});

final class $$CachedNotesTableReferences
    extends BaseReferences<_$AppDatabase, $CachedNotesTable, CachedNote> {
  $$CachedNotesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CachedAnimalsTable _animalLocalIdTable(_$AppDatabase db) => db
      .cachedAnimals
      .createAlias('cached_notes__animal_local_id__cached_animals__local_id');

  $$CachedAnimalsTableProcessedTableManager get animalLocalId {
    final $_column = $_itemColumn<int>('animal_local_id')!;

    final manager = $$CachedAnimalsTableTableManager($_db, $_db.cachedAnimals)
        .filter((f) => f.localId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_animalLocalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$CachedNotesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedNotesTable> {
  $$CachedNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get localId => $composableBuilder(
      column: $table.localId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get authorKind => $composableBuilder(
      column: $table.authorKind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get authorLabel => $composableBuilder(
      column: $table.authorLabel, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get pending => $composableBuilder(
      column: $table.pending, builder: (column) => ColumnFilters(column));

  $$CachedAnimalsTableFilterComposer get animalLocalId {
    final $$CachedAnimalsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.animalLocalId,
        referencedTable: $db.cachedAnimals,
        getReferencedColumn: (t) => t.localId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CachedAnimalsTableFilterComposer(
              $db: $db,
              $table: $db.cachedAnimals,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CachedNotesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedNotesTable> {
  $$CachedNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get localId => $composableBuilder(
      column: $table.localId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get authorKind => $composableBuilder(
      column: $table.authorKind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get authorLabel => $composableBuilder(
      column: $table.authorLabel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get pending => $composableBuilder(
      column: $table.pending, builder: (column) => ColumnOrderings(column));

  $$CachedAnimalsTableOrderingComposer get animalLocalId {
    final $$CachedAnimalsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.animalLocalId,
        referencedTable: $db.cachedAnimals,
        getReferencedColumn: (t) => t.localId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CachedAnimalsTableOrderingComposer(
              $db: $db,
              $table: $db.cachedAnimals,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CachedNotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedNotesTable> {
  $$CachedNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get authorKind => $composableBuilder(
      column: $table.authorKind, builder: (column) => column);

  GeneratedColumn<String> get authorLabel => $composableBuilder(
      column: $table.authorLabel, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get pending =>
      $composableBuilder(column: $table.pending, builder: (column) => column);

  $$CachedAnimalsTableAnnotationComposer get animalLocalId {
    final $$CachedAnimalsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.animalLocalId,
        referencedTable: $db.cachedAnimals,
        getReferencedColumn: (t) => t.localId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CachedAnimalsTableAnnotationComposer(
              $db: $db,
              $table: $db.cachedAnimals,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CachedNotesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedNotesTable,
    CachedNote,
    $$CachedNotesTableFilterComposer,
    $$CachedNotesTableOrderingComposer,
    $$CachedNotesTableAnnotationComposer,
    $$CachedNotesTableCreateCompanionBuilder,
    $$CachedNotesTableUpdateCompanionBuilder,
    (CachedNote, $$CachedNotesTableReferences),
    CachedNote,
    PrefetchHooks Function({bool animalLocalId})> {
  $$CachedNotesTableTableManager(_$AppDatabase db, $CachedNotesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> localId = const Value.absent(),
            Value<int?> serverId = const Value.absent(),
            Value<int> animalLocalId = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<String> authorKind = const Value.absent(),
            Value<String> authorLabel = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> pending = const Value.absent(),
          }) =>
              CachedNotesCompanion(
            localId: localId,
            serverId: serverId,
            animalLocalId: animalLocalId,
            body: body,
            authorKind: authorKind,
            authorLabel: authorLabel,
            createdAt: createdAt,
            pending: pending,
          ),
          createCompanionCallback: ({
            Value<int> localId = const Value.absent(),
            Value<int?> serverId = const Value.absent(),
            required int animalLocalId,
            required String body,
            Value<String> authorKind = const Value.absent(),
            Value<String> authorLabel = const Value.absent(),
            required DateTime createdAt,
            Value<bool> pending = const Value.absent(),
          }) =>
              CachedNotesCompanion.insert(
            localId: localId,
            serverId: serverId,
            animalLocalId: animalLocalId,
            body: body,
            authorKind: authorKind,
            authorLabel: authorLabel,
            createdAt: createdAt,
            pending: pending,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CachedNotesTable, CachedNote>(table),
                    $$CachedNotesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({animalLocalId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (animalLocalId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.animalLocalId,
                    referencedTable:
                        $$CachedNotesTableReferences._animalLocalIdTable(db),
                    referencedColumn: $$CachedNotesTableReferences
                        ._animalLocalIdTable(db)
                        .localId,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$CachedNotesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedNotesTable,
    CachedNote,
    $$CachedNotesTableFilterComposer,
    $$CachedNotesTableOrderingComposer,
    $$CachedNotesTableAnnotationComposer,
    $$CachedNotesTableCreateCompanionBuilder,
    $$CachedNotesTableUpdateCompanionBuilder,
    (CachedNote, $$CachedNotesTableReferences),
    CachedNote,
    PrefetchHooks Function({bool animalLocalId})>;
typedef $$OutboxEntriesTableCreateCompanionBuilder = OutboxEntriesCompanion
    Function({
  Value<int> id,
  required String kind,
  required String idempotencyKey,
  required int targetLocalId,
  Value<int?> animalLocalId,
  required String payload,
  Value<int> attempts,
  Value<String?> lastError,
  Value<bool> failed,
  required DateTime createdAt,
});
typedef $$OutboxEntriesTableUpdateCompanionBuilder = OutboxEntriesCompanion
    Function({
  Value<int> id,
  Value<String> kind,
  Value<String> idempotencyKey,
  Value<int> targetLocalId,
  Value<int?> animalLocalId,
  Value<String> payload,
  Value<int> attempts,
  Value<String?> lastError,
  Value<bool> failed,
  Value<DateTime> createdAt,
});

class $$OutboxEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get targetLocalId => $composableBuilder(
      column: $table.targetLocalId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get animalLocalId => $composableBuilder(
      column: $table.animalLocalId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get failed => $composableBuilder(
      column: $table.failed, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$OutboxEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get targetLocalId => $composableBuilder(
      column: $table.targetLocalId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get animalLocalId => $composableBuilder(
      column: $table.animalLocalId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get failed => $composableBuilder(
      column: $table.failed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$OutboxEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey, builder: (column) => column);

  GeneratedColumn<int> get targetLocalId => $composableBuilder(
      column: $table.targetLocalId, builder: (column) => column);

  GeneratedColumn<int> get animalLocalId => $composableBuilder(
      column: $table.animalLocalId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<bool> get failed =>
      $composableBuilder(column: $table.failed, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OutboxEntriesTable,
    OutboxEntry,
    $$OutboxEntriesTableFilterComposer,
    $$OutboxEntriesTableOrderingComposer,
    $$OutboxEntriesTableAnnotationComposer,
    $$OutboxEntriesTableCreateCompanionBuilder,
    $$OutboxEntriesTableUpdateCompanionBuilder,
    (
      OutboxEntry,
      BaseReferences<_$AppDatabase, $OutboxEntriesTable, OutboxEntry>
    ),
    OutboxEntry,
    PrefetchHooks Function()> {
  $$OutboxEntriesTableTableManager(_$AppDatabase db, $OutboxEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> idempotencyKey = const Value.absent(),
            Value<int> targetLocalId = const Value.absent(),
            Value<int?> animalLocalId = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<bool> failed = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              OutboxEntriesCompanion(
            id: id,
            kind: kind,
            idempotencyKey: idempotencyKey,
            targetLocalId: targetLocalId,
            animalLocalId: animalLocalId,
            payload: payload,
            attempts: attempts,
            lastError: lastError,
            failed: failed,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String kind,
            required String idempotencyKey,
            required int targetLocalId,
            Value<int?> animalLocalId = const Value.absent(),
            required String payload,
            Value<int> attempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<bool> failed = const Value.absent(),
            required DateTime createdAt,
          }) =>
              OutboxEntriesCompanion.insert(
            id: id,
            kind: kind,
            idempotencyKey: idempotencyKey,
            targetLocalId: targetLocalId,
            animalLocalId: animalLocalId,
            payload: payload,
            attempts: attempts,
            lastError: lastError,
            failed: failed,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$OutboxEntriesTable, OutboxEntry>(table),
                    BaseReferences<_$AppDatabase, $OutboxEntriesTable,
                        OutboxEntry>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OutboxEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OutboxEntriesTable,
    OutboxEntry,
    $$OutboxEntriesTableFilterComposer,
    $$OutboxEntriesTableOrderingComposer,
    $$OutboxEntriesTableAnnotationComposer,
    $$OutboxEntriesTableCreateCompanionBuilder,
    $$OutboxEntriesTableUpdateCompanionBuilder,
    (
      OutboxEntry,
      BaseReferences<_$AppDatabase, $OutboxEntriesTable, OutboxEntry>
    ),
    OutboxEntry,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedAnimalsTableTableManager get cachedAnimals =>
      $$CachedAnimalsTableTableManager(_db, _db.cachedAnimals);
  $$CachedNotesTableTableManager get cachedNotes =>
      $$CachedNotesTableTableManager(_db, _db.cachedNotes);
  $$OutboxEntriesTableTableManager get outboxEntries =>
      $$OutboxEntriesTableTableManager(_db, _db.outboxEntries);
}
