// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SessionsTableTable extends SessionsTable
    with TableInfo<$SessionsTableTable, LocalSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta =
      const VerificationMeta('localId');
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
      'local_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serverIdMeta =
      const VerificationMeta('serverId');
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
      'server_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _teacherIdMeta =
      const VerificationMeta('teacherId');
  @override
  late final GeneratedColumn<String> teacherId = GeneratedColumn<String>(
      'teacher_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _classIdMeta =
      const VerificationMeta('classId');
  @override
  late final GeneratedColumn<String> classId = GeneratedColumn<String>(
      'class_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _courseMeta = const VerificationMeta('course');
  @override
  late final GeneratedColumn<String> course = GeneratedColumn<String>(
      'course', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _branchMeta = const VerificationMeta('branch');
  @override
  late final GeneratedColumn<String> branch = GeneratedColumn<String>(
      'branch', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<String> year = GeneratedColumn<String>(
      'year', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationMeta =
      const VerificationMeta('location');
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
      'location', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Room 204'));
  static const VerificationMeta _startTimeMeta =
      const VerificationMeta('startTime');
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
      'start_time', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endTimeMeta =
      const VerificationMeta('endTime');
  @override
  late final GeneratedColumn<DateTime> endTime = GeneratedColumn<DateTime>(
      'end_time', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _txPowerLevelMeta =
      const VerificationMeta('txPowerLevel');
  @override
  late final GeneratedColumn<int> txPowerLevel = GeneratedColumn<int>(
      'tx_power_level', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _sessionNonceMeta =
      const VerificationMeta('sessionNonce');
  @override
  late final GeneratedColumn<String> sessionNonce = GeneratedColumn<String>(
      'session_nonce', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _attendanceCountMeta =
      const VerificationMeta('attendanceCount');
  @override
  late final GeneratedColumn<int> attendanceCount = GeneratedColumn<int>(
      'attendance_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _syncStateMeta =
      const VerificationMeta('syncState');
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
      'sync_state', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('synced'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        localId,
        serverId,
        teacherId,
        classId,
        name,
        course,
        branch,
        year,
        location,
        startTime,
        endTime,
        isActive,
        txPowerLevel,
        sessionNonce,
        attendanceCount,
        syncState,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(Insertable<LocalSession> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(_localIdMeta,
          localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta));
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(_serverIdMeta,
          serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta));
    }
    if (data.containsKey('teacher_id')) {
      context.handle(_teacherIdMeta,
          teacherId.isAcceptableOrUnknown(data['teacher_id']!, _teacherIdMeta));
    } else if (isInserting) {
      context.missing(_teacherIdMeta);
    }
    if (data.containsKey('class_id')) {
      context.handle(_classIdMeta,
          classId.isAcceptableOrUnknown(data['class_id']!, _classIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('course')) {
      context.handle(_courseMeta,
          course.isAcceptableOrUnknown(data['course']!, _courseMeta));
    }
    if (data.containsKey('branch')) {
      context.handle(_branchMeta,
          branch.isAcceptableOrUnknown(data['branch']!, _branchMeta));
    }
    if (data.containsKey('year')) {
      context.handle(
          _yearMeta, year.isAcceptableOrUnknown(data['year']!, _yearMeta));
    }
    if (data.containsKey('location')) {
      context.handle(_locationMeta,
          location.isAcceptableOrUnknown(data['location']!, _locationMeta));
    }
    if (data.containsKey('start_time')) {
      context.handle(_startTimeMeta,
          startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta));
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(_endTimeMeta,
          endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta));
    } else if (isInserting) {
      context.missing(_endTimeMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('tx_power_level')) {
      context.handle(
          _txPowerLevelMeta,
          txPowerLevel.isAcceptableOrUnknown(
              data['tx_power_level']!, _txPowerLevelMeta));
    }
    if (data.containsKey('session_nonce')) {
      context.handle(
          _sessionNonceMeta,
          sessionNonce.isAcceptableOrUnknown(
              data['session_nonce']!, _sessionNonceMeta));
    }
    if (data.containsKey('attendance_count')) {
      context.handle(
          _attendanceCountMeta,
          attendanceCount.isAcceptableOrUnknown(
              data['attendance_count']!, _attendanceCountMeta));
    }
    if (data.containsKey('sync_state')) {
      context.handle(_syncStateMeta,
          syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  LocalSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSession(
      localId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_id'])!,
      serverId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_id']),
      teacherId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}teacher_id'])!,
      classId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}class_id']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      course: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}course']),
      branch: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch']),
      year: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}year']),
      location: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location'])!,
      startTime: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_time'])!,
      endTime: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end_time'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      txPowerLevel: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tx_power_level']),
      sessionNonce: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_nonce']),
      attendanceCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attendance_count'])!,
      syncState: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_state'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SessionsTableTable createAlias(String alias) {
    return $SessionsTableTable(attachedDatabase, alias);
  }
}

class LocalSession extends DataClass implements Insertable<LocalSession> {
  /// Client-generated unique identifier (UUID v4).
  final String localId;

  /// Central backend session UUID (nullable for sessions created offline).
  final String? serverId;

  /// Faculty UID of the instructor.
  final String teacherId;

  /// Optional link to normalized class catalog entry.
  final String? classId;

  /// Subject or session title (e.g. 'CS301 Distributed Systems').
  final String name;

  /// Academic curriculum metadata.
  final String? course;
  final String? branch;
  final String? year;

  /// Classroom / lecture hall location.
  final String location;

  /// Scheduled or actual session timestamps.
  final DateTime startTime;
  final DateTime endTime;

  /// Whether the session is currently broadcasting / collecting responses.
  final bool isActive;

  /// Ble broadcast transmit power setting (0: Low, 1: Medium, 2: High).
  final int? txPowerLevel;

  /// Ephemeral session nonce generated for cryptographic challenge binding.
  final String? sessionNonce;

  /// Cumulative verified count.
  final int attendanceCount;

  /// Synchronization state with backend ('synced', 'pending_create', 'pending_stop').
  final String syncState;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LocalSession(
      {required this.localId,
      this.serverId,
      required this.teacherId,
      this.classId,
      required this.name,
      this.course,
      this.branch,
      this.year,
      required this.location,
      required this.startTime,
      required this.endTime,
      required this.isActive,
      this.txPowerLevel,
      this.sessionNonce,
      required this.attendanceCount,
      required this.syncState,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['teacher_id'] = Variable<String>(teacherId);
    if (!nullToAbsent || classId != null) {
      map['class_id'] = Variable<String>(classId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || course != null) {
      map['course'] = Variable<String>(course);
    }
    if (!nullToAbsent || branch != null) {
      map['branch'] = Variable<String>(branch);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<String>(year);
    }
    map['location'] = Variable<String>(location);
    map['start_time'] = Variable<DateTime>(startTime);
    map['end_time'] = Variable<DateTime>(endTime);
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || txPowerLevel != null) {
      map['tx_power_level'] = Variable<int>(txPowerLevel);
    }
    if (!nullToAbsent || sessionNonce != null) {
      map['session_nonce'] = Variable<String>(sessionNonce);
    }
    map['attendance_count'] = Variable<int>(attendanceCount);
    map['sync_state'] = Variable<String>(syncState);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SessionsTableCompanion toCompanion(bool nullToAbsent) {
    return SessionsTableCompanion(
      localId: Value(localId),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      teacherId: Value(teacherId),
      classId: classId == null && nullToAbsent
          ? const Value.absent()
          : Value(classId),
      name: Value(name),
      course:
          course == null && nullToAbsent ? const Value.absent() : Value(course),
      branch:
          branch == null && nullToAbsent ? const Value.absent() : Value(branch),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      location: Value(location),
      startTime: Value(startTime),
      endTime: Value(endTime),
      isActive: Value(isActive),
      txPowerLevel: txPowerLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(txPowerLevel),
      sessionNonce: sessionNonce == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionNonce),
      attendanceCount: Value(attendanceCount),
      syncState: Value(syncState),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalSession.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSession(
      localId: serializer.fromJson<String>(json['localId']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      teacherId: serializer.fromJson<String>(json['teacherId']),
      classId: serializer.fromJson<String?>(json['classId']),
      name: serializer.fromJson<String>(json['name']),
      course: serializer.fromJson<String?>(json['course']),
      branch: serializer.fromJson<String?>(json['branch']),
      year: serializer.fromJson<String?>(json['year']),
      location: serializer.fromJson<String>(json['location']),
      startTime: serializer.fromJson<DateTime>(json['startTime']),
      endTime: serializer.fromJson<DateTime>(json['endTime']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      txPowerLevel: serializer.fromJson<int?>(json['txPowerLevel']),
      sessionNonce: serializer.fromJson<String?>(json['sessionNonce']),
      attendanceCount: serializer.fromJson<int>(json['attendanceCount']),
      syncState: serializer.fromJson<String>(json['syncState']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'serverId': serializer.toJson<String?>(serverId),
      'teacherId': serializer.toJson<String>(teacherId),
      'classId': serializer.toJson<String?>(classId),
      'name': serializer.toJson<String>(name),
      'course': serializer.toJson<String?>(course),
      'branch': serializer.toJson<String?>(branch),
      'year': serializer.toJson<String?>(year),
      'location': serializer.toJson<String>(location),
      'startTime': serializer.toJson<DateTime>(startTime),
      'endTime': serializer.toJson<DateTime>(endTime),
      'isActive': serializer.toJson<bool>(isActive),
      'txPowerLevel': serializer.toJson<int?>(txPowerLevel),
      'sessionNonce': serializer.toJson<String?>(sessionNonce),
      'attendanceCount': serializer.toJson<int>(attendanceCount),
      'syncState': serializer.toJson<String>(syncState),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalSession copyWith(
          {String? localId,
          Value<String?> serverId = const Value.absent(),
          String? teacherId,
          Value<String?> classId = const Value.absent(),
          String? name,
          Value<String?> course = const Value.absent(),
          Value<String?> branch = const Value.absent(),
          Value<String?> year = const Value.absent(),
          String? location,
          DateTime? startTime,
          DateTime? endTime,
          bool? isActive,
          Value<int?> txPowerLevel = const Value.absent(),
          Value<String?> sessionNonce = const Value.absent(),
          int? attendanceCount,
          String? syncState,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      LocalSession(
        localId: localId ?? this.localId,
        serverId: serverId.present ? serverId.value : this.serverId,
        teacherId: teacherId ?? this.teacherId,
        classId: classId.present ? classId.value : this.classId,
        name: name ?? this.name,
        course: course.present ? course.value : this.course,
        branch: branch.present ? branch.value : this.branch,
        year: year.present ? year.value : this.year,
        location: location ?? this.location,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        isActive: isActive ?? this.isActive,
        txPowerLevel:
            txPowerLevel.present ? txPowerLevel.value : this.txPowerLevel,
        sessionNonce:
            sessionNonce.present ? sessionNonce.value : this.sessionNonce,
        attendanceCount: attendanceCount ?? this.attendanceCount,
        syncState: syncState ?? this.syncState,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LocalSession copyWithCompanion(SessionsTableCompanion data) {
    return LocalSession(
      localId: data.localId.present ? data.localId.value : this.localId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      teacherId: data.teacherId.present ? data.teacherId.value : this.teacherId,
      classId: data.classId.present ? data.classId.value : this.classId,
      name: data.name.present ? data.name.value : this.name,
      course: data.course.present ? data.course.value : this.course,
      branch: data.branch.present ? data.branch.value : this.branch,
      year: data.year.present ? data.year.value : this.year,
      location: data.location.present ? data.location.value : this.location,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      txPowerLevel: data.txPowerLevel.present
          ? data.txPowerLevel.value
          : this.txPowerLevel,
      sessionNonce: data.sessionNonce.present
          ? data.sessionNonce.value
          : this.sessionNonce,
      attendanceCount: data.attendanceCount.present
          ? data.attendanceCount.value
          : this.attendanceCount,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSession(')
          ..write('localId: $localId, ')
          ..write('serverId: $serverId, ')
          ..write('teacherId: $teacherId, ')
          ..write('classId: $classId, ')
          ..write('name: $name, ')
          ..write('course: $course, ')
          ..write('branch: $branch, ')
          ..write('year: $year, ')
          ..write('location: $location, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('isActive: $isActive, ')
          ..write('txPowerLevel: $txPowerLevel, ')
          ..write('sessionNonce: $sessionNonce, ')
          ..write('attendanceCount: $attendanceCount, ')
          ..write('syncState: $syncState, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      localId,
      serverId,
      teacherId,
      classId,
      name,
      course,
      branch,
      year,
      location,
      startTime,
      endTime,
      isActive,
      txPowerLevel,
      sessionNonce,
      attendanceCount,
      syncState,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSession &&
          other.localId == this.localId &&
          other.serverId == this.serverId &&
          other.teacherId == this.teacherId &&
          other.classId == this.classId &&
          other.name == this.name &&
          other.course == this.course &&
          other.branch == this.branch &&
          other.year == this.year &&
          other.location == this.location &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.isActive == this.isActive &&
          other.txPowerLevel == this.txPowerLevel &&
          other.sessionNonce == this.sessionNonce &&
          other.attendanceCount == this.attendanceCount &&
          other.syncState == this.syncState &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SessionsTableCompanion extends UpdateCompanion<LocalSession> {
  final Value<String> localId;
  final Value<String?> serverId;
  final Value<String> teacherId;
  final Value<String?> classId;
  final Value<String> name;
  final Value<String?> course;
  final Value<String?> branch;
  final Value<String?> year;
  final Value<String> location;
  final Value<DateTime> startTime;
  final Value<DateTime> endTime;
  final Value<bool> isActive;
  final Value<int?> txPowerLevel;
  final Value<String?> sessionNonce;
  final Value<int> attendanceCount;
  final Value<String> syncState;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SessionsTableCompanion({
    this.localId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.teacherId = const Value.absent(),
    this.classId = const Value.absent(),
    this.name = const Value.absent(),
    this.course = const Value.absent(),
    this.branch = const Value.absent(),
    this.year = const Value.absent(),
    this.location = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.isActive = const Value.absent(),
    this.txPowerLevel = const Value.absent(),
    this.sessionNonce = const Value.absent(),
    this.attendanceCount = const Value.absent(),
    this.syncState = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsTableCompanion.insert({
    required String localId,
    this.serverId = const Value.absent(),
    required String teacherId,
    this.classId = const Value.absent(),
    required String name,
    this.course = const Value.absent(),
    this.branch = const Value.absent(),
    this.year = const Value.absent(),
    this.location = const Value.absent(),
    required DateTime startTime,
    required DateTime endTime,
    this.isActive = const Value.absent(),
    this.txPowerLevel = const Value.absent(),
    this.sessionNonce = const Value.absent(),
    this.attendanceCount = const Value.absent(),
    this.syncState = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : localId = Value(localId),
        teacherId = Value(teacherId),
        name = Value(name),
        startTime = Value(startTime),
        endTime = Value(endTime);
  static Insertable<LocalSession> custom({
    Expression<String>? localId,
    Expression<String>? serverId,
    Expression<String>? teacherId,
    Expression<String>? classId,
    Expression<String>? name,
    Expression<String>? course,
    Expression<String>? branch,
    Expression<String>? year,
    Expression<String>? location,
    Expression<DateTime>? startTime,
    Expression<DateTime>? endTime,
    Expression<bool>? isActive,
    Expression<int>? txPowerLevel,
    Expression<String>? sessionNonce,
    Expression<int>? attendanceCount,
    Expression<String>? syncState,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (serverId != null) 'server_id': serverId,
      if (teacherId != null) 'teacher_id': teacherId,
      if (classId != null) 'class_id': classId,
      if (name != null) 'name': name,
      if (course != null) 'course': course,
      if (branch != null) 'branch': branch,
      if (year != null) 'year': year,
      if (location != null) 'location': location,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (isActive != null) 'is_active': isActive,
      if (txPowerLevel != null) 'tx_power_level': txPowerLevel,
      if (sessionNonce != null) 'session_nonce': sessionNonce,
      if (attendanceCount != null) 'attendance_count': attendanceCount,
      if (syncState != null) 'sync_state': syncState,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsTableCompanion copyWith(
      {Value<String>? localId,
      Value<String?>? serverId,
      Value<String>? teacherId,
      Value<String?>? classId,
      Value<String>? name,
      Value<String?>? course,
      Value<String?>? branch,
      Value<String?>? year,
      Value<String>? location,
      Value<DateTime>? startTime,
      Value<DateTime>? endTime,
      Value<bool>? isActive,
      Value<int?>? txPowerLevel,
      Value<String?>? sessionNonce,
      Value<int>? attendanceCount,
      Value<String>? syncState,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return SessionsTableCompanion(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      teacherId: teacherId ?? this.teacherId,
      classId: classId ?? this.classId,
      name: name ?? this.name,
      course: course ?? this.course,
      branch: branch ?? this.branch,
      year: year ?? this.year,
      location: location ?? this.location,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isActive: isActive ?? this.isActive,
      txPowerLevel: txPowerLevel ?? this.txPowerLevel,
      sessionNonce: sessionNonce ?? this.sessionNonce,
      attendanceCount: attendanceCount ?? this.attendanceCount,
      syncState: syncState ?? this.syncState,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (teacherId.present) {
      map['teacher_id'] = Variable<String>(teacherId.value);
    }
    if (classId.present) {
      map['class_id'] = Variable<String>(classId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (course.present) {
      map['course'] = Variable<String>(course.value);
    }
    if (branch.present) {
      map['branch'] = Variable<String>(branch.value);
    }
    if (year.present) {
      map['year'] = Variable<String>(year.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<DateTime>(endTime.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (txPowerLevel.present) {
      map['tx_power_level'] = Variable<int>(txPowerLevel.value);
    }
    if (sessionNonce.present) {
      map['session_nonce'] = Variable<String>(sessionNonce.value);
    }
    if (attendanceCount.present) {
      map['attendance_count'] = Variable<int>(attendanceCount.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsTableCompanion(')
          ..write('localId: $localId, ')
          ..write('serverId: $serverId, ')
          ..write('teacherId: $teacherId, ')
          ..write('classId: $classId, ')
          ..write('name: $name, ')
          ..write('course: $course, ')
          ..write('branch: $branch, ')
          ..write('year: $year, ')
          ..write('location: $location, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('isActive: $isActive, ')
          ..write('txPowerLevel: $txPowerLevel, ')
          ..write('sessionNonce: $sessionNonce, ')
          ..write('attendanceCount: $attendanceCount, ')
          ..write('syncState: $syncState, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StudentsTableTable extends StudentsTable
    with TableInfo<$StudentsTableTable, LocalStudent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudentsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _studentIdMeta =
      const VerificationMeta('studentId');
  @override
  late final GeneratedColumn<String> studentId = GeneratedColumn<String>(
      'student_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _rollNumberMeta =
      const VerificationMeta('rollNumber');
  @override
  late final GeneratedColumn<String> rollNumber = GeneratedColumn<String>(
      'roll_number', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _courseMeta = const VerificationMeta('course');
  @override
  late final GeneratedColumn<String> course = GeneratedColumn<String>(
      'course', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _branchMeta = const VerificationMeta('branch');
  @override
  late final GeneratedColumn<String> branch = GeneratedColumn<String>(
      'branch', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<String> year = GeneratedColumn<String>(
      'year', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deviceKeyIdMeta =
      const VerificationMeta('deviceKeyId');
  @override
  late final GeneratedColumn<String> deviceKeyId = GeneratedColumn<String>(
      'device_key_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        studentId,
        name,
        email,
        rollNumber,
        course,
        branch,
        year,
        deviceKeyId,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'students';
  @override
  VerificationContext validateIntegrity(Insertable<LocalStudent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('student_id')) {
      context.handle(_studentIdMeta,
          studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta));
    } else if (isInserting) {
      context.missing(_studentIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('roll_number')) {
      context.handle(
          _rollNumberMeta,
          rollNumber.isAcceptableOrUnknown(
              data['roll_number']!, _rollNumberMeta));
    }
    if (data.containsKey('course')) {
      context.handle(_courseMeta,
          course.isAcceptableOrUnknown(data['course']!, _courseMeta));
    }
    if (data.containsKey('branch')) {
      context.handle(_branchMeta,
          branch.isAcceptableOrUnknown(data['branch']!, _branchMeta));
    }
    if (data.containsKey('year')) {
      context.handle(
          _yearMeta, year.isAcceptableOrUnknown(data['year']!, _yearMeta));
    }
    if (data.containsKey('device_key_id')) {
      context.handle(
          _deviceKeyIdMeta,
          deviceKeyId.isAcceptableOrUnknown(
              data['device_key_id']!, _deviceKeyIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {studentId};
  @override
  LocalStudent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalStudent(
      studentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}student_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      rollNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}roll_number']),
      course: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}course']),
      branch: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch']),
      year: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}year']),
      deviceKeyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_key_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $StudentsTableTable createAlias(String alias) {
    return $StudentsTableTable(attachedDatabase, alias);
  }
}

class LocalStudent extends DataClass implements Insertable<LocalStudent> {
  /// Primary student identifier (UUID or registration UID).
  final String studentId;

  /// Student display name.
  final String name;

  /// Institutional email.
  final String? email;

  /// University registration number / roll number.
  final String? rollNumber;

  /// Academic curriculum attributes.
  final String? course;
  final String? branch;
  final String? year;

  /// Registered Passport public key identifier for cryptographic authentication.
  final String? deviceKeyId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LocalStudent(
      {required this.studentId,
      required this.name,
      this.email,
      this.rollNumber,
      this.course,
      this.branch,
      this.year,
      this.deviceKeyId,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['student_id'] = Variable<String>(studentId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || rollNumber != null) {
      map['roll_number'] = Variable<String>(rollNumber);
    }
    if (!nullToAbsent || course != null) {
      map['course'] = Variable<String>(course);
    }
    if (!nullToAbsent || branch != null) {
      map['branch'] = Variable<String>(branch);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<String>(year);
    }
    if (!nullToAbsent || deviceKeyId != null) {
      map['device_key_id'] = Variable<String>(deviceKeyId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StudentsTableCompanion toCompanion(bool nullToAbsent) {
    return StudentsTableCompanion(
      studentId: Value(studentId),
      name: Value(name),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      rollNumber: rollNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(rollNumber),
      course:
          course == null && nullToAbsent ? const Value.absent() : Value(course),
      branch:
          branch == null && nullToAbsent ? const Value.absent() : Value(branch),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      deviceKeyId: deviceKeyId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceKeyId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalStudent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalStudent(
      studentId: serializer.fromJson<String>(json['studentId']),
      name: serializer.fromJson<String>(json['name']),
      email: serializer.fromJson<String?>(json['email']),
      rollNumber: serializer.fromJson<String?>(json['rollNumber']),
      course: serializer.fromJson<String?>(json['course']),
      branch: serializer.fromJson<String?>(json['branch']),
      year: serializer.fromJson<String?>(json['year']),
      deviceKeyId: serializer.fromJson<String?>(json['deviceKeyId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'studentId': serializer.toJson<String>(studentId),
      'name': serializer.toJson<String>(name),
      'email': serializer.toJson<String?>(email),
      'rollNumber': serializer.toJson<String?>(rollNumber),
      'course': serializer.toJson<String?>(course),
      'branch': serializer.toJson<String?>(branch),
      'year': serializer.toJson<String?>(year),
      'deviceKeyId': serializer.toJson<String?>(deviceKeyId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalStudent copyWith(
          {String? studentId,
          String? name,
          Value<String?> email = const Value.absent(),
          Value<String?> rollNumber = const Value.absent(),
          Value<String?> course = const Value.absent(),
          Value<String?> branch = const Value.absent(),
          Value<String?> year = const Value.absent(),
          Value<String?> deviceKeyId = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      LocalStudent(
        studentId: studentId ?? this.studentId,
        name: name ?? this.name,
        email: email.present ? email.value : this.email,
        rollNumber: rollNumber.present ? rollNumber.value : this.rollNumber,
        course: course.present ? course.value : this.course,
        branch: branch.present ? branch.value : this.branch,
        year: year.present ? year.value : this.year,
        deviceKeyId: deviceKeyId.present ? deviceKeyId.value : this.deviceKeyId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LocalStudent copyWithCompanion(StudentsTableCompanion data) {
    return LocalStudent(
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      name: data.name.present ? data.name.value : this.name,
      email: data.email.present ? data.email.value : this.email,
      rollNumber:
          data.rollNumber.present ? data.rollNumber.value : this.rollNumber,
      course: data.course.present ? data.course.value : this.course,
      branch: data.branch.present ? data.branch.value : this.branch,
      year: data.year.present ? data.year.value : this.year,
      deviceKeyId:
          data.deviceKeyId.present ? data.deviceKeyId.value : this.deviceKeyId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalStudent(')
          ..write('studentId: $studentId, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('rollNumber: $rollNumber, ')
          ..write('course: $course, ')
          ..write('branch: $branch, ')
          ..write('year: $year, ')
          ..write('deviceKeyId: $deviceKeyId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(studentId, name, email, rollNumber, course,
      branch, year, deviceKeyId, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalStudent &&
          other.studentId == this.studentId &&
          other.name == this.name &&
          other.email == this.email &&
          other.rollNumber == this.rollNumber &&
          other.course == this.course &&
          other.branch == this.branch &&
          other.year == this.year &&
          other.deviceKeyId == this.deviceKeyId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StudentsTableCompanion extends UpdateCompanion<LocalStudent> {
  final Value<String> studentId;
  final Value<String> name;
  final Value<String?> email;
  final Value<String?> rollNumber;
  final Value<String?> course;
  final Value<String?> branch;
  final Value<String?> year;
  final Value<String?> deviceKeyId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StudentsTableCompanion({
    this.studentId = const Value.absent(),
    this.name = const Value.absent(),
    this.email = const Value.absent(),
    this.rollNumber = const Value.absent(),
    this.course = const Value.absent(),
    this.branch = const Value.absent(),
    this.year = const Value.absent(),
    this.deviceKeyId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudentsTableCompanion.insert({
    required String studentId,
    required String name,
    this.email = const Value.absent(),
    this.rollNumber = const Value.absent(),
    this.course = const Value.absent(),
    this.branch = const Value.absent(),
    this.year = const Value.absent(),
    this.deviceKeyId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : studentId = Value(studentId),
        name = Value(name);
  static Insertable<LocalStudent> custom({
    Expression<String>? studentId,
    Expression<String>? name,
    Expression<String>? email,
    Expression<String>? rollNumber,
    Expression<String>? course,
    Expression<String>? branch,
    Expression<String>? year,
    Expression<String>? deviceKeyId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (studentId != null) 'student_id': studentId,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (rollNumber != null) 'roll_number': rollNumber,
      if (course != null) 'course': course,
      if (branch != null) 'branch': branch,
      if (year != null) 'year': year,
      if (deviceKeyId != null) 'device_key_id': deviceKeyId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudentsTableCompanion copyWith(
      {Value<String>? studentId,
      Value<String>? name,
      Value<String?>? email,
      Value<String?>? rollNumber,
      Value<String?>? course,
      Value<String?>? branch,
      Value<String?>? year,
      Value<String?>? deviceKeyId,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return StudentsTableCompanion(
      studentId: studentId ?? this.studentId,
      name: name ?? this.name,
      email: email ?? this.email,
      rollNumber: rollNumber ?? this.rollNumber,
      course: course ?? this.course,
      branch: branch ?? this.branch,
      year: year ?? this.year,
      deviceKeyId: deviceKeyId ?? this.deviceKeyId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (studentId.present) {
      map['student_id'] = Variable<String>(studentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (rollNumber.present) {
      map['roll_number'] = Variable<String>(rollNumber.value);
    }
    if (course.present) {
      map['course'] = Variable<String>(course.value);
    }
    if (branch.present) {
      map['branch'] = Variable<String>(branch.value);
    }
    if (year.present) {
      map['year'] = Variable<String>(year.value);
    }
    if (deviceKeyId.present) {
      map['device_key_id'] = Variable<String>(deviceKeyId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudentsTableCompanion(')
          ..write('studentId: $studentId, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('rollNumber: $rollNumber, ')
          ..write('course: $course, ')
          ..write('branch: $branch, ')
          ..write('year: $year, ')
          ..write('deviceKeyId: $deviceKeyId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClassesTableTable extends ClassesTable
    with TableInfo<$ClassesTableTable, LocalClass> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClassesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _classIdMeta =
      const VerificationMeta('classId');
  @override
  late final GeneratedColumn<String> classId = GeneratedColumn<String>(
      'class_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _courseMeta = const VerificationMeta('course');
  @override
  late final GeneratedColumn<String> course = GeneratedColumn<String>(
      'course', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _branchMeta = const VerificationMeta('branch');
  @override
  late final GeneratedColumn<String> branch = GeneratedColumn<String>(
      'branch', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<String> year = GeneratedColumn<String>(
      'year', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _roomMeta = const VerificationMeta('room');
  @override
  late final GeneratedColumn<String> room = GeneratedColumn<String>(
      'room', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _teacherIdMeta =
      const VerificationMeta('teacherId');
  @override
  late final GeneratedColumn<String> teacherId = GeneratedColumn<String>(
      'teacher_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [classId, name, code, course, branch, year, room, teacherId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'classes';
  @override
  VerificationContext validateIntegrity(Insertable<LocalClass> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('class_id')) {
      context.handle(_classIdMeta,
          classId.isAcceptableOrUnknown(data['class_id']!, _classIdMeta));
    } else if (isInserting) {
      context.missing(_classIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    }
    if (data.containsKey('course')) {
      context.handle(_courseMeta,
          course.isAcceptableOrUnknown(data['course']!, _courseMeta));
    }
    if (data.containsKey('branch')) {
      context.handle(_branchMeta,
          branch.isAcceptableOrUnknown(data['branch']!, _branchMeta));
    }
    if (data.containsKey('year')) {
      context.handle(
          _yearMeta, year.isAcceptableOrUnknown(data['year']!, _yearMeta));
    }
    if (data.containsKey('room')) {
      context.handle(
          _roomMeta, room.isAcceptableOrUnknown(data['room']!, _roomMeta));
    }
    if (data.containsKey('teacher_id')) {
      context.handle(_teacherIdMeta,
          teacherId.isAcceptableOrUnknown(data['teacher_id']!, _teacherIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {classId};
  @override
  LocalClass map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalClass(
      classId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}class_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code']),
      course: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}course']),
      branch: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch']),
      year: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}year']),
      room: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}room']),
      teacherId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}teacher_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ClassesTableTable createAlias(String alias) {
    return $ClassesTableTable(attachedDatabase, alias);
  }
}

class LocalClass extends DataClass implements Insertable<LocalClass> {
  /// Class identifier (e.g. 'class_cs301' or UUID).
  final String classId;

  /// Subject / course display name (e.g. 'Distributed Systems').
  final String name;

  /// Subject code (e.g. 'CS301').
  final String? code;

  /// Academic curriculum metadata.
  final String? course;
  final String? branch;
  final String? year;

  /// Assigned lecture hall or classroom.
  final String? room;

  /// Assigned teacher UID.
  final String? teacherId;
  final DateTime createdAt;
  const LocalClass(
      {required this.classId,
      required this.name,
      this.code,
      this.course,
      this.branch,
      this.year,
      this.room,
      this.teacherId,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['class_id'] = Variable<String>(classId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || code != null) {
      map['code'] = Variable<String>(code);
    }
    if (!nullToAbsent || course != null) {
      map['course'] = Variable<String>(course);
    }
    if (!nullToAbsent || branch != null) {
      map['branch'] = Variable<String>(branch);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<String>(year);
    }
    if (!nullToAbsent || room != null) {
      map['room'] = Variable<String>(room);
    }
    if (!nullToAbsent || teacherId != null) {
      map['teacher_id'] = Variable<String>(teacherId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ClassesTableCompanion toCompanion(bool nullToAbsent) {
    return ClassesTableCompanion(
      classId: Value(classId),
      name: Value(name),
      code: code == null && nullToAbsent ? const Value.absent() : Value(code),
      course:
          course == null && nullToAbsent ? const Value.absent() : Value(course),
      branch:
          branch == null && nullToAbsent ? const Value.absent() : Value(branch),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      room: room == null && nullToAbsent ? const Value.absent() : Value(room),
      teacherId: teacherId == null && nullToAbsent
          ? const Value.absent()
          : Value(teacherId),
      createdAt: Value(createdAt),
    );
  }

  factory LocalClass.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalClass(
      classId: serializer.fromJson<String>(json['classId']),
      name: serializer.fromJson<String>(json['name']),
      code: serializer.fromJson<String?>(json['code']),
      course: serializer.fromJson<String?>(json['course']),
      branch: serializer.fromJson<String?>(json['branch']),
      year: serializer.fromJson<String?>(json['year']),
      room: serializer.fromJson<String?>(json['room']),
      teacherId: serializer.fromJson<String?>(json['teacherId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'classId': serializer.toJson<String>(classId),
      'name': serializer.toJson<String>(name),
      'code': serializer.toJson<String?>(code),
      'course': serializer.toJson<String?>(course),
      'branch': serializer.toJson<String?>(branch),
      'year': serializer.toJson<String?>(year),
      'room': serializer.toJson<String?>(room),
      'teacherId': serializer.toJson<String?>(teacherId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalClass copyWith(
          {String? classId,
          String? name,
          Value<String?> code = const Value.absent(),
          Value<String?> course = const Value.absent(),
          Value<String?> branch = const Value.absent(),
          Value<String?> year = const Value.absent(),
          Value<String?> room = const Value.absent(),
          Value<String?> teacherId = const Value.absent(),
          DateTime? createdAt}) =>
      LocalClass(
        classId: classId ?? this.classId,
        name: name ?? this.name,
        code: code.present ? code.value : this.code,
        course: course.present ? course.value : this.course,
        branch: branch.present ? branch.value : this.branch,
        year: year.present ? year.value : this.year,
        room: room.present ? room.value : this.room,
        teacherId: teacherId.present ? teacherId.value : this.teacherId,
        createdAt: createdAt ?? this.createdAt,
      );
  LocalClass copyWithCompanion(ClassesTableCompanion data) {
    return LocalClass(
      classId: data.classId.present ? data.classId.value : this.classId,
      name: data.name.present ? data.name.value : this.name,
      code: data.code.present ? data.code.value : this.code,
      course: data.course.present ? data.course.value : this.course,
      branch: data.branch.present ? data.branch.value : this.branch,
      year: data.year.present ? data.year.value : this.year,
      room: data.room.present ? data.room.value : this.room,
      teacherId: data.teacherId.present ? data.teacherId.value : this.teacherId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalClass(')
          ..write('classId: $classId, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('course: $course, ')
          ..write('branch: $branch, ')
          ..write('year: $year, ')
          ..write('room: $room, ')
          ..write('teacherId: $teacherId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      classId, name, code, course, branch, year, room, teacherId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalClass &&
          other.classId == this.classId &&
          other.name == this.name &&
          other.code == this.code &&
          other.course == this.course &&
          other.branch == this.branch &&
          other.year == this.year &&
          other.room == this.room &&
          other.teacherId == this.teacherId &&
          other.createdAt == this.createdAt);
}

class ClassesTableCompanion extends UpdateCompanion<LocalClass> {
  final Value<String> classId;
  final Value<String> name;
  final Value<String?> code;
  final Value<String?> course;
  final Value<String?> branch;
  final Value<String?> year;
  final Value<String?> room;
  final Value<String?> teacherId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ClassesTableCompanion({
    this.classId = const Value.absent(),
    this.name = const Value.absent(),
    this.code = const Value.absent(),
    this.course = const Value.absent(),
    this.branch = const Value.absent(),
    this.year = const Value.absent(),
    this.room = const Value.absent(),
    this.teacherId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClassesTableCompanion.insert({
    required String classId,
    required String name,
    this.code = const Value.absent(),
    this.course = const Value.absent(),
    this.branch = const Value.absent(),
    this.year = const Value.absent(),
    this.room = const Value.absent(),
    this.teacherId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : classId = Value(classId),
        name = Value(name);
  static Insertable<LocalClass> custom({
    Expression<String>? classId,
    Expression<String>? name,
    Expression<String>? code,
    Expression<String>? course,
    Expression<String>? branch,
    Expression<String>? year,
    Expression<String>? room,
    Expression<String>? teacherId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (classId != null) 'class_id': classId,
      if (name != null) 'name': name,
      if (code != null) 'code': code,
      if (course != null) 'course': course,
      if (branch != null) 'branch': branch,
      if (year != null) 'year': year,
      if (room != null) 'room': room,
      if (teacherId != null) 'teacher_id': teacherId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClassesTableCompanion copyWith(
      {Value<String>? classId,
      Value<String>? name,
      Value<String?>? code,
      Value<String?>? course,
      Value<String?>? branch,
      Value<String?>? year,
      Value<String?>? room,
      Value<String?>? teacherId,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return ClassesTableCompanion(
      classId: classId ?? this.classId,
      name: name ?? this.name,
      code: code ?? this.code,
      course: course ?? this.course,
      branch: branch ?? this.branch,
      year: year ?? this.year,
      room: room ?? this.room,
      teacherId: teacherId ?? this.teacherId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (classId.present) {
      map['class_id'] = Variable<String>(classId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (course.present) {
      map['course'] = Variable<String>(course.value);
    }
    if (branch.present) {
      map['branch'] = Variable<String>(branch.value);
    }
    if (year.present) {
      map['year'] = Variable<String>(year.value);
    }
    if (room.present) {
      map['room'] = Variable<String>(room.value);
    }
    if (teacherId.present) {
      map['teacher_id'] = Variable<String>(teacherId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClassesTableCompanion(')
          ..write('classId: $classId, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('course: $course, ')
          ..write('branch: $branch, ')
          ..write('year: $year, ')
          ..write('room: $room, ')
          ..write('teacherId: $teacherId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EnrollmentsTableTable extends EnrollmentsTable
    with TableInfo<$EnrollmentsTableTable, LocalEnrollment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EnrollmentsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _classIdMeta =
      const VerificationMeta('classId');
  @override
  late final GeneratedColumn<String> classId = GeneratedColumn<String>(
      'class_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES classes (class_id) ON DELETE CASCADE'));
  static const VerificationMeta _studentIdMeta =
      const VerificationMeta('studentId');
  @override
  late final GeneratedColumn<String> studentId = GeneratedColumn<String>(
      'student_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES students (student_id) ON DELETE CASCADE'));
  static const VerificationMeta _enrolledAtMeta =
      const VerificationMeta('enrolledAt');
  @override
  late final GeneratedColumn<DateTime> enrolledAt = GeneratedColumn<DateTime>(
      'enrolled_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, classId, studentId, enrolledAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'enrollments';
  @override
  VerificationContext validateIntegrity(Insertable<LocalEnrollment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('class_id')) {
      context.handle(_classIdMeta,
          classId.isAcceptableOrUnknown(data['class_id']!, _classIdMeta));
    } else if (isInserting) {
      context.missing(_classIdMeta);
    }
    if (data.containsKey('student_id')) {
      context.handle(_studentIdMeta,
          studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta));
    } else if (isInserting) {
      context.missing(_studentIdMeta);
    }
    if (data.containsKey('enrolled_at')) {
      context.handle(
          _enrolledAtMeta,
          enrolledAt.isAcceptableOrUnknown(
              data['enrolled_at']!, _enrolledAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {classId, studentId},
      ];
  @override
  LocalEnrollment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalEnrollment(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      classId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}class_id'])!,
      studentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}student_id'])!,
      enrolledAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}enrolled_at'])!,
    );
  }

  @override
  $EnrollmentsTableTable createAlias(String alias) {
    return $EnrollmentsTableTable(attachedDatabase, alias);
  }
}

class LocalEnrollment extends DataClass implements Insertable<LocalEnrollment> {
  /// Primary enrollment UUID.
  final String id;

  /// Target class identifier.
  final String classId;

  /// Enrolled student identifier.
  final String studentId;

  /// Enrollment timestamp.
  final DateTime enrolledAt;
  const LocalEnrollment(
      {required this.id,
      required this.classId,
      required this.studentId,
      required this.enrolledAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['class_id'] = Variable<String>(classId);
    map['student_id'] = Variable<String>(studentId);
    map['enrolled_at'] = Variable<DateTime>(enrolledAt);
    return map;
  }

  EnrollmentsTableCompanion toCompanion(bool nullToAbsent) {
    return EnrollmentsTableCompanion(
      id: Value(id),
      classId: Value(classId),
      studentId: Value(studentId),
      enrolledAt: Value(enrolledAt),
    );
  }

  factory LocalEnrollment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalEnrollment(
      id: serializer.fromJson<String>(json['id']),
      classId: serializer.fromJson<String>(json['classId']),
      studentId: serializer.fromJson<String>(json['studentId']),
      enrolledAt: serializer.fromJson<DateTime>(json['enrolledAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'classId': serializer.toJson<String>(classId),
      'studentId': serializer.toJson<String>(studentId),
      'enrolledAt': serializer.toJson<DateTime>(enrolledAt),
    };
  }

  LocalEnrollment copyWith(
          {String? id,
          String? classId,
          String? studentId,
          DateTime? enrolledAt}) =>
      LocalEnrollment(
        id: id ?? this.id,
        classId: classId ?? this.classId,
        studentId: studentId ?? this.studentId,
        enrolledAt: enrolledAt ?? this.enrolledAt,
      );
  LocalEnrollment copyWithCompanion(EnrollmentsTableCompanion data) {
    return LocalEnrollment(
      id: data.id.present ? data.id.value : this.id,
      classId: data.classId.present ? data.classId.value : this.classId,
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      enrolledAt:
          data.enrolledAt.present ? data.enrolledAt.value : this.enrolledAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalEnrollment(')
          ..write('id: $id, ')
          ..write('classId: $classId, ')
          ..write('studentId: $studentId, ')
          ..write('enrolledAt: $enrolledAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, classId, studentId, enrolledAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalEnrollment &&
          other.id == this.id &&
          other.classId == this.classId &&
          other.studentId == this.studentId &&
          other.enrolledAt == this.enrolledAt);
}

class EnrollmentsTableCompanion extends UpdateCompanion<LocalEnrollment> {
  final Value<String> id;
  final Value<String> classId;
  final Value<String> studentId;
  final Value<DateTime> enrolledAt;
  final Value<int> rowid;
  const EnrollmentsTableCompanion({
    this.id = const Value.absent(),
    this.classId = const Value.absent(),
    this.studentId = const Value.absent(),
    this.enrolledAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EnrollmentsTableCompanion.insert({
    required String id,
    required String classId,
    required String studentId,
    this.enrolledAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        classId = Value(classId),
        studentId = Value(studentId);
  static Insertable<LocalEnrollment> custom({
    Expression<String>? id,
    Expression<String>? classId,
    Expression<String>? studentId,
    Expression<DateTime>? enrolledAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (classId != null) 'class_id': classId,
      if (studentId != null) 'student_id': studentId,
      if (enrolledAt != null) 'enrolled_at': enrolledAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EnrollmentsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? classId,
      Value<String>? studentId,
      Value<DateTime>? enrolledAt,
      Value<int>? rowid}) {
    return EnrollmentsTableCompanion(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      studentId: studentId ?? this.studentId,
      enrolledAt: enrolledAt ?? this.enrolledAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (classId.present) {
      map['class_id'] = Variable<String>(classId.value);
    }
    if (studentId.present) {
      map['student_id'] = Variable<String>(studentId.value);
    }
    if (enrolledAt.present) {
      map['enrolled_at'] = Variable<DateTime>(enrolledAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EnrollmentsTableCompanion(')
          ..write('id: $id, ')
          ..write('classId: $classId, ')
          ..write('studentId: $studentId, ')
          ..write('enrolledAt: $enrolledAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttendanceRecordsTableTable extends AttendanceRecordsTable
    with TableInfo<$AttendanceRecordsTableTable, LocalAttendanceRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttendanceRecordsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta =
      const VerificationMeta('localId');
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
      'local_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serverIdMeta =
      const VerificationMeta('serverId');
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
      'server_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES sessions (local_id) ON DELETE CASCADE'));
  static const VerificationMeta _studentIdMeta =
      const VerificationMeta('studentId');
  @override
  late final GeneratedColumn<String> studentId = GeneratedColumn<String>(
      'student_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES students (student_id) ON DELETE CASCADE'));
  static const VerificationMeta _studentNameMeta =
      const VerificationMeta('studentName');
  @override
  late final GeneratedColumn<String> studentName = GeneratedColumn<String>(
      'student_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('present'));
  static const VerificationMeta _checkInTimeMeta =
      const VerificationMeta('checkInTime');
  @override
  late final GeneratedColumn<DateTime> checkInTime = GeneratedColumn<DateTime>(
      'check_in_time', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _idempotencyKeyMeta =
      const VerificationMeta('idempotencyKey');
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
      'idempotency_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deviceKeyIdMeta =
      const VerificationMeta('deviceKeyId');
  @override
  late final GeneratedColumn<String> deviceKeyId = GeneratedColumn<String>(
      'device_key_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _responseNonceMeta =
      const VerificationMeta('responseNonce');
  @override
  late final GeneratedColumn<String> responseNonce = GeneratedColumn<String>(
      'response_nonce', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _verificationModeMeta =
      const VerificationMeta('verificationMode');
  @override
  late final GeneratedColumn<String> verificationMode = GeneratedColumn<String>(
      'verification_mode', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('BLE_BATCH'));
  static const VerificationMeta _proximityTierMeta =
      const VerificationMeta('proximityTier');
  @override
  late final GeneratedColumn<String> proximityTier = GeneratedColumn<String>(
      'proximity_tier', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncStateMeta =
      const VerificationMeta('syncState');
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
      'sync_state', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        localId,
        serverId,
        sessionId,
        studentId,
        studentName,
        status,
        checkInTime,
        idempotencyKey,
        deviceKeyId,
        responseNonce,
        verificationMode,
        proximityTier,
        syncState,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attendance_records';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalAttendanceRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(_localIdMeta,
          localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta));
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(_serverIdMeta,
          serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('student_id')) {
      context.handle(_studentIdMeta,
          studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta));
    } else if (isInserting) {
      context.missing(_studentIdMeta);
    }
    if (data.containsKey('student_name')) {
      context.handle(
          _studentNameMeta,
          studentName.isAcceptableOrUnknown(
              data['student_name']!, _studentNameMeta));
    } else if (isInserting) {
      context.missing(_studentNameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('check_in_time')) {
      context.handle(
          _checkInTimeMeta,
          checkInTime.isAcceptableOrUnknown(
              data['check_in_time']!, _checkInTimeMeta));
    } else if (isInserting) {
      context.missing(_checkInTimeMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
          _idempotencyKeyMeta,
          idempotencyKey.isAcceptableOrUnknown(
              data['idempotency_key']!, _idempotencyKeyMeta));
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('device_key_id')) {
      context.handle(
          _deviceKeyIdMeta,
          deviceKeyId.isAcceptableOrUnknown(
              data['device_key_id']!, _deviceKeyIdMeta));
    }
    if (data.containsKey('response_nonce')) {
      context.handle(
          _responseNonceMeta,
          responseNonce.isAcceptableOrUnknown(
              data['response_nonce']!, _responseNonceMeta));
    }
    if (data.containsKey('verification_mode')) {
      context.handle(
          _verificationModeMeta,
          verificationMode.isAcceptableOrUnknown(
              data['verification_mode']!, _verificationModeMeta));
    }
    if (data.containsKey('proximity_tier')) {
      context.handle(
          _proximityTierMeta,
          proximityTier.isAcceptableOrUnknown(
              data['proximity_tier']!, _proximityTierMeta));
    }
    if (data.containsKey('sync_state')) {
      context.handle(_syncStateMeta,
          syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {idempotencyKey},
        {sessionId, studentId},
      ];
  @override
  LocalAttendanceRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAttendanceRecord(
      localId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_id'])!,
      serverId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_id']),
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      studentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}student_id'])!,
      studentName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}student_name'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      checkInTime: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}check_in_time'])!,
      idempotencyKey: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}idempotency_key'])!,
      deviceKeyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_key_id']),
      responseNonce: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}response_nonce']),
      verificationMode: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}verification_mode'])!,
      proximityTier: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}proximity_tier']),
      syncState: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_state'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AttendanceRecordsTableTable createAlias(String alias) {
    return $AttendanceRecordsTableTable(attachedDatabase, alias);
  }
}

class LocalAttendanceRecord extends DataClass
    implements Insertable<LocalAttendanceRecord> {
  /// Client-generated unique identifier (UUID v4).
  final String localId;

  /// Central backend attendance record UUID (nullable until confirmed by batch-sync).
  final String? serverId;

  /// Parent session local identifier.
  final String sessionId;

  /// Verified student identifier.
  final String studentId;

  /// Snapshot of student display name.
  final String studentName;

  /// Attendance status ('present', 'absent', 'inconclusive').
  final String status;

  /// Timestamp when verification occurred.
  final DateTime checkInTime;

  /// Deterministic idempotency key: 'att_${sessionId}_${deviceKeyId}_${responseNonce}'.
  final String idempotencyKey;

  /// Cryptographic device identity key ID used to sign the response.
  final String? deviceKeyId;

  /// Student challenge response nonce.
  final String? responseNonce;

  /// Verification mechanism ('BLE_BATCH', 'QR_FALLBACK', 'MANUAL').
  final String verificationMode;

  /// Proximity tier ('NEAR', 'FAR', 'FALLBACK_VERIFIED').
  final String? proximityTier;

  /// Synchronization state with backend ('pending', 'synced', 'failed').
  final String syncState;
  final DateTime createdAt;
  const LocalAttendanceRecord(
      {required this.localId,
      this.serverId,
      required this.sessionId,
      required this.studentId,
      required this.studentName,
      required this.status,
      required this.checkInTime,
      required this.idempotencyKey,
      this.deviceKeyId,
      this.responseNonce,
      required this.verificationMode,
      this.proximityTier,
      required this.syncState,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['session_id'] = Variable<String>(sessionId);
    map['student_id'] = Variable<String>(studentId);
    map['student_name'] = Variable<String>(studentName);
    map['status'] = Variable<String>(status);
    map['check_in_time'] = Variable<DateTime>(checkInTime);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    if (!nullToAbsent || deviceKeyId != null) {
      map['device_key_id'] = Variable<String>(deviceKeyId);
    }
    if (!nullToAbsent || responseNonce != null) {
      map['response_nonce'] = Variable<String>(responseNonce);
    }
    map['verification_mode'] = Variable<String>(verificationMode);
    if (!nullToAbsent || proximityTier != null) {
      map['proximity_tier'] = Variable<String>(proximityTier);
    }
    map['sync_state'] = Variable<String>(syncState);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AttendanceRecordsTableCompanion toCompanion(bool nullToAbsent) {
    return AttendanceRecordsTableCompanion(
      localId: Value(localId),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      sessionId: Value(sessionId),
      studentId: Value(studentId),
      studentName: Value(studentName),
      status: Value(status),
      checkInTime: Value(checkInTime),
      idempotencyKey: Value(idempotencyKey),
      deviceKeyId: deviceKeyId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceKeyId),
      responseNonce: responseNonce == null && nullToAbsent
          ? const Value.absent()
          : Value(responseNonce),
      verificationMode: Value(verificationMode),
      proximityTier: proximityTier == null && nullToAbsent
          ? const Value.absent()
          : Value(proximityTier),
      syncState: Value(syncState),
      createdAt: Value(createdAt),
    );
  }

  factory LocalAttendanceRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAttendanceRecord(
      localId: serializer.fromJson<String>(json['localId']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      studentId: serializer.fromJson<String>(json['studentId']),
      studentName: serializer.fromJson<String>(json['studentName']),
      status: serializer.fromJson<String>(json['status']),
      checkInTime: serializer.fromJson<DateTime>(json['checkInTime']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      deviceKeyId: serializer.fromJson<String?>(json['deviceKeyId']),
      responseNonce: serializer.fromJson<String?>(json['responseNonce']),
      verificationMode: serializer.fromJson<String>(json['verificationMode']),
      proximityTier: serializer.fromJson<String?>(json['proximityTier']),
      syncState: serializer.fromJson<String>(json['syncState']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'serverId': serializer.toJson<String?>(serverId),
      'sessionId': serializer.toJson<String>(sessionId),
      'studentId': serializer.toJson<String>(studentId),
      'studentName': serializer.toJson<String>(studentName),
      'status': serializer.toJson<String>(status),
      'checkInTime': serializer.toJson<DateTime>(checkInTime),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'deviceKeyId': serializer.toJson<String?>(deviceKeyId),
      'responseNonce': serializer.toJson<String?>(responseNonce),
      'verificationMode': serializer.toJson<String>(verificationMode),
      'proximityTier': serializer.toJson<String?>(proximityTier),
      'syncState': serializer.toJson<String>(syncState),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalAttendanceRecord copyWith(
          {String? localId,
          Value<String?> serverId = const Value.absent(),
          String? sessionId,
          String? studentId,
          String? studentName,
          String? status,
          DateTime? checkInTime,
          String? idempotencyKey,
          Value<String?> deviceKeyId = const Value.absent(),
          Value<String?> responseNonce = const Value.absent(),
          String? verificationMode,
          Value<String?> proximityTier = const Value.absent(),
          String? syncState,
          DateTime? createdAt}) =>
      LocalAttendanceRecord(
        localId: localId ?? this.localId,
        serverId: serverId.present ? serverId.value : this.serverId,
        sessionId: sessionId ?? this.sessionId,
        studentId: studentId ?? this.studentId,
        studentName: studentName ?? this.studentName,
        status: status ?? this.status,
        checkInTime: checkInTime ?? this.checkInTime,
        idempotencyKey: idempotencyKey ?? this.idempotencyKey,
        deviceKeyId: deviceKeyId.present ? deviceKeyId.value : this.deviceKeyId,
        responseNonce:
            responseNonce.present ? responseNonce.value : this.responseNonce,
        verificationMode: verificationMode ?? this.verificationMode,
        proximityTier:
            proximityTier.present ? proximityTier.value : this.proximityTier,
        syncState: syncState ?? this.syncState,
        createdAt: createdAt ?? this.createdAt,
      );
  LocalAttendanceRecord copyWithCompanion(
      AttendanceRecordsTableCompanion data) {
    return LocalAttendanceRecord(
      localId: data.localId.present ? data.localId.value : this.localId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      studentName:
          data.studentName.present ? data.studentName.value : this.studentName,
      status: data.status.present ? data.status.value : this.status,
      checkInTime:
          data.checkInTime.present ? data.checkInTime.value : this.checkInTime,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      deviceKeyId:
          data.deviceKeyId.present ? data.deviceKeyId.value : this.deviceKeyId,
      responseNonce: data.responseNonce.present
          ? data.responseNonce.value
          : this.responseNonce,
      verificationMode: data.verificationMode.present
          ? data.verificationMode.value
          : this.verificationMode,
      proximityTier: data.proximityTier.present
          ? data.proximityTier.value
          : this.proximityTier,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAttendanceRecord(')
          ..write('localId: $localId, ')
          ..write('serverId: $serverId, ')
          ..write('sessionId: $sessionId, ')
          ..write('studentId: $studentId, ')
          ..write('studentName: $studentName, ')
          ..write('status: $status, ')
          ..write('checkInTime: $checkInTime, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('deviceKeyId: $deviceKeyId, ')
          ..write('responseNonce: $responseNonce, ')
          ..write('verificationMode: $verificationMode, ')
          ..write('proximityTier: $proximityTier, ')
          ..write('syncState: $syncState, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      localId,
      serverId,
      sessionId,
      studentId,
      studentName,
      status,
      checkInTime,
      idempotencyKey,
      deviceKeyId,
      responseNonce,
      verificationMode,
      proximityTier,
      syncState,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAttendanceRecord &&
          other.localId == this.localId &&
          other.serverId == this.serverId &&
          other.sessionId == this.sessionId &&
          other.studentId == this.studentId &&
          other.studentName == this.studentName &&
          other.status == this.status &&
          other.checkInTime == this.checkInTime &&
          other.idempotencyKey == this.idempotencyKey &&
          other.deviceKeyId == this.deviceKeyId &&
          other.responseNonce == this.responseNonce &&
          other.verificationMode == this.verificationMode &&
          other.proximityTier == this.proximityTier &&
          other.syncState == this.syncState &&
          other.createdAt == this.createdAt);
}

class AttendanceRecordsTableCompanion
    extends UpdateCompanion<LocalAttendanceRecord> {
  final Value<String> localId;
  final Value<String?> serverId;
  final Value<String> sessionId;
  final Value<String> studentId;
  final Value<String> studentName;
  final Value<String> status;
  final Value<DateTime> checkInTime;
  final Value<String> idempotencyKey;
  final Value<String?> deviceKeyId;
  final Value<String?> responseNonce;
  final Value<String> verificationMode;
  final Value<String?> proximityTier;
  final Value<String> syncState;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AttendanceRecordsTableCompanion({
    this.localId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.studentId = const Value.absent(),
    this.studentName = const Value.absent(),
    this.status = const Value.absent(),
    this.checkInTime = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.deviceKeyId = const Value.absent(),
    this.responseNonce = const Value.absent(),
    this.verificationMode = const Value.absent(),
    this.proximityTier = const Value.absent(),
    this.syncState = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttendanceRecordsTableCompanion.insert({
    required String localId,
    this.serverId = const Value.absent(),
    required String sessionId,
    required String studentId,
    required String studentName,
    this.status = const Value.absent(),
    required DateTime checkInTime,
    required String idempotencyKey,
    this.deviceKeyId = const Value.absent(),
    this.responseNonce = const Value.absent(),
    this.verificationMode = const Value.absent(),
    this.proximityTier = const Value.absent(),
    this.syncState = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : localId = Value(localId),
        sessionId = Value(sessionId),
        studentId = Value(studentId),
        studentName = Value(studentName),
        checkInTime = Value(checkInTime),
        idempotencyKey = Value(idempotencyKey);
  static Insertable<LocalAttendanceRecord> custom({
    Expression<String>? localId,
    Expression<String>? serverId,
    Expression<String>? sessionId,
    Expression<String>? studentId,
    Expression<String>? studentName,
    Expression<String>? status,
    Expression<DateTime>? checkInTime,
    Expression<String>? idempotencyKey,
    Expression<String>? deviceKeyId,
    Expression<String>? responseNonce,
    Expression<String>? verificationMode,
    Expression<String>? proximityTier,
    Expression<String>? syncState,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (serverId != null) 'server_id': serverId,
      if (sessionId != null) 'session_id': sessionId,
      if (studentId != null) 'student_id': studentId,
      if (studentName != null) 'student_name': studentName,
      if (status != null) 'status': status,
      if (checkInTime != null) 'check_in_time': checkInTime,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (deviceKeyId != null) 'device_key_id': deviceKeyId,
      if (responseNonce != null) 'response_nonce': responseNonce,
      if (verificationMode != null) 'verification_mode': verificationMode,
      if (proximityTier != null) 'proximity_tier': proximityTier,
      if (syncState != null) 'sync_state': syncState,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttendanceRecordsTableCompanion copyWith(
      {Value<String>? localId,
      Value<String?>? serverId,
      Value<String>? sessionId,
      Value<String>? studentId,
      Value<String>? studentName,
      Value<String>? status,
      Value<DateTime>? checkInTime,
      Value<String>? idempotencyKey,
      Value<String?>? deviceKeyId,
      Value<String?>? responseNonce,
      Value<String>? verificationMode,
      Value<String?>? proximityTier,
      Value<String>? syncState,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return AttendanceRecordsTableCompanion(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      sessionId: sessionId ?? this.sessionId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      status: status ?? this.status,
      checkInTime: checkInTime ?? this.checkInTime,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      deviceKeyId: deviceKeyId ?? this.deviceKeyId,
      responseNonce: responseNonce ?? this.responseNonce,
      verificationMode: verificationMode ?? this.verificationMode,
      proximityTier: proximityTier ?? this.proximityTier,
      syncState: syncState ?? this.syncState,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (studentId.present) {
      map['student_id'] = Variable<String>(studentId.value);
    }
    if (studentName.present) {
      map['student_name'] = Variable<String>(studentName.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (checkInTime.present) {
      map['check_in_time'] = Variable<DateTime>(checkInTime.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (deviceKeyId.present) {
      map['device_key_id'] = Variable<String>(deviceKeyId.value);
    }
    if (responseNonce.present) {
      map['response_nonce'] = Variable<String>(responseNonce.value);
    }
    if (verificationMode.present) {
      map['verification_mode'] = Variable<String>(verificationMode.value);
    }
    if (proximityTier.present) {
      map['proximity_tier'] = Variable<String>(proximityTier.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceRecordsTableCompanion(')
          ..write('localId: $localId, ')
          ..write('serverId: $serverId, ')
          ..write('sessionId: $sessionId, ')
          ..write('studentId: $studentId, ')
          ..write('studentName: $studentName, ')
          ..write('status: $status, ')
          ..write('checkInTime: $checkInTime, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('deviceKeyId: $deviceKeyId, ')
          ..write('responseNonce: $responseNonce, ')
          ..write('verificationMode: $verificationMode, ')
          ..write('proximityTier: $proximityTier, ')
          ..write('syncState: $syncState, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTableTable extends SyncOutboxTable
    with TableInfo<$SyncOutboxTableTable, LocalOutboxOperation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta =
      const VerificationMeta('localId');
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
      'local_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
      'entity_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _endpointMeta =
      const VerificationMeta('endpoint');
  @override
  late final GeneratedColumn<String> endpoint = GeneratedColumn<String>(
      'endpoint', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
      'method', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('POST'));
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _idempotencyKeyMeta =
      const VerificationMeta('idempotencyKey');
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
      'idempotency_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _attemptCountMeta =
      const VerificationMeta('attemptCount');
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
      'attempt_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastAttemptedAtMeta =
      const VerificationMeta('lastAttemptedAt');
  @override
  late final GeneratedColumn<DateTime> lastAttemptedAt =
      GeneratedColumn<DateTime>('last_attempted_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _errorMessageMeta =
      const VerificationMeta('errorMessage');
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
      'error_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        localId,
        entityType,
        entityId,
        endpoint,
        method,
        payload,
        idempotencyKey,
        createdAt,
        attemptCount,
        lastAttemptedAt,
        status,
        errorMessage
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalOutboxOperation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(_localIdMeta,
          localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta));
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('endpoint')) {
      context.handle(_endpointMeta,
          endpoint.isAcceptableOrUnknown(data['endpoint']!, _endpointMeta));
    } else if (isInserting) {
      context.missing(_endpointMeta);
    }
    if (data.containsKey('method')) {
      context.handle(_methodMeta,
          method.isAcceptableOrUnknown(data['method']!, _methodMeta));
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
          _idempotencyKeyMeta,
          idempotencyKey.isAcceptableOrUnknown(
              data['idempotency_key']!, _idempotencyKeyMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
          _attemptCountMeta,
          attemptCount.isAcceptableOrUnknown(
              data['attempt_count']!, _attemptCountMeta));
    }
    if (data.containsKey('last_attempted_at')) {
      context.handle(
          _lastAttemptedAtMeta,
          lastAttemptedAt.isAcceptableOrUnknown(
              data['last_attempted_at']!, _lastAttemptedAtMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('error_message')) {
      context.handle(
          _errorMessageMeta,
          errorMessage.isAcceptableOrUnknown(
              data['error_message']!, _errorMessageMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  LocalOutboxOperation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalOutboxOperation(
      localId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_id'])!,
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id'])!,
      endpoint: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}endpoint'])!,
      method: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}method'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      idempotencyKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}idempotency_key']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      attemptCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempt_count'])!,
      lastAttemptedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_attempted_at']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      errorMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_message']),
    );
  }

  @override
  $SyncOutboxTableTable createAlias(String alias) {
    return $SyncOutboxTableTable(attachedDatabase, alias);
  }
}

class LocalOutboxOperation extends DataClass
    implements Insertable<LocalOutboxOperation> {
  /// Client operation UUID.
  final String localId;

  /// Entity category ('attendance', 'session').
  final String entityType;

  /// Local identifier of the affected domain entity.
  final String entityId;

  /// Target REST API endpoint path (e.g. '/attendance/batch-sync').
  final String endpoint;

  /// HTTP verb ('POST', 'PUT', 'DELETE').
  final String method;

  /// Serialized request body payload (canonical JSON string).
  final String payload;

  /// Client idempotency key for network replay safety.
  final String? idempotencyKey;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Number of transmission attempts.
  final int attemptCount;

  /// Timestamp of the most recent transmission attempt.
  final DateTime? lastAttemptedAt;

  /// Operation synchronization status ('pending', 'in_progress', 'completed', 'failed').
  final String status;

  /// Last error message encountered during synchronization.
  final String? errorMessage;
  const LocalOutboxOperation(
      {required this.localId,
      required this.entityType,
      required this.entityId,
      required this.endpoint,
      required this.method,
      required this.payload,
      this.idempotencyKey,
      required this.createdAt,
      required this.attemptCount,
      this.lastAttemptedAt,
      required this.status,
      this.errorMessage});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['endpoint'] = Variable<String>(endpoint);
    map['method'] = Variable<String>(method);
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || idempotencyKey != null) {
      map['idempotency_key'] = Variable<String>(idempotencyKey);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastAttemptedAt != null) {
      map['last_attempted_at'] = Variable<DateTime>(lastAttemptedAt);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    return map;
  }

  SyncOutboxTableCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxTableCompanion(
      localId: Value(localId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      endpoint: Value(endpoint),
      method: Value(method),
      payload: Value(payload),
      idempotencyKey: idempotencyKey == null && nullToAbsent
          ? const Value.absent()
          : Value(idempotencyKey),
      createdAt: Value(createdAt),
      attemptCount: Value(attemptCount),
      lastAttemptedAt: lastAttemptedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptedAt),
      status: Value(status),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
    );
  }

  factory LocalOutboxOperation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalOutboxOperation(
      localId: serializer.fromJson<String>(json['localId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      endpoint: serializer.fromJson<String>(json['endpoint']),
      method: serializer.fromJson<String>(json['method']),
      payload: serializer.fromJson<String>(json['payload']),
      idempotencyKey: serializer.fromJson<String?>(json['idempotencyKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastAttemptedAt: serializer.fromJson<DateTime?>(json['lastAttemptedAt']),
      status: serializer.fromJson<String>(json['status']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'endpoint': serializer.toJson<String>(endpoint),
      'method': serializer.toJson<String>(method),
      'payload': serializer.toJson<String>(payload),
      'idempotencyKey': serializer.toJson<String?>(idempotencyKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastAttemptedAt': serializer.toJson<DateTime?>(lastAttemptedAt),
      'status': serializer.toJson<String>(status),
      'errorMessage': serializer.toJson<String?>(errorMessage),
    };
  }

  LocalOutboxOperation copyWith(
          {String? localId,
          String? entityType,
          String? entityId,
          String? endpoint,
          String? method,
          String? payload,
          Value<String?> idempotencyKey = const Value.absent(),
          DateTime? createdAt,
          int? attemptCount,
          Value<DateTime?> lastAttemptedAt = const Value.absent(),
          String? status,
          Value<String?> errorMessage = const Value.absent()}) =>
      LocalOutboxOperation(
        localId: localId ?? this.localId,
        entityType: entityType ?? this.entityType,
        entityId: entityId ?? this.entityId,
        endpoint: endpoint ?? this.endpoint,
        method: method ?? this.method,
        payload: payload ?? this.payload,
        idempotencyKey:
            idempotencyKey.present ? idempotencyKey.value : this.idempotencyKey,
        createdAt: createdAt ?? this.createdAt,
        attemptCount: attemptCount ?? this.attemptCount,
        lastAttemptedAt: lastAttemptedAt.present
            ? lastAttemptedAt.value
            : this.lastAttemptedAt,
        status: status ?? this.status,
        errorMessage:
            errorMessage.present ? errorMessage.value : this.errorMessage,
      );
  LocalOutboxOperation copyWithCompanion(SyncOutboxTableCompanion data) {
    return LocalOutboxOperation(
      localId: data.localId.present ? data.localId.value : this.localId,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      endpoint: data.endpoint.present ? data.endpoint.value : this.endpoint,
      method: data.method.present ? data.method.value : this.method,
      payload: data.payload.present ? data.payload.value : this.payload,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastAttemptedAt: data.lastAttemptedAt.present
          ? data.lastAttemptedAt.value
          : this.lastAttemptedAt,
      status: data.status.present ? data.status.value : this.status,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalOutboxOperation(')
          ..write('localId: $localId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('endpoint: $endpoint, ')
          ..write('method: $method, ')
          ..write('payload: $payload, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastAttemptedAt: $lastAttemptedAt, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      localId,
      entityType,
      entityId,
      endpoint,
      method,
      payload,
      idempotencyKey,
      createdAt,
      attemptCount,
      lastAttemptedAt,
      status,
      errorMessage);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalOutboxOperation &&
          other.localId == this.localId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.endpoint == this.endpoint &&
          other.method == this.method &&
          other.payload == this.payload &&
          other.idempotencyKey == this.idempotencyKey &&
          other.createdAt == this.createdAt &&
          other.attemptCount == this.attemptCount &&
          other.lastAttemptedAt == this.lastAttemptedAt &&
          other.status == this.status &&
          other.errorMessage == this.errorMessage);
}

class SyncOutboxTableCompanion extends UpdateCompanion<LocalOutboxOperation> {
  final Value<String> localId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> endpoint;
  final Value<String> method;
  final Value<String> payload;
  final Value<String?> idempotencyKey;
  final Value<DateTime> createdAt;
  final Value<int> attemptCount;
  final Value<DateTime?> lastAttemptedAt;
  final Value<String> status;
  final Value<String?> errorMessage;
  final Value<int> rowid;
  const SyncOutboxTableCompanion({
    this.localId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.endpoint = const Value.absent(),
    this.method = const Value.absent(),
    this.payload = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastAttemptedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOutboxTableCompanion.insert({
    required String localId,
    required String entityType,
    required String entityId,
    required String endpoint,
    this.method = const Value.absent(),
    required String payload,
    this.idempotencyKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastAttemptedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : localId = Value(localId),
        entityType = Value(entityType),
        entityId = Value(entityId),
        endpoint = Value(endpoint),
        payload = Value(payload);
  static Insertable<LocalOutboxOperation> custom({
    Expression<String>? localId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? endpoint,
    Expression<String>? method,
    Expression<String>? payload,
    Expression<String>? idempotencyKey,
    Expression<DateTime>? createdAt,
    Expression<int>? attemptCount,
    Expression<DateTime>? lastAttemptedAt,
    Expression<String>? status,
    Expression<String>? errorMessage,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (endpoint != null) 'endpoint': endpoint,
      if (method != null) 'method': method,
      if (payload != null) 'payload': payload,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (createdAt != null) 'created_at': createdAt,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastAttemptedAt != null) 'last_attempted_at': lastAttemptedAt,
      if (status != null) 'status': status,
      if (errorMessage != null) 'error_message': errorMessage,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOutboxTableCompanion copyWith(
      {Value<String>? localId,
      Value<String>? entityType,
      Value<String>? entityId,
      Value<String>? endpoint,
      Value<String>? method,
      Value<String>? payload,
      Value<String?>? idempotencyKey,
      Value<DateTime>? createdAt,
      Value<int>? attemptCount,
      Value<DateTime?>? lastAttemptedAt,
      Value<String>? status,
      Value<String?>? errorMessage,
      Value<int>? rowid}) {
    return SyncOutboxTableCompanion(
      localId: localId ?? this.localId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      endpoint: endpoint ?? this.endpoint,
      method: method ?? this.method,
      payload: payload ?? this.payload,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      createdAt: createdAt ?? this.createdAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastAttemptedAt: lastAttemptedAt ?? this.lastAttemptedAt,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (endpoint.present) {
      map['endpoint'] = Variable<String>(endpoint.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastAttemptedAt.present) {
      map['last_attempted_at'] = Variable<DateTime>(lastAttemptedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxTableCompanion(')
          ..write('localId: $localId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('endpoint: $endpoint, ')
          ..write('method: $method, ')
          ..write('payload: $payload, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastAttemptedAt: $lastAttemptedAt, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ComplaintsTableTable extends ComplaintsTable
    with TableInfo<$ComplaintsTableTable, LocalComplaint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ComplaintsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta =
      const VerificationMeta('localId');
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
      'local_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serverIdMeta =
      const VerificationMeta('serverId');
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
      'server_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _idempotencyKeyMeta =
      const VerificationMeta('idempotencyKey');
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
      'idempotency_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _studentIdMeta =
      const VerificationMeta('studentId');
  @override
  late final GeneratedColumn<String> studentId = GeneratedColumn<String>(
      'student_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _locationMeta =
      const VerificationMeta('location');
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
      'location', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Campus'));
  static const VerificationMeta _priorityMeta =
      const VerificationMeta('priority');
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
      'priority', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('MEDIUM'));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('PENDING'));
  static const VerificationMeta _syncStateMeta =
      const VerificationMeta('syncState');
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
      'sync_state', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _assignedToMeta =
      const VerificationMeta('assignedTo');
  @override
  late final GeneratedColumn<String> assignedTo = GeneratedColumn<String>(
      'assigned_to', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _assignedToNameMeta =
      const VerificationMeta('assignedToName');
  @override
  late final GeneratedColumn<String> assignedToName = GeneratedColumn<String>(
      'assigned_to_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _resolutionRemarksMeta =
      const VerificationMeta('resolutionRemarks');
  @override
  late final GeneratedColumn<String> resolutionRemarks =
      GeneratedColumn<String>('resolution_remarks', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _resolvedAtMeta =
      const VerificationMeta('resolvedAt');
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
      'resolved_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _serverCreatedAtMeta =
      const VerificationMeta('serverCreatedAt');
  @override
  late final GeneratedColumn<DateTime> serverCreatedAt =
      GeneratedColumn<DateTime>('server_created_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _isRepeatMeta =
      const VerificationMeta('isRepeat');
  @override
  late final GeneratedColumn<bool> isRepeat = GeneratedColumn<bool>(
      'is_repeat', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_repeat" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        localId,
        serverId,
        idempotencyKey,
        studentId,
        category,
        title,
        description,
        location,
        priority,
        status,
        syncState,
        assignedTo,
        assignedToName,
        resolutionRemarks,
        resolvedAt,
        createdAt,
        serverCreatedAt,
        updatedAt,
        isRepeat
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'complaints';
  @override
  VerificationContext validateIntegrity(Insertable<LocalComplaint> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(_localIdMeta,
          localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta));
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(_serverIdMeta,
          serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta));
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
          _idempotencyKeyMeta,
          idempotencyKey.isAcceptableOrUnknown(
              data['idempotency_key']!, _idempotencyKeyMeta));
    }
    if (data.containsKey('student_id')) {
      context.handle(_studentIdMeta,
          studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta));
    } else if (isInserting) {
      context.missing(_studentIdMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('location')) {
      context.handle(_locationMeta,
          location.isAcceptableOrUnknown(data['location']!, _locationMeta));
    }
    if (data.containsKey('priority')) {
      context.handle(_priorityMeta,
          priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('sync_state')) {
      context.handle(_syncStateMeta,
          syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta));
    }
    if (data.containsKey('assigned_to')) {
      context.handle(
          _assignedToMeta,
          assignedTo.isAcceptableOrUnknown(
              data['assigned_to']!, _assignedToMeta));
    }
    if (data.containsKey('assigned_to_name')) {
      context.handle(
          _assignedToNameMeta,
          assignedToName.isAcceptableOrUnknown(
              data['assigned_to_name']!, _assignedToNameMeta));
    }
    if (data.containsKey('resolution_remarks')) {
      context.handle(
          _resolutionRemarksMeta,
          resolutionRemarks.isAcceptableOrUnknown(
              data['resolution_remarks']!, _resolutionRemarksMeta));
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
          _resolvedAtMeta,
          resolvedAt.isAcceptableOrUnknown(
              data['resolved_at']!, _resolvedAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('server_created_at')) {
      context.handle(
          _serverCreatedAtMeta,
          serverCreatedAt.isAcceptableOrUnknown(
              data['server_created_at']!, _serverCreatedAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('is_repeat')) {
      context.handle(_isRepeatMeta,
          isRepeat.isAcceptableOrUnknown(data['is_repeat']!, _isRepeatMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  LocalComplaint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalComplaint(
      localId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_id'])!,
      serverId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_id']),
      idempotencyKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}idempotency_key']),
      studentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}student_id'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      location: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location'])!,
      priority: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}priority'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      syncState: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_state'])!,
      assignedTo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}assigned_to']),
      assignedToName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}assigned_to_name']),
      resolutionRemarks: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}resolution_remarks']),
      resolvedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}resolved_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      serverCreatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}server_created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
      isRepeat: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_repeat'])!,
    );
  }

  @override
  $ComplaintsTableTable createAlias(String alias) {
    return $ComplaintsTableTable(attachedDatabase, alias);
  }
}

class LocalComplaint extends DataClass implements Insertable<LocalComplaint> {
  /// Client primary key UUID.
  final String localId;

  /// Server UUID once acknowledged.
  final String? serverId;

  /// Client idempotency key for network replay safety.
  final String? idempotencyKey;

  /// Associated student/user ID.
  final String studentId;

  /// Category (e.g. 'Hostel/Room', 'Mess', etc.).
  final String category;

  /// Issue title.
  final String title;

  /// Issue detailed description.
  final String description;

  /// Location on campus.
  final String location;

  /// Priority ('LOW', 'MEDIUM', 'HIGH', 'URGENT').
  final String priority;

  /// Current workflow status ('PENDING', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED', 'CLOSED', 'REOPENED', 'REJECTED').
  final String status;

  /// Local sync lifecycle state ('pending', 'synced', 'failed').
  final String syncState;

  /// Staff ID assigned to resolve this issue.
  final String? assignedTo;

  /// Staff name assigned to resolve this issue.
  final String? assignedToName;

  /// Admin/Staff resolution notes or remarks.
  final String? resolutionRemarks;

  /// Timestamp when resolved.
  final DateTime? resolvedAt;

  /// Local creation timestamp.
  final DateTime createdAt;

  /// Server creation timestamp (when synced or cached from server).
  final DateTime? serverCreatedAt;

  /// Last updated timestamp.
  final DateTime? updatedAt;

  /// Repeat issue flag.
  final bool isRepeat;
  const LocalComplaint(
      {required this.localId,
      this.serverId,
      this.idempotencyKey,
      required this.studentId,
      required this.category,
      required this.title,
      required this.description,
      required this.location,
      required this.priority,
      required this.status,
      required this.syncState,
      this.assignedTo,
      this.assignedToName,
      this.resolutionRemarks,
      this.resolvedAt,
      required this.createdAt,
      this.serverCreatedAt,
      this.updatedAt,
      required this.isRepeat});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    if (!nullToAbsent || idempotencyKey != null) {
      map['idempotency_key'] = Variable<String>(idempotencyKey);
    }
    map['student_id'] = Variable<String>(studentId);
    map['category'] = Variable<String>(category);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['location'] = Variable<String>(location);
    map['priority'] = Variable<String>(priority);
    map['status'] = Variable<String>(status);
    map['sync_state'] = Variable<String>(syncState);
    if (!nullToAbsent || assignedTo != null) {
      map['assigned_to'] = Variable<String>(assignedTo);
    }
    if (!nullToAbsent || assignedToName != null) {
      map['assigned_to_name'] = Variable<String>(assignedToName);
    }
    if (!nullToAbsent || resolutionRemarks != null) {
      map['resolution_remarks'] = Variable<String>(resolutionRemarks);
    }
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || serverCreatedAt != null) {
      map['server_created_at'] = Variable<DateTime>(serverCreatedAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['is_repeat'] = Variable<bool>(isRepeat);
    return map;
  }

  ComplaintsTableCompanion toCompanion(bool nullToAbsent) {
    return ComplaintsTableCompanion(
      localId: Value(localId),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      idempotencyKey: idempotencyKey == null && nullToAbsent
          ? const Value.absent()
          : Value(idempotencyKey),
      studentId: Value(studentId),
      category: Value(category),
      title: Value(title),
      description: Value(description),
      location: Value(location),
      priority: Value(priority),
      status: Value(status),
      syncState: Value(syncState),
      assignedTo: assignedTo == null && nullToAbsent
          ? const Value.absent()
          : Value(assignedTo),
      assignedToName: assignedToName == null && nullToAbsent
          ? const Value.absent()
          : Value(assignedToName),
      resolutionRemarks: resolutionRemarks == null && nullToAbsent
          ? const Value.absent()
          : Value(resolutionRemarks),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
      createdAt: Value(createdAt),
      serverCreatedAt: serverCreatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverCreatedAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      isRepeat: Value(isRepeat),
    );
  }

  factory LocalComplaint.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalComplaint(
      localId: serializer.fromJson<String>(json['localId']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      idempotencyKey: serializer.fromJson<String?>(json['idempotencyKey']),
      studentId: serializer.fromJson<String>(json['studentId']),
      category: serializer.fromJson<String>(json['category']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      location: serializer.fromJson<String>(json['location']),
      priority: serializer.fromJson<String>(json['priority']),
      status: serializer.fromJson<String>(json['status']),
      syncState: serializer.fromJson<String>(json['syncState']),
      assignedTo: serializer.fromJson<String?>(json['assignedTo']),
      assignedToName: serializer.fromJson<String?>(json['assignedToName']),
      resolutionRemarks:
          serializer.fromJson<String?>(json['resolutionRemarks']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      serverCreatedAt: serializer.fromJson<DateTime?>(json['serverCreatedAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      isRepeat: serializer.fromJson<bool>(json['isRepeat']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'serverId': serializer.toJson<String?>(serverId),
      'idempotencyKey': serializer.toJson<String?>(idempotencyKey),
      'studentId': serializer.toJson<String>(studentId),
      'category': serializer.toJson<String>(category),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'location': serializer.toJson<String>(location),
      'priority': serializer.toJson<String>(priority),
      'status': serializer.toJson<String>(status),
      'syncState': serializer.toJson<String>(syncState),
      'assignedTo': serializer.toJson<String?>(assignedTo),
      'assignedToName': serializer.toJson<String?>(assignedToName),
      'resolutionRemarks': serializer.toJson<String?>(resolutionRemarks),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'serverCreatedAt': serializer.toJson<DateTime?>(serverCreatedAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'isRepeat': serializer.toJson<bool>(isRepeat),
    };
  }

  LocalComplaint copyWith(
          {String? localId,
          Value<String?> serverId = const Value.absent(),
          Value<String?> idempotencyKey = const Value.absent(),
          String? studentId,
          String? category,
          String? title,
          String? description,
          String? location,
          String? priority,
          String? status,
          String? syncState,
          Value<String?> assignedTo = const Value.absent(),
          Value<String?> assignedToName = const Value.absent(),
          Value<String?> resolutionRemarks = const Value.absent(),
          Value<DateTime?> resolvedAt = const Value.absent(),
          DateTime? createdAt,
          Value<DateTime?> serverCreatedAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent(),
          bool? isRepeat}) =>
      LocalComplaint(
        localId: localId ?? this.localId,
        serverId: serverId.present ? serverId.value : this.serverId,
        idempotencyKey:
            idempotencyKey.present ? idempotencyKey.value : this.idempotencyKey,
        studentId: studentId ?? this.studentId,
        category: category ?? this.category,
        title: title ?? this.title,
        description: description ?? this.description,
        location: location ?? this.location,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        syncState: syncState ?? this.syncState,
        assignedTo: assignedTo.present ? assignedTo.value : this.assignedTo,
        assignedToName:
            assignedToName.present ? assignedToName.value : this.assignedToName,
        resolutionRemarks: resolutionRemarks.present
            ? resolutionRemarks.value
            : this.resolutionRemarks,
        resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
        createdAt: createdAt ?? this.createdAt,
        serverCreatedAt: serverCreatedAt.present
            ? serverCreatedAt.value
            : this.serverCreatedAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
        isRepeat: isRepeat ?? this.isRepeat,
      );
  LocalComplaint copyWithCompanion(ComplaintsTableCompanion data) {
    return LocalComplaint(
      localId: data.localId.present ? data.localId.value : this.localId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      category: data.category.present ? data.category.value : this.category,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      location: data.location.present ? data.location.value : this.location,
      priority: data.priority.present ? data.priority.value : this.priority,
      status: data.status.present ? data.status.value : this.status,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      assignedTo:
          data.assignedTo.present ? data.assignedTo.value : this.assignedTo,
      assignedToName: data.assignedToName.present
          ? data.assignedToName.value
          : this.assignedToName,
      resolutionRemarks: data.resolutionRemarks.present
          ? data.resolutionRemarks.value
          : this.resolutionRemarks,
      resolvedAt:
          data.resolvedAt.present ? data.resolvedAt.value : this.resolvedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      serverCreatedAt: data.serverCreatedAt.present
          ? data.serverCreatedAt.value
          : this.serverCreatedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isRepeat: data.isRepeat.present ? data.isRepeat.value : this.isRepeat,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalComplaint(')
          ..write('localId: $localId, ')
          ..write('serverId: $serverId, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('studentId: $studentId, ')
          ..write('category: $category, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('location: $location, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('syncState: $syncState, ')
          ..write('assignedTo: $assignedTo, ')
          ..write('assignedToName: $assignedToName, ')
          ..write('resolutionRemarks: $resolutionRemarks, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('serverCreatedAt: $serverCreatedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isRepeat: $isRepeat')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      localId,
      serverId,
      idempotencyKey,
      studentId,
      category,
      title,
      description,
      location,
      priority,
      status,
      syncState,
      assignedTo,
      assignedToName,
      resolutionRemarks,
      resolvedAt,
      createdAt,
      serverCreatedAt,
      updatedAt,
      isRepeat);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalComplaint &&
          other.localId == this.localId &&
          other.serverId == this.serverId &&
          other.idempotencyKey == this.idempotencyKey &&
          other.studentId == this.studentId &&
          other.category == this.category &&
          other.title == this.title &&
          other.description == this.description &&
          other.location == this.location &&
          other.priority == this.priority &&
          other.status == this.status &&
          other.syncState == this.syncState &&
          other.assignedTo == this.assignedTo &&
          other.assignedToName == this.assignedToName &&
          other.resolutionRemarks == this.resolutionRemarks &&
          other.resolvedAt == this.resolvedAt &&
          other.createdAt == this.createdAt &&
          other.serverCreatedAt == this.serverCreatedAt &&
          other.updatedAt == this.updatedAt &&
          other.isRepeat == this.isRepeat);
}

class ComplaintsTableCompanion extends UpdateCompanion<LocalComplaint> {
  final Value<String> localId;
  final Value<String?> serverId;
  final Value<String?> idempotencyKey;
  final Value<String> studentId;
  final Value<String> category;
  final Value<String> title;
  final Value<String> description;
  final Value<String> location;
  final Value<String> priority;
  final Value<String> status;
  final Value<String> syncState;
  final Value<String?> assignedTo;
  final Value<String?> assignedToName;
  final Value<String?> resolutionRemarks;
  final Value<DateTime?> resolvedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime?> serverCreatedAt;
  final Value<DateTime?> updatedAt;
  final Value<bool> isRepeat;
  final Value<int> rowid;
  const ComplaintsTableCompanion({
    this.localId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.studentId = const Value.absent(),
    this.category = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.location = const Value.absent(),
    this.priority = const Value.absent(),
    this.status = const Value.absent(),
    this.syncState = const Value.absent(),
    this.assignedTo = const Value.absent(),
    this.assignedToName = const Value.absent(),
    this.resolutionRemarks = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.serverCreatedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isRepeat = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ComplaintsTableCompanion.insert({
    required String localId,
    this.serverId = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    required String studentId,
    required String category,
    required String title,
    required String description,
    this.location = const Value.absent(),
    this.priority = const Value.absent(),
    this.status = const Value.absent(),
    this.syncState = const Value.absent(),
    this.assignedTo = const Value.absent(),
    this.assignedToName = const Value.absent(),
    this.resolutionRemarks = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.serverCreatedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isRepeat = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : localId = Value(localId),
        studentId = Value(studentId),
        category = Value(category),
        title = Value(title),
        description = Value(description);
  static Insertable<LocalComplaint> custom({
    Expression<String>? localId,
    Expression<String>? serverId,
    Expression<String>? idempotencyKey,
    Expression<String>? studentId,
    Expression<String>? category,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? location,
    Expression<String>? priority,
    Expression<String>? status,
    Expression<String>? syncState,
    Expression<String>? assignedTo,
    Expression<String>? assignedToName,
    Expression<String>? resolutionRemarks,
    Expression<DateTime>? resolvedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? serverCreatedAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isRepeat,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (serverId != null) 'server_id': serverId,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (studentId != null) 'student_id': studentId,
      if (category != null) 'category': category,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (location != null) 'location': location,
      if (priority != null) 'priority': priority,
      if (status != null) 'status': status,
      if (syncState != null) 'sync_state': syncState,
      if (assignedTo != null) 'assigned_to': assignedTo,
      if (assignedToName != null) 'assigned_to_name': assignedToName,
      if (resolutionRemarks != null) 'resolution_remarks': resolutionRemarks,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (serverCreatedAt != null) 'server_created_at': serverCreatedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isRepeat != null) 'is_repeat': isRepeat,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ComplaintsTableCompanion copyWith(
      {Value<String>? localId,
      Value<String?>? serverId,
      Value<String?>? idempotencyKey,
      Value<String>? studentId,
      Value<String>? category,
      Value<String>? title,
      Value<String>? description,
      Value<String>? location,
      Value<String>? priority,
      Value<String>? status,
      Value<String>? syncState,
      Value<String?>? assignedTo,
      Value<String?>? assignedToName,
      Value<String?>? resolutionRemarks,
      Value<DateTime?>? resolvedAt,
      Value<DateTime>? createdAt,
      Value<DateTime?>? serverCreatedAt,
      Value<DateTime?>? updatedAt,
      Value<bool>? isRepeat,
      Value<int>? rowid}) {
    return ComplaintsTableCompanion(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      studentId: studentId ?? this.studentId,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      syncState: syncState ?? this.syncState,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      resolutionRemarks: resolutionRemarks ?? this.resolutionRemarks,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
      serverCreatedAt: serverCreatedAt ?? this.serverCreatedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isRepeat: isRepeat ?? this.isRepeat,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (studentId.present) {
      map['student_id'] = Variable<String>(studentId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (assignedTo.present) {
      map['assigned_to'] = Variable<String>(assignedTo.value);
    }
    if (assignedToName.present) {
      map['assigned_to_name'] = Variable<String>(assignedToName.value);
    }
    if (resolutionRemarks.present) {
      map['resolution_remarks'] = Variable<String>(resolutionRemarks.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (serverCreatedAt.present) {
      map['server_created_at'] = Variable<DateTime>(serverCreatedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isRepeat.present) {
      map['is_repeat'] = Variable<bool>(isRepeat.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ComplaintsTableCompanion(')
          ..write('localId: $localId, ')
          ..write('serverId: $serverId, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('studentId: $studentId, ')
          ..write('category: $category, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('location: $location, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('syncState: $syncState, ')
          ..write('assignedTo: $assignedTo, ')
          ..write('assignedToName: $assignedToName, ')
          ..write('resolutionRemarks: $resolutionRemarks, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('serverCreatedAt: $serverCreatedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isRepeat: $isRepeat, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SessionsTableTable sessionsTable = $SessionsTableTable(this);
  late final $StudentsTableTable studentsTable = $StudentsTableTable(this);
  late final $ClassesTableTable classesTable = $ClassesTableTable(this);
  late final $EnrollmentsTableTable enrollmentsTable =
      $EnrollmentsTableTable(this);
  late final $AttendanceRecordsTableTable attendanceRecordsTable =
      $AttendanceRecordsTableTable(this);
  late final $SyncOutboxTableTable syncOutboxTable =
      $SyncOutboxTableTable(this);
  late final $ComplaintsTableTable complaintsTable =
      $ComplaintsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        sessionsTable,
        studentsTable,
        classesTable,
        enrollmentsTable,
        attendanceRecordsTable,
        syncOutboxTable,
        complaintsTable
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('classes',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('enrollments', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('students',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('enrollments', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('sessions',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('attendance_records', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('students',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('attendance_records', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$SessionsTableTableCreateCompanionBuilder = SessionsTableCompanion
    Function({
  required String localId,
  Value<String?> serverId,
  required String teacherId,
  Value<String?> classId,
  required String name,
  Value<String?> course,
  Value<String?> branch,
  Value<String?> year,
  Value<String> location,
  required DateTime startTime,
  required DateTime endTime,
  Value<bool> isActive,
  Value<int?> txPowerLevel,
  Value<String?> sessionNonce,
  Value<int> attendanceCount,
  Value<String> syncState,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$SessionsTableTableUpdateCompanionBuilder = SessionsTableCompanion
    Function({
  Value<String> localId,
  Value<String?> serverId,
  Value<String> teacherId,
  Value<String?> classId,
  Value<String> name,
  Value<String?> course,
  Value<String?> branch,
  Value<String?> year,
  Value<String> location,
  Value<DateTime> startTime,
  Value<DateTime> endTime,
  Value<bool> isActive,
  Value<int?> txPowerLevel,
  Value<String?> sessionNonce,
  Value<int> attendanceCount,
  Value<String> syncState,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$SessionsTableTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTableTable, LocalSession> {
  $$SessionsTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AttendanceRecordsTableTable,
      List<LocalAttendanceRecord>> _attendanceRecordsTableRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.attendanceRecordsTable,
          aliasName: $_aliasNameGenerator(
              db.sessionsTable.localId, db.attendanceRecordsTable.sessionId));

  $$AttendanceRecordsTableTableProcessedTableManager
      get attendanceRecordsTableRefs {
    final manager = $$AttendanceRecordsTableTableTableManager(
            $_db, $_db.attendanceRecordsTable)
        .filter((f) =>
            f.sessionId.localId.sqlEquals($_itemColumn<String>('local_id')!));

    final cache =
        $_typedResult.readTableOrNull(_attendanceRecordsTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SessionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTableTable> {
  $$SessionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localId => $composableBuilder(
      column: $table.localId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get teacherId => $composableBuilder(
      column: $table.teacherId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get classId => $composableBuilder(
      column: $table.classId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get course => $composableBuilder(
      column: $table.course, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get branch => $composableBuilder(
      column: $table.branch, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get year => $composableBuilder(
      column: $table.year, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startTime => $composableBuilder(
      column: $table.startTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endTime => $composableBuilder(
      column: $table.endTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get txPowerLevel => $composableBuilder(
      column: $table.txPowerLevel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sessionNonce => $composableBuilder(
      column: $table.sessionNonce, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attendanceCount => $composableBuilder(
      column: $table.attendanceCount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncState => $composableBuilder(
      column: $table.syncState, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> attendanceRecordsTableRefs(
      Expression<bool> Function($$AttendanceRecordsTableTableFilterComposer f)
          f) {
    final $$AttendanceRecordsTableTableFilterComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.localId,
            referencedTable: $db.attendanceRecordsTable,
            getReferencedColumn: (t) => t.sessionId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$AttendanceRecordsTableTableFilterComposer(
                  $db: $db,
                  $table: $db.attendanceRecordsTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$SessionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTableTable> {
  $$SessionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localId => $composableBuilder(
      column: $table.localId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get teacherId => $composableBuilder(
      column: $table.teacherId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get classId => $composableBuilder(
      column: $table.classId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get course => $composableBuilder(
      column: $table.course, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get branch => $composableBuilder(
      column: $table.branch, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get year => $composableBuilder(
      column: $table.year, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
      column: $table.startTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endTime => $composableBuilder(
      column: $table.endTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get txPowerLevel => $composableBuilder(
      column: $table.txPowerLevel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sessionNonce => $composableBuilder(
      column: $table.sessionNonce,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attendanceCount => $composableBuilder(
      column: $table.attendanceCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncState => $composableBuilder(
      column: $table.syncState, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SessionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTableTable> {
  $$SessionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get teacherId =>
      $composableBuilder(column: $table.teacherId, builder: (column) => column);

  GeneratedColumn<String> get classId =>
      $composableBuilder(column: $table.classId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get course =>
      $composableBuilder(column: $table.course, builder: (column) => column);

  GeneratedColumn<String> get branch =>
      $composableBuilder(column: $table.branch, builder: (column) => column);

  GeneratedColumn<String> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<DateTime> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get txPowerLevel => $composableBuilder(
      column: $table.txPowerLevel, builder: (column) => column);

  GeneratedColumn<String> get sessionNonce => $composableBuilder(
      column: $table.sessionNonce, builder: (column) => column);

  GeneratedColumn<int> get attendanceCount => $composableBuilder(
      column: $table.attendanceCount, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> attendanceRecordsTableRefs<T extends Object>(
      Expression<T> Function($$AttendanceRecordsTableTableAnnotationComposer a)
          f) {
    final $$AttendanceRecordsTableTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.localId,
            referencedTable: $db.attendanceRecordsTable,
            getReferencedColumn: (t) => t.sessionId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$AttendanceRecordsTableTableAnnotationComposer(
                  $db: $db,
                  $table: $db.attendanceRecordsTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$SessionsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionsTableTable,
    LocalSession,
    $$SessionsTableTableFilterComposer,
    $$SessionsTableTableOrderingComposer,
    $$SessionsTableTableAnnotationComposer,
    $$SessionsTableTableCreateCompanionBuilder,
    $$SessionsTableTableUpdateCompanionBuilder,
    (LocalSession, $$SessionsTableTableReferences),
    LocalSession,
    PrefetchHooks Function({bool attendanceRecordsTableRefs})> {
  $$SessionsTableTableTableManager(_$AppDatabase db, $SessionsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> localId = const Value.absent(),
            Value<String?> serverId = const Value.absent(),
            Value<String> teacherId = const Value.absent(),
            Value<String?> classId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> course = const Value.absent(),
            Value<String?> branch = const Value.absent(),
            Value<String?> year = const Value.absent(),
            Value<String> location = const Value.absent(),
            Value<DateTime> startTime = const Value.absent(),
            Value<DateTime> endTime = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<int?> txPowerLevel = const Value.absent(),
            Value<String?> sessionNonce = const Value.absent(),
            Value<int> attendanceCount = const Value.absent(),
            Value<String> syncState = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionsTableCompanion(
            localId: localId,
            serverId: serverId,
            teacherId: teacherId,
            classId: classId,
            name: name,
            course: course,
            branch: branch,
            year: year,
            location: location,
            startTime: startTime,
            endTime: endTime,
            isActive: isActive,
            txPowerLevel: txPowerLevel,
            sessionNonce: sessionNonce,
            attendanceCount: attendanceCount,
            syncState: syncState,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String localId,
            Value<String?> serverId = const Value.absent(),
            required String teacherId,
            Value<String?> classId = const Value.absent(),
            required String name,
            Value<String?> course = const Value.absent(),
            Value<String?> branch = const Value.absent(),
            Value<String?> year = const Value.absent(),
            Value<String> location = const Value.absent(),
            required DateTime startTime,
            required DateTime endTime,
            Value<bool> isActive = const Value.absent(),
            Value<int?> txPowerLevel = const Value.absent(),
            Value<String?> sessionNonce = const Value.absent(),
            Value<int> attendanceCount = const Value.absent(),
            Value<String> syncState = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionsTableCompanion.insert(
            localId: localId,
            serverId: serverId,
            teacherId: teacherId,
            classId: classId,
            name: name,
            course: course,
            branch: branch,
            year: year,
            location: location,
            startTime: startTime,
            endTime: endTime,
            isActive: isActive,
            txPowerLevel: txPowerLevel,
            sessionNonce: sessionNonce,
            attendanceCount: attendanceCount,
            syncState: syncState,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$SessionsTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({attendanceRecordsTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (attendanceRecordsTableRefs) db.attendanceRecordsTable
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (attendanceRecordsTableRefs)
                    await $_getPrefetchedData<LocalSession, $SessionsTableTable,
                            LocalAttendanceRecord>(
                        currentTable: table,
                        referencedTable: $$SessionsTableTableReferences
                            ._attendanceRecordsTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SessionsTableTableReferences(db, table, p0)
                                .attendanceRecordsTableRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.sessionId == item.localId),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$SessionsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SessionsTableTable,
    LocalSession,
    $$SessionsTableTableFilterComposer,
    $$SessionsTableTableOrderingComposer,
    $$SessionsTableTableAnnotationComposer,
    $$SessionsTableTableCreateCompanionBuilder,
    $$SessionsTableTableUpdateCompanionBuilder,
    (LocalSession, $$SessionsTableTableReferences),
    LocalSession,
    PrefetchHooks Function({bool attendanceRecordsTableRefs})>;
typedef $$StudentsTableTableCreateCompanionBuilder = StudentsTableCompanion
    Function({
  required String studentId,
  required String name,
  Value<String?> email,
  Value<String?> rollNumber,
  Value<String?> course,
  Value<String?> branch,
  Value<String?> year,
  Value<String?> deviceKeyId,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$StudentsTableTableUpdateCompanionBuilder = StudentsTableCompanion
    Function({
  Value<String> studentId,
  Value<String> name,
  Value<String?> email,
  Value<String?> rollNumber,
  Value<String?> course,
  Value<String?> branch,
  Value<String?> year,
  Value<String?> deviceKeyId,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$StudentsTableTableReferences
    extends BaseReferences<_$AppDatabase, $StudentsTableTable, LocalStudent> {
  $$StudentsTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EnrollmentsTableTable, List<LocalEnrollment>>
      _enrollmentsTableRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.enrollmentsTable,
              aliasName: $_aliasNameGenerator(
                  db.studentsTable.studentId, db.enrollmentsTable.studentId));

  $$EnrollmentsTableTableProcessedTableManager get enrollmentsTableRefs {
    final manager =
        $$EnrollmentsTableTableTableManager($_db, $_db.enrollmentsTable).filter(
            (f) => f.studentId.studentId
                .sqlEquals($_itemColumn<String>('student_id')!));

    final cache =
        $_typedResult.readTableOrNull(_enrollmentsTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$AttendanceRecordsTableTable,
      List<LocalAttendanceRecord>> _attendanceRecordsTableRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.attendanceRecordsTable,
          aliasName: $_aliasNameGenerator(
              db.studentsTable.studentId, db.attendanceRecordsTable.studentId));

  $$AttendanceRecordsTableTableProcessedTableManager
      get attendanceRecordsTableRefs {
    final manager = $$AttendanceRecordsTableTableTableManager(
            $_db, $_db.attendanceRecordsTable)
        .filter((f) => f.studentId.studentId
            .sqlEquals($_itemColumn<String>('student_id')!));

    final cache =
        $_typedResult.readTableOrNull(_attendanceRecordsTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$StudentsTableTableFilterComposer
    extends Composer<_$AppDatabase, $StudentsTableTable> {
  $$StudentsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get studentId => $composableBuilder(
      column: $table.studentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rollNumber => $composableBuilder(
      column: $table.rollNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get course => $composableBuilder(
      column: $table.course, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get branch => $composableBuilder(
      column: $table.branch, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get year => $composableBuilder(
      column: $table.year, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceKeyId => $composableBuilder(
      column: $table.deviceKeyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> enrollmentsTableRefs(
      Expression<bool> Function($$EnrollmentsTableTableFilterComposer f) f) {
    final $$EnrollmentsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.studentId,
        referencedTable: $db.enrollmentsTable,
        getReferencedColumn: (t) => t.studentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EnrollmentsTableTableFilterComposer(
              $db: $db,
              $table: $db.enrollmentsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> attendanceRecordsTableRefs(
      Expression<bool> Function($$AttendanceRecordsTableTableFilterComposer f)
          f) {
    final $$AttendanceRecordsTableTableFilterComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.studentId,
            referencedTable: $db.attendanceRecordsTable,
            getReferencedColumn: (t) => t.studentId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$AttendanceRecordsTableTableFilterComposer(
                  $db: $db,
                  $table: $db.attendanceRecordsTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$StudentsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $StudentsTableTable> {
  $$StudentsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get studentId => $composableBuilder(
      column: $table.studentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rollNumber => $composableBuilder(
      column: $table.rollNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get course => $composableBuilder(
      column: $table.course, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get branch => $composableBuilder(
      column: $table.branch, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get year => $composableBuilder(
      column: $table.year, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceKeyId => $composableBuilder(
      column: $table.deviceKeyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$StudentsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudentsTableTable> {
  $$StudentsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get studentId =>
      $composableBuilder(column: $table.studentId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get rollNumber => $composableBuilder(
      column: $table.rollNumber, builder: (column) => column);

  GeneratedColumn<String> get course =>
      $composableBuilder(column: $table.course, builder: (column) => column);

  GeneratedColumn<String> get branch =>
      $composableBuilder(column: $table.branch, builder: (column) => column);

  GeneratedColumn<String> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get deviceKeyId => $composableBuilder(
      column: $table.deviceKeyId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> enrollmentsTableRefs<T extends Object>(
      Expression<T> Function($$EnrollmentsTableTableAnnotationComposer a) f) {
    final $$EnrollmentsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.studentId,
        referencedTable: $db.enrollmentsTable,
        getReferencedColumn: (t) => t.studentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EnrollmentsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.enrollmentsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> attendanceRecordsTableRefs<T extends Object>(
      Expression<T> Function($$AttendanceRecordsTableTableAnnotationComposer a)
          f) {
    final $$AttendanceRecordsTableTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.studentId,
            referencedTable: $db.attendanceRecordsTable,
            getReferencedColumn: (t) => t.studentId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$AttendanceRecordsTableTableAnnotationComposer(
                  $db: $db,
                  $table: $db.attendanceRecordsTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$StudentsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StudentsTableTable,
    LocalStudent,
    $$StudentsTableTableFilterComposer,
    $$StudentsTableTableOrderingComposer,
    $$StudentsTableTableAnnotationComposer,
    $$StudentsTableTableCreateCompanionBuilder,
    $$StudentsTableTableUpdateCompanionBuilder,
    (LocalStudent, $$StudentsTableTableReferences),
    LocalStudent,
    PrefetchHooks Function(
        {bool enrollmentsTableRefs, bool attendanceRecordsTableRefs})> {
  $$StudentsTableTableTableManager(_$AppDatabase db, $StudentsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudentsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudentsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudentsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> studentId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> rollNumber = const Value.absent(),
            Value<String?> course = const Value.absent(),
            Value<String?> branch = const Value.absent(),
            Value<String?> year = const Value.absent(),
            Value<String?> deviceKeyId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StudentsTableCompanion(
            studentId: studentId,
            name: name,
            email: email,
            rollNumber: rollNumber,
            course: course,
            branch: branch,
            year: year,
            deviceKeyId: deviceKeyId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String studentId,
            required String name,
            Value<String?> email = const Value.absent(),
            Value<String?> rollNumber = const Value.absent(),
            Value<String?> course = const Value.absent(),
            Value<String?> branch = const Value.absent(),
            Value<String?> year = const Value.absent(),
            Value<String?> deviceKeyId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StudentsTableCompanion.insert(
            studentId: studentId,
            name: name,
            email: email,
            rollNumber: rollNumber,
            course: course,
            branch: branch,
            year: year,
            deviceKeyId: deviceKeyId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$StudentsTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {enrollmentsTableRefs = false,
              attendanceRecordsTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (enrollmentsTableRefs) db.enrollmentsTable,
                if (attendanceRecordsTableRefs) db.attendanceRecordsTable
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (enrollmentsTableRefs)
                    await $_getPrefetchedData<LocalStudent, $StudentsTableTable,
                            LocalEnrollment>(
                        currentTable: table,
                        referencedTable: $$StudentsTableTableReferences
                            ._enrollmentsTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$StudentsTableTableReferences(db, table, p0)
                                .enrollmentsTableRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.studentId == item.studentId),
                        typedResults: items),
                  if (attendanceRecordsTableRefs)
                    await $_getPrefetchedData<LocalStudent, $StudentsTableTable,
                            LocalAttendanceRecord>(
                        currentTable: table,
                        referencedTable: $$StudentsTableTableReferences
                            ._attendanceRecordsTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$StudentsTableTableReferences(db, table, p0)
                                .attendanceRecordsTableRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.studentId == item.studentId),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$StudentsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StudentsTableTable,
    LocalStudent,
    $$StudentsTableTableFilterComposer,
    $$StudentsTableTableOrderingComposer,
    $$StudentsTableTableAnnotationComposer,
    $$StudentsTableTableCreateCompanionBuilder,
    $$StudentsTableTableUpdateCompanionBuilder,
    (LocalStudent, $$StudentsTableTableReferences),
    LocalStudent,
    PrefetchHooks Function(
        {bool enrollmentsTableRefs, bool attendanceRecordsTableRefs})>;
typedef $$ClassesTableTableCreateCompanionBuilder = ClassesTableCompanion
    Function({
  required String classId,
  required String name,
  Value<String?> code,
  Value<String?> course,
  Value<String?> branch,
  Value<String?> year,
  Value<String?> room,
  Value<String?> teacherId,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$ClassesTableTableUpdateCompanionBuilder = ClassesTableCompanion
    Function({
  Value<String> classId,
  Value<String> name,
  Value<String?> code,
  Value<String?> course,
  Value<String?> branch,
  Value<String?> year,
  Value<String?> room,
  Value<String?> teacherId,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$ClassesTableTableReferences
    extends BaseReferences<_$AppDatabase, $ClassesTableTable, LocalClass> {
  $$ClassesTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EnrollmentsTableTable, List<LocalEnrollment>>
      _enrollmentsTableRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.enrollmentsTable,
              aliasName: $_aliasNameGenerator(
                  db.classesTable.classId, db.enrollmentsTable.classId));

  $$EnrollmentsTableTableProcessedTableManager get enrollmentsTableRefs {
    final manager =
        $$EnrollmentsTableTableTableManager($_db, $_db.enrollmentsTable).filter(
            (f) =>
                f.classId.classId.sqlEquals($_itemColumn<String>('class_id')!));

    final cache =
        $_typedResult.readTableOrNull(_enrollmentsTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ClassesTableTableFilterComposer
    extends Composer<_$AppDatabase, $ClassesTableTable> {
  $$ClassesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get classId => $composableBuilder(
      column: $table.classId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get course => $composableBuilder(
      column: $table.course, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get branch => $composableBuilder(
      column: $table.branch, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get year => $composableBuilder(
      column: $table.year, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get room => $composableBuilder(
      column: $table.room, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get teacherId => $composableBuilder(
      column: $table.teacherId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> enrollmentsTableRefs(
      Expression<bool> Function($$EnrollmentsTableTableFilterComposer f) f) {
    final $$EnrollmentsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.classId,
        referencedTable: $db.enrollmentsTable,
        getReferencedColumn: (t) => t.classId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EnrollmentsTableTableFilterComposer(
              $db: $db,
              $table: $db.enrollmentsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ClassesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ClassesTableTable> {
  $$ClassesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get classId => $composableBuilder(
      column: $table.classId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get course => $composableBuilder(
      column: $table.course, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get branch => $composableBuilder(
      column: $table.branch, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get year => $composableBuilder(
      column: $table.year, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get room => $composableBuilder(
      column: $table.room, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get teacherId => $composableBuilder(
      column: $table.teacherId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ClassesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClassesTableTable> {
  $$ClassesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get classId =>
      $composableBuilder(column: $table.classId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get course =>
      $composableBuilder(column: $table.course, builder: (column) => column);

  GeneratedColumn<String> get branch =>
      $composableBuilder(column: $table.branch, builder: (column) => column);

  GeneratedColumn<String> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get room =>
      $composableBuilder(column: $table.room, builder: (column) => column);

  GeneratedColumn<String> get teacherId =>
      $composableBuilder(column: $table.teacherId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> enrollmentsTableRefs<T extends Object>(
      Expression<T> Function($$EnrollmentsTableTableAnnotationComposer a) f) {
    final $$EnrollmentsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.classId,
        referencedTable: $db.enrollmentsTable,
        getReferencedColumn: (t) => t.classId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EnrollmentsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.enrollmentsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ClassesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ClassesTableTable,
    LocalClass,
    $$ClassesTableTableFilterComposer,
    $$ClassesTableTableOrderingComposer,
    $$ClassesTableTableAnnotationComposer,
    $$ClassesTableTableCreateCompanionBuilder,
    $$ClassesTableTableUpdateCompanionBuilder,
    (LocalClass, $$ClassesTableTableReferences),
    LocalClass,
    PrefetchHooks Function({bool enrollmentsTableRefs})> {
  $$ClassesTableTableTableManager(_$AppDatabase db, $ClassesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClassesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClassesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClassesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> classId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> code = const Value.absent(),
            Value<String?> course = const Value.absent(),
            Value<String?> branch = const Value.absent(),
            Value<String?> year = const Value.absent(),
            Value<String?> room = const Value.absent(),
            Value<String?> teacherId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ClassesTableCompanion(
            classId: classId,
            name: name,
            code: code,
            course: course,
            branch: branch,
            year: year,
            room: room,
            teacherId: teacherId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String classId,
            required String name,
            Value<String?> code = const Value.absent(),
            Value<String?> course = const Value.absent(),
            Value<String?> branch = const Value.absent(),
            Value<String?> year = const Value.absent(),
            Value<String?> room = const Value.absent(),
            Value<String?> teacherId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ClassesTableCompanion.insert(
            classId: classId,
            name: name,
            code: code,
            course: course,
            branch: branch,
            year: year,
            room: room,
            teacherId: teacherId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ClassesTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({enrollmentsTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (enrollmentsTableRefs) db.enrollmentsTable
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (enrollmentsTableRefs)
                    await $_getPrefetchedData<LocalClass, $ClassesTableTable,
                            LocalEnrollment>(
                        currentTable: table,
                        referencedTable: $$ClassesTableTableReferences
                            ._enrollmentsTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ClassesTableTableReferences(db, table, p0)
                                .enrollmentsTableRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.classId == item.classId),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ClassesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ClassesTableTable,
    LocalClass,
    $$ClassesTableTableFilterComposer,
    $$ClassesTableTableOrderingComposer,
    $$ClassesTableTableAnnotationComposer,
    $$ClassesTableTableCreateCompanionBuilder,
    $$ClassesTableTableUpdateCompanionBuilder,
    (LocalClass, $$ClassesTableTableReferences),
    LocalClass,
    PrefetchHooks Function({bool enrollmentsTableRefs})>;
typedef $$EnrollmentsTableTableCreateCompanionBuilder
    = EnrollmentsTableCompanion Function({
  required String id,
  required String classId,
  required String studentId,
  Value<DateTime> enrolledAt,
  Value<int> rowid,
});
typedef $$EnrollmentsTableTableUpdateCompanionBuilder
    = EnrollmentsTableCompanion Function({
  Value<String> id,
  Value<String> classId,
  Value<String> studentId,
  Value<DateTime> enrolledAt,
  Value<int> rowid,
});

final class $$EnrollmentsTableTableReferences extends BaseReferences<
    _$AppDatabase, $EnrollmentsTableTable, LocalEnrollment> {
  $$EnrollmentsTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ClassesTableTable _classIdTable(_$AppDatabase db) =>
      db.classesTable.createAlias($_aliasNameGenerator(
          db.enrollmentsTable.classId, db.classesTable.classId));

  $$ClassesTableTableProcessedTableManager get classId {
    final $_column = $_itemColumn<String>('class_id')!;

    final manager = $$ClassesTableTableTableManager($_db, $_db.classesTable)
        .filter((f) => f.classId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_classIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $StudentsTableTable _studentIdTable(_$AppDatabase db) =>
      db.studentsTable.createAlias($_aliasNameGenerator(
          db.enrollmentsTable.studentId, db.studentsTable.studentId));

  $$StudentsTableTableProcessedTableManager get studentId {
    final $_column = $_itemColumn<String>('student_id')!;

    final manager = $$StudentsTableTableTableManager($_db, $_db.studentsTable)
        .filter((f) => f.studentId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_studentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$EnrollmentsTableTableFilterComposer
    extends Composer<_$AppDatabase, $EnrollmentsTableTable> {
  $$EnrollmentsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get enrolledAt => $composableBuilder(
      column: $table.enrolledAt, builder: (column) => ColumnFilters(column));

  $$ClassesTableTableFilterComposer get classId {
    final $$ClassesTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.classId,
        referencedTable: $db.classesTable,
        getReferencedColumn: (t) => t.classId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ClassesTableTableFilterComposer(
              $db: $db,
              $table: $db.classesTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$StudentsTableTableFilterComposer get studentId {
    final $$StudentsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.studentId,
        referencedTable: $db.studentsTable,
        getReferencedColumn: (t) => t.studentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StudentsTableTableFilterComposer(
              $db: $db,
              $table: $db.studentsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$EnrollmentsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $EnrollmentsTableTable> {
  $$EnrollmentsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get enrolledAt => $composableBuilder(
      column: $table.enrolledAt, builder: (column) => ColumnOrderings(column));

  $$ClassesTableTableOrderingComposer get classId {
    final $$ClassesTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.classId,
        referencedTable: $db.classesTable,
        getReferencedColumn: (t) => t.classId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ClassesTableTableOrderingComposer(
              $db: $db,
              $table: $db.classesTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$StudentsTableTableOrderingComposer get studentId {
    final $$StudentsTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.studentId,
        referencedTable: $db.studentsTable,
        getReferencedColumn: (t) => t.studentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StudentsTableTableOrderingComposer(
              $db: $db,
              $table: $db.studentsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$EnrollmentsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $EnrollmentsTableTable> {
  $$EnrollmentsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get enrolledAt => $composableBuilder(
      column: $table.enrolledAt, builder: (column) => column);

  $$ClassesTableTableAnnotationComposer get classId {
    final $$ClassesTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.classId,
        referencedTable: $db.classesTable,
        getReferencedColumn: (t) => t.classId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ClassesTableTableAnnotationComposer(
              $db: $db,
              $table: $db.classesTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$StudentsTableTableAnnotationComposer get studentId {
    final $$StudentsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.studentId,
        referencedTable: $db.studentsTable,
        getReferencedColumn: (t) => t.studentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StudentsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.studentsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$EnrollmentsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $EnrollmentsTableTable,
    LocalEnrollment,
    $$EnrollmentsTableTableFilterComposer,
    $$EnrollmentsTableTableOrderingComposer,
    $$EnrollmentsTableTableAnnotationComposer,
    $$EnrollmentsTableTableCreateCompanionBuilder,
    $$EnrollmentsTableTableUpdateCompanionBuilder,
    (LocalEnrollment, $$EnrollmentsTableTableReferences),
    LocalEnrollment,
    PrefetchHooks Function({bool classId, bool studentId})> {
  $$EnrollmentsTableTableTableManager(
      _$AppDatabase db, $EnrollmentsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EnrollmentsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EnrollmentsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EnrollmentsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> classId = const Value.absent(),
            Value<String> studentId = const Value.absent(),
            Value<DateTime> enrolledAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EnrollmentsTableCompanion(
            id: id,
            classId: classId,
            studentId: studentId,
            enrolledAt: enrolledAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String classId,
            required String studentId,
            Value<DateTime> enrolledAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EnrollmentsTableCompanion.insert(
            id: id,
            classId: classId,
            studentId: studentId,
            enrolledAt: enrolledAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$EnrollmentsTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({classId = false, studentId = false}) {
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
                if (classId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.classId,
                    referencedTable:
                        $$EnrollmentsTableTableReferences._classIdTable(db),
                    referencedColumn: $$EnrollmentsTableTableReferences
                        ._classIdTable(db)
                        .classId,
                  ) as T;
                }
                if (studentId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.studentId,
                    referencedTable:
                        $$EnrollmentsTableTableReferences._studentIdTable(db),
                    referencedColumn: $$EnrollmentsTableTableReferences
                        ._studentIdTable(db)
                        .studentId,
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

typedef $$EnrollmentsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $EnrollmentsTableTable,
    LocalEnrollment,
    $$EnrollmentsTableTableFilterComposer,
    $$EnrollmentsTableTableOrderingComposer,
    $$EnrollmentsTableTableAnnotationComposer,
    $$EnrollmentsTableTableCreateCompanionBuilder,
    $$EnrollmentsTableTableUpdateCompanionBuilder,
    (LocalEnrollment, $$EnrollmentsTableTableReferences),
    LocalEnrollment,
    PrefetchHooks Function({bool classId, bool studentId})>;
typedef $$AttendanceRecordsTableTableCreateCompanionBuilder
    = AttendanceRecordsTableCompanion Function({
  required String localId,
  Value<String?> serverId,
  required String sessionId,
  required String studentId,
  required String studentName,
  Value<String> status,
  required DateTime checkInTime,
  required String idempotencyKey,
  Value<String?> deviceKeyId,
  Value<String?> responseNonce,
  Value<String> verificationMode,
  Value<String?> proximityTier,
  Value<String> syncState,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$AttendanceRecordsTableTableUpdateCompanionBuilder
    = AttendanceRecordsTableCompanion Function({
  Value<String> localId,
  Value<String?> serverId,
  Value<String> sessionId,
  Value<String> studentId,
  Value<String> studentName,
  Value<String> status,
  Value<DateTime> checkInTime,
  Value<String> idempotencyKey,
  Value<String?> deviceKeyId,
  Value<String?> responseNonce,
  Value<String> verificationMode,
  Value<String?> proximityTier,
  Value<String> syncState,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$AttendanceRecordsTableTableReferences extends BaseReferences<
    _$AppDatabase, $AttendanceRecordsTableTable, LocalAttendanceRecord> {
  $$AttendanceRecordsTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTableTable _sessionIdTable(_$AppDatabase db) =>
      db.sessionsTable.createAlias($_aliasNameGenerator(
          db.attendanceRecordsTable.sessionId, db.sessionsTable.localId));

  $$SessionsTableTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableTableManager($_db, $_db.sessionsTable)
        .filter((f) => f.localId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $StudentsTableTable _studentIdTable(_$AppDatabase db) =>
      db.studentsTable.createAlias($_aliasNameGenerator(
          db.attendanceRecordsTable.studentId, db.studentsTable.studentId));

  $$StudentsTableTableProcessedTableManager get studentId {
    final $_column = $_itemColumn<String>('student_id')!;

    final manager = $$StudentsTableTableTableManager($_db, $_db.studentsTable)
        .filter((f) => f.studentId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_studentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$AttendanceRecordsTableTableFilterComposer
    extends Composer<_$AppDatabase, $AttendanceRecordsTableTable> {
  $$AttendanceRecordsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localId => $composableBuilder(
      column: $table.localId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get studentName => $composableBuilder(
      column: $table.studentName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get checkInTime => $composableBuilder(
      column: $table.checkInTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceKeyId => $composableBuilder(
      column: $table.deviceKeyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get responseNonce => $composableBuilder(
      column: $table.responseNonce, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get verificationMode => $composableBuilder(
      column: $table.verificationMode,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get proximityTier => $composableBuilder(
      column: $table.proximityTier, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncState => $composableBuilder(
      column: $table.syncState, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$SessionsTableTableFilterComposer get sessionId {
    final $$SessionsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.localId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableFilterComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$StudentsTableTableFilterComposer get studentId {
    final $$StudentsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.studentId,
        referencedTable: $db.studentsTable,
        getReferencedColumn: (t) => t.studentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StudentsTableTableFilterComposer(
              $db: $db,
              $table: $db.studentsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AttendanceRecordsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AttendanceRecordsTableTable> {
  $$AttendanceRecordsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localId => $composableBuilder(
      column: $table.localId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get studentName => $composableBuilder(
      column: $table.studentName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get checkInTime => $composableBuilder(
      column: $table.checkInTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceKeyId => $composableBuilder(
      column: $table.deviceKeyId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get responseNonce => $composableBuilder(
      column: $table.responseNonce,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get verificationMode => $composableBuilder(
      column: $table.verificationMode,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get proximityTier => $composableBuilder(
      column: $table.proximityTier,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncState => $composableBuilder(
      column: $table.syncState, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$SessionsTableTableOrderingComposer get sessionId {
    final $$SessionsTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.localId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableOrderingComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$StudentsTableTableOrderingComposer get studentId {
    final $$StudentsTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.studentId,
        referencedTable: $db.studentsTable,
        getReferencedColumn: (t) => t.studentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StudentsTableTableOrderingComposer(
              $db: $db,
              $table: $db.studentsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AttendanceRecordsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttendanceRecordsTableTable> {
  $$AttendanceRecordsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get studentName => $composableBuilder(
      column: $table.studentName, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get checkInTime => $composableBuilder(
      column: $table.checkInTime, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey, builder: (column) => column);

  GeneratedColumn<String> get deviceKeyId => $composableBuilder(
      column: $table.deviceKeyId, builder: (column) => column);

  GeneratedColumn<String> get responseNonce => $composableBuilder(
      column: $table.responseNonce, builder: (column) => column);

  GeneratedColumn<String> get verificationMode => $composableBuilder(
      column: $table.verificationMode, builder: (column) => column);

  GeneratedColumn<String> get proximityTier => $composableBuilder(
      column: $table.proximityTier, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SessionsTableTableAnnotationComposer get sessionId {
    final $$SessionsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionsTable,
        getReferencedColumn: (t) => t.localId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.sessionsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$StudentsTableTableAnnotationComposer get studentId {
    final $$StudentsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.studentId,
        referencedTable: $db.studentsTable,
        getReferencedColumn: (t) => t.studentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StudentsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.studentsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AttendanceRecordsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AttendanceRecordsTableTable,
    LocalAttendanceRecord,
    $$AttendanceRecordsTableTableFilterComposer,
    $$AttendanceRecordsTableTableOrderingComposer,
    $$AttendanceRecordsTableTableAnnotationComposer,
    $$AttendanceRecordsTableTableCreateCompanionBuilder,
    $$AttendanceRecordsTableTableUpdateCompanionBuilder,
    (LocalAttendanceRecord, $$AttendanceRecordsTableTableReferences),
    LocalAttendanceRecord,
    PrefetchHooks Function({bool sessionId, bool studentId})> {
  $$AttendanceRecordsTableTableTableManager(
      _$AppDatabase db, $AttendanceRecordsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttendanceRecordsTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$AttendanceRecordsTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttendanceRecordsTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> localId = const Value.absent(),
            Value<String?> serverId = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<String> studentId = const Value.absent(),
            Value<String> studentName = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> checkInTime = const Value.absent(),
            Value<String> idempotencyKey = const Value.absent(),
            Value<String?> deviceKeyId = const Value.absent(),
            Value<String?> responseNonce = const Value.absent(),
            Value<String> verificationMode = const Value.absent(),
            Value<String?> proximityTier = const Value.absent(),
            Value<String> syncState = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AttendanceRecordsTableCompanion(
            localId: localId,
            serverId: serverId,
            sessionId: sessionId,
            studentId: studentId,
            studentName: studentName,
            status: status,
            checkInTime: checkInTime,
            idempotencyKey: idempotencyKey,
            deviceKeyId: deviceKeyId,
            responseNonce: responseNonce,
            verificationMode: verificationMode,
            proximityTier: proximityTier,
            syncState: syncState,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String localId,
            Value<String?> serverId = const Value.absent(),
            required String sessionId,
            required String studentId,
            required String studentName,
            Value<String> status = const Value.absent(),
            required DateTime checkInTime,
            required String idempotencyKey,
            Value<String?> deviceKeyId = const Value.absent(),
            Value<String?> responseNonce = const Value.absent(),
            Value<String> verificationMode = const Value.absent(),
            Value<String?> proximityTier = const Value.absent(),
            Value<String> syncState = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AttendanceRecordsTableCompanion.insert(
            localId: localId,
            serverId: serverId,
            sessionId: sessionId,
            studentId: studentId,
            studentName: studentName,
            status: status,
            checkInTime: checkInTime,
            idempotencyKey: idempotencyKey,
            deviceKeyId: deviceKeyId,
            responseNonce: responseNonce,
            verificationMode: verificationMode,
            proximityTier: proximityTier,
            syncState: syncState,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$AttendanceRecordsTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sessionId = false, studentId = false}) {
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
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable: $$AttendanceRecordsTableTableReferences
                        ._sessionIdTable(db),
                    referencedColumn: $$AttendanceRecordsTableTableReferences
                        ._sessionIdTable(db)
                        .localId,
                  ) as T;
                }
                if (studentId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.studentId,
                    referencedTable: $$AttendanceRecordsTableTableReferences
                        ._studentIdTable(db),
                    referencedColumn: $$AttendanceRecordsTableTableReferences
                        ._studentIdTable(db)
                        .studentId,
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

typedef $$AttendanceRecordsTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $AttendanceRecordsTableTable,
        LocalAttendanceRecord,
        $$AttendanceRecordsTableTableFilterComposer,
        $$AttendanceRecordsTableTableOrderingComposer,
        $$AttendanceRecordsTableTableAnnotationComposer,
        $$AttendanceRecordsTableTableCreateCompanionBuilder,
        $$AttendanceRecordsTableTableUpdateCompanionBuilder,
        (LocalAttendanceRecord, $$AttendanceRecordsTableTableReferences),
        LocalAttendanceRecord,
        PrefetchHooks Function({bool sessionId, bool studentId})>;
typedef $$SyncOutboxTableTableCreateCompanionBuilder = SyncOutboxTableCompanion
    Function({
  required String localId,
  required String entityType,
  required String entityId,
  required String endpoint,
  Value<String> method,
  required String payload,
  Value<String?> idempotencyKey,
  Value<DateTime> createdAt,
  Value<int> attemptCount,
  Value<DateTime?> lastAttemptedAt,
  Value<String> status,
  Value<String?> errorMessage,
  Value<int> rowid,
});
typedef $$SyncOutboxTableTableUpdateCompanionBuilder = SyncOutboxTableCompanion
    Function({
  Value<String> localId,
  Value<String> entityType,
  Value<String> entityId,
  Value<String> endpoint,
  Value<String> method,
  Value<String> payload,
  Value<String?> idempotencyKey,
  Value<DateTime> createdAt,
  Value<int> attemptCount,
  Value<DateTime?> lastAttemptedAt,
  Value<String> status,
  Value<String?> errorMessage,
  Value<int> rowid,
});

class $$SyncOutboxTableTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxTableTable> {
  $$SyncOutboxTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localId => $composableBuilder(
      column: $table.localId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get endpoint => $composableBuilder(
      column: $table.endpoint, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get method => $composableBuilder(
      column: $table.method, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastAttemptedAt => $composableBuilder(
      column: $table.lastAttemptedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => ColumnFilters(column));
}

class $$SyncOutboxTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxTableTable> {
  $$SyncOutboxTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localId => $composableBuilder(
      column: $table.localId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get endpoint => $composableBuilder(
      column: $table.endpoint, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get method => $composableBuilder(
      column: $table.method, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastAttemptedAt => $composableBuilder(
      column: $table.lastAttemptedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage,
      builder: (column) => ColumnOrderings(column));
}

class $$SyncOutboxTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxTableTable> {
  $$SyncOutboxTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get endpoint =>
      $composableBuilder(column: $table.endpoint, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptedAt => $composableBuilder(
      column: $table.lastAttemptedAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => column);
}

class $$SyncOutboxTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncOutboxTableTable,
    LocalOutboxOperation,
    $$SyncOutboxTableTableFilterComposer,
    $$SyncOutboxTableTableOrderingComposer,
    $$SyncOutboxTableTableAnnotationComposer,
    $$SyncOutboxTableTableCreateCompanionBuilder,
    $$SyncOutboxTableTableUpdateCompanionBuilder,
    (
      LocalOutboxOperation,
      BaseReferences<_$AppDatabase, $SyncOutboxTableTable, LocalOutboxOperation>
    ),
    LocalOutboxOperation,
    PrefetchHooks Function()> {
  $$SyncOutboxTableTableTableManager(
      _$AppDatabase db, $SyncOutboxTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> localId = const Value.absent(),
            Value<String> entityType = const Value.absent(),
            Value<String> entityId = const Value.absent(),
            Value<String> endpoint = const Value.absent(),
            Value<String> method = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<String?> idempotencyKey = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> attemptCount = const Value.absent(),
            Value<DateTime?> lastAttemptedAt = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncOutboxTableCompanion(
            localId: localId,
            entityType: entityType,
            entityId: entityId,
            endpoint: endpoint,
            method: method,
            payload: payload,
            idempotencyKey: idempotencyKey,
            createdAt: createdAt,
            attemptCount: attemptCount,
            lastAttemptedAt: lastAttemptedAt,
            status: status,
            errorMessage: errorMessage,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String localId,
            required String entityType,
            required String entityId,
            required String endpoint,
            Value<String> method = const Value.absent(),
            required String payload,
            Value<String?> idempotencyKey = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> attemptCount = const Value.absent(),
            Value<DateTime?> lastAttemptedAt = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncOutboxTableCompanion.insert(
            localId: localId,
            entityType: entityType,
            entityId: entityId,
            endpoint: endpoint,
            method: method,
            payload: payload,
            idempotencyKey: idempotencyKey,
            createdAt: createdAt,
            attemptCount: attemptCount,
            lastAttemptedAt: lastAttemptedAt,
            status: status,
            errorMessage: errorMessage,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncOutboxTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncOutboxTableTable,
    LocalOutboxOperation,
    $$SyncOutboxTableTableFilterComposer,
    $$SyncOutboxTableTableOrderingComposer,
    $$SyncOutboxTableTableAnnotationComposer,
    $$SyncOutboxTableTableCreateCompanionBuilder,
    $$SyncOutboxTableTableUpdateCompanionBuilder,
    (
      LocalOutboxOperation,
      BaseReferences<_$AppDatabase, $SyncOutboxTableTable, LocalOutboxOperation>
    ),
    LocalOutboxOperation,
    PrefetchHooks Function()>;
typedef $$ComplaintsTableTableCreateCompanionBuilder = ComplaintsTableCompanion
    Function({
  required String localId,
  Value<String?> serverId,
  Value<String?> idempotencyKey,
  required String studentId,
  required String category,
  required String title,
  required String description,
  Value<String> location,
  Value<String> priority,
  Value<String> status,
  Value<String> syncState,
  Value<String?> assignedTo,
  Value<String?> assignedToName,
  Value<String?> resolutionRemarks,
  Value<DateTime?> resolvedAt,
  Value<DateTime> createdAt,
  Value<DateTime?> serverCreatedAt,
  Value<DateTime?> updatedAt,
  Value<bool> isRepeat,
  Value<int> rowid,
});
typedef $$ComplaintsTableTableUpdateCompanionBuilder = ComplaintsTableCompanion
    Function({
  Value<String> localId,
  Value<String?> serverId,
  Value<String?> idempotencyKey,
  Value<String> studentId,
  Value<String> category,
  Value<String> title,
  Value<String> description,
  Value<String> location,
  Value<String> priority,
  Value<String> status,
  Value<String> syncState,
  Value<String?> assignedTo,
  Value<String?> assignedToName,
  Value<String?> resolutionRemarks,
  Value<DateTime?> resolvedAt,
  Value<DateTime> createdAt,
  Value<DateTime?> serverCreatedAt,
  Value<DateTime?> updatedAt,
  Value<bool> isRepeat,
  Value<int> rowid,
});

class $$ComplaintsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ComplaintsTableTable> {
  $$ComplaintsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localId => $composableBuilder(
      column: $table.localId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get studentId => $composableBuilder(
      column: $table.studentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncState => $composableBuilder(
      column: $table.syncState, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get assignedTo => $composableBuilder(
      column: $table.assignedTo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get assignedToName => $composableBuilder(
      column: $table.assignedToName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resolutionRemarks => $composableBuilder(
      column: $table.resolutionRemarks,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
      column: $table.resolvedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get serverCreatedAt => $composableBuilder(
      column: $table.serverCreatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isRepeat => $composableBuilder(
      column: $table.isRepeat, builder: (column) => ColumnFilters(column));
}

class $$ComplaintsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ComplaintsTableTable> {
  $$ComplaintsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localId => $composableBuilder(
      column: $table.localId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get studentId => $composableBuilder(
      column: $table.studentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncState => $composableBuilder(
      column: $table.syncState, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get assignedTo => $composableBuilder(
      column: $table.assignedTo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get assignedToName => $composableBuilder(
      column: $table.assignedToName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resolutionRemarks => $composableBuilder(
      column: $table.resolutionRemarks,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
      column: $table.resolvedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get serverCreatedAt => $composableBuilder(
      column: $table.serverCreatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isRepeat => $composableBuilder(
      column: $table.isRepeat, builder: (column) => ColumnOrderings(column));
}

class $$ComplaintsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ComplaintsTableTable> {
  $$ComplaintsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey, builder: (column) => column);

  GeneratedColumn<String> get studentId =>
      $composableBuilder(column: $table.studentId, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<String> get assignedTo => $composableBuilder(
      column: $table.assignedTo, builder: (column) => column);

  GeneratedColumn<String> get assignedToName => $composableBuilder(
      column: $table.assignedToName, builder: (column) => column);

  GeneratedColumn<String> get resolutionRemarks => $composableBuilder(
      column: $table.resolutionRemarks, builder: (column) => column);

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
      column: $table.resolvedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get serverCreatedAt => $composableBuilder(
      column: $table.serverCreatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isRepeat =>
      $composableBuilder(column: $table.isRepeat, builder: (column) => column);
}

class $$ComplaintsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ComplaintsTableTable,
    LocalComplaint,
    $$ComplaintsTableTableFilterComposer,
    $$ComplaintsTableTableOrderingComposer,
    $$ComplaintsTableTableAnnotationComposer,
    $$ComplaintsTableTableCreateCompanionBuilder,
    $$ComplaintsTableTableUpdateCompanionBuilder,
    (
      LocalComplaint,
      BaseReferences<_$AppDatabase, $ComplaintsTableTable, LocalComplaint>
    ),
    LocalComplaint,
    PrefetchHooks Function()> {
  $$ComplaintsTableTableTableManager(
      _$AppDatabase db, $ComplaintsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ComplaintsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ComplaintsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ComplaintsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> localId = const Value.absent(),
            Value<String?> serverId = const Value.absent(),
            Value<String?> idempotencyKey = const Value.absent(),
            Value<String> studentId = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<String> location = const Value.absent(),
            Value<String> priority = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> syncState = const Value.absent(),
            Value<String?> assignedTo = const Value.absent(),
            Value<String?> assignedToName = const Value.absent(),
            Value<String?> resolutionRemarks = const Value.absent(),
            Value<DateTime?> resolvedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> serverCreatedAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<bool> isRepeat = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ComplaintsTableCompanion(
            localId: localId,
            serverId: serverId,
            idempotencyKey: idempotencyKey,
            studentId: studentId,
            category: category,
            title: title,
            description: description,
            location: location,
            priority: priority,
            status: status,
            syncState: syncState,
            assignedTo: assignedTo,
            assignedToName: assignedToName,
            resolutionRemarks: resolutionRemarks,
            resolvedAt: resolvedAt,
            createdAt: createdAt,
            serverCreatedAt: serverCreatedAt,
            updatedAt: updatedAt,
            isRepeat: isRepeat,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String localId,
            Value<String?> serverId = const Value.absent(),
            Value<String?> idempotencyKey = const Value.absent(),
            required String studentId,
            required String category,
            required String title,
            required String description,
            Value<String> location = const Value.absent(),
            Value<String> priority = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> syncState = const Value.absent(),
            Value<String?> assignedTo = const Value.absent(),
            Value<String?> assignedToName = const Value.absent(),
            Value<String?> resolutionRemarks = const Value.absent(),
            Value<DateTime?> resolvedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> serverCreatedAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<bool> isRepeat = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ComplaintsTableCompanion.insert(
            localId: localId,
            serverId: serverId,
            idempotencyKey: idempotencyKey,
            studentId: studentId,
            category: category,
            title: title,
            description: description,
            location: location,
            priority: priority,
            status: status,
            syncState: syncState,
            assignedTo: assignedTo,
            assignedToName: assignedToName,
            resolutionRemarks: resolutionRemarks,
            resolvedAt: resolvedAt,
            createdAt: createdAt,
            serverCreatedAt: serverCreatedAt,
            updatedAt: updatedAt,
            isRepeat: isRepeat,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ComplaintsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ComplaintsTableTable,
    LocalComplaint,
    $$ComplaintsTableTableFilterComposer,
    $$ComplaintsTableTableOrderingComposer,
    $$ComplaintsTableTableAnnotationComposer,
    $$ComplaintsTableTableCreateCompanionBuilder,
    $$ComplaintsTableTableUpdateCompanionBuilder,
    (
      LocalComplaint,
      BaseReferences<_$AppDatabase, $ComplaintsTableTable, LocalComplaint>
    ),
    LocalComplaint,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SessionsTableTableTableManager get sessionsTable =>
      $$SessionsTableTableTableManager(_db, _db.sessionsTable);
  $$StudentsTableTableTableManager get studentsTable =>
      $$StudentsTableTableTableManager(_db, _db.studentsTable);
  $$ClassesTableTableTableManager get classesTable =>
      $$ClassesTableTableTableManager(_db, _db.classesTable);
  $$EnrollmentsTableTableTableManager get enrollmentsTable =>
      $$EnrollmentsTableTableTableManager(_db, _db.enrollmentsTable);
  $$AttendanceRecordsTableTableTableManager get attendanceRecordsTable =>
      $$AttendanceRecordsTableTableTableManager(
          _db, _db.attendanceRecordsTable);
  $$SyncOutboxTableTableTableManager get syncOutboxTable =>
      $$SyncOutboxTableTableTableManager(_db, _db.syncOutboxTable);
  $$ComplaintsTableTableTableManager get complaintsTable =>
      $$ComplaintsTableTableTableManager(_db, _db.complaintsTable);
}
