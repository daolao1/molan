// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $NovelsTable extends Novels with TableInfo<$NovelsTable, Novel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NovelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _styleEntryIdsMeta = const VerificationMeta(
    'styleEntryIds',
  );
  @override
  late final GeneratedColumn<String> styleEntryIds = GeneratedColumn<String>(
    'style_entry_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    styleEntryIds,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'novels';
  @override
  VerificationContext validateIntegrity(
    Insertable<Novel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('style_entry_ids')) {
      context.handle(
        _styleEntryIdsMeta,
        styleEntryIds.isAcceptableOrUnknown(
          data['style_entry_ids']!,
          _styleEntryIdsMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Novel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Novel(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      styleEntryIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}style_entry_ids'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $NovelsTable createAlias(String alias) {
    return $NovelsTable(attachedDatabase, alias);
  }
}

class Novel extends DataClass implements Insertable<Novel> {
  final int id;
  final String title;
  final String description;

  /// 挂载到写作会话的文风设定卡 id(逗号分隔)
  final String styleEntryIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Novel({
    required this.id,
    required this.title,
    required this.description,
    required this.styleEntryIds,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['style_entry_ids'] = Variable<String>(styleEntryIds);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  NovelsCompanion toCompanion(bool nullToAbsent) {
    return NovelsCompanion(
      id: Value(id),
      title: Value(title),
      description: Value(description),
      styleEntryIds: Value(styleEntryIds),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Novel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Novel(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      styleEntryIds: serializer.fromJson<String>(json['styleEntryIds']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'styleEntryIds': serializer.toJson<String>(styleEntryIds),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Novel copyWith({
    int? id,
    String? title,
    String? description,
    String? styleEntryIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Novel(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    styleEntryIds: styleEntryIds ?? this.styleEntryIds,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Novel copyWithCompanion(NovelsCompanion data) {
    return Novel(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      styleEntryIds: data.styleEntryIds.present
          ? data.styleEntryIds.value
          : this.styleEntryIds,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Novel(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('styleEntryIds: $styleEntryIds, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, description, styleEntryIds, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Novel &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.styleEntryIds == this.styleEntryIds &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class NovelsCompanion extends UpdateCompanion<Novel> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> description;
  final Value<String> styleEntryIds;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const NovelsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.styleEntryIds = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  NovelsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    this.styleEntryIds = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : title = Value(title);
  static Insertable<Novel> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? styleEntryIds,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (styleEntryIds != null) 'style_entry_ids': styleEntryIds,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  NovelsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? description,
    Value<String>? styleEntryIds,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return NovelsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      styleEntryIds: styleEntryIds ?? this.styleEntryIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (styleEntryIds.present) {
      map['style_entry_ids'] = Variable<String>(styleEntryIds.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NovelsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('styleEntryIds: $styleEntryIds, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $EntriesTable extends Entries with TableInfo<$EntriesTable, Entry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _novelIdMeta = const VerificationMeta(
    'novelId',
  );
  @override
  late final GeneratedColumn<int> novelId = GeneratedColumn<int>(
    'novel_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES novels (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _imageDataMeta = const VerificationMeta(
    'imageData',
  );
  @override
  late final GeneratedColumn<String> imageData = GeneratedColumn<String>(
    'image_data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    novelId,
    kind,
    name,
    content,
    imageData,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Entry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('novel_id')) {
      context.handle(
        _novelIdMeta,
        novelId.isAcceptableOrUnknown(data['novel_id']!, _novelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_novelIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('image_data')) {
      context.handle(
        _imageDataMeta,
        imageData.isAcceptableOrUnknown(data['image_data']!, _imageDataMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Entry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Entry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      novelId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}novel_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      imageData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_data'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }
}

class Entry extends DataClass implements Insertable<Entry> {
  final int id;
  final int novelId;
  final String kind;
  final String name;
  final String content;

  /// 卡面图片(base64,空=无图)
  final String imageData;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Entry({
    required this.id,
    required this.novelId,
    required this.kind,
    required this.name,
    required this.content,
    required this.imageData,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['novel_id'] = Variable<int>(novelId);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    map['content'] = Variable<String>(content);
    map['image_data'] = Variable<String>(imageData);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      novelId: Value(novelId),
      kind: Value(kind),
      name: Value(name),
      content: Value(content),
      imageData: Value(imageData),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Entry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Entry(
      id: serializer.fromJson<int>(json['id']),
      novelId: serializer.fromJson<int>(json['novelId']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      content: serializer.fromJson<String>(json['content']),
      imageData: serializer.fromJson<String>(json['imageData']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'novelId': serializer.toJson<int>(novelId),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'content': serializer.toJson<String>(content),
      'imageData': serializer.toJson<String>(imageData),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Entry copyWith({
    int? id,
    int? novelId,
    String? kind,
    String? name,
    String? content,
    String? imageData,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Entry(
    id: id ?? this.id,
    novelId: novelId ?? this.novelId,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    content: content ?? this.content,
    imageData: imageData ?? this.imageData,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Entry copyWithCompanion(EntriesCompanion data) {
    return Entry(
      id: data.id.present ? data.id.value : this.id,
      novelId: data.novelId.present ? data.novelId.value : this.novelId,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      content: data.content.present ? data.content.value : this.content,
      imageData: data.imageData.present ? data.imageData.value : this.imageData,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Entry(')
          ..write('id: $id, ')
          ..write('novelId: $novelId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('content: $content, ')
          ..write('imageData: $imageData, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    novelId,
    kind,
    name,
    content,
    imageData,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Entry &&
          other.id == this.id &&
          other.novelId == this.novelId &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.content == this.content &&
          other.imageData == this.imageData &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class EntriesCompanion extends UpdateCompanion<Entry> {
  final Value<int> id;
  final Value<int> novelId;
  final Value<String> kind;
  final Value<String> name;
  final Value<String> content;
  final Value<String> imageData;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.novelId = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.content = const Value.absent(),
    this.imageData = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  EntriesCompanion.insert({
    this.id = const Value.absent(),
    required int novelId,
    required String kind,
    required String name,
    this.content = const Value.absent(),
    this.imageData = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : novelId = Value(novelId),
       kind = Value(kind),
       name = Value(name);
  static Insertable<Entry> custom({
    Expression<int>? id,
    Expression<int>? novelId,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? content,
    Expression<String>? imageData,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (novelId != null) 'novel_id': novelId,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (content != null) 'content': content,
      if (imageData != null) 'image_data': imageData,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  EntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? novelId,
    Value<String>? kind,
    Value<String>? name,
    Value<String>? content,
    Value<String>? imageData,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return EntriesCompanion(
      id: id ?? this.id,
      novelId: novelId ?? this.novelId,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      content: content ?? this.content,
      imageData: imageData ?? this.imageData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (novelId.present) {
      map['novel_id'] = Variable<int>(novelId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (imageData.present) {
      map['image_data'] = Variable<String>(imageData.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntriesCompanion(')
          ..write('id: $id, ')
          ..write('novelId: $novelId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('content: $content, ')
          ..write('imageData: $imageData, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $EntryLinksTable extends EntryLinks
    with TableInfo<$EntryLinksTable, EntryLink> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntryLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _fromEntryIdMeta = const VerificationMeta(
    'fromEntryId',
  );
  @override
  late final GeneratedColumn<int> fromEntryId = GeneratedColumn<int>(
    'from_entry_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES entries (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _toEntryIdMeta = const VerificationMeta(
    'toEntryId',
  );
  @override
  late final GeneratedColumn<int> toEntryId = GeneratedColumn<int>(
    'to_entry_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES entries (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [id, fromEntryId, toEntryId, label];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entry_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryLink> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('from_entry_id')) {
      context.handle(
        _fromEntryIdMeta,
        fromEntryId.isAcceptableOrUnknown(
          data['from_entry_id']!,
          _fromEntryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fromEntryIdMeta);
    }
    if (data.containsKey('to_entry_id')) {
      context.handle(
        _toEntryIdMeta,
        toEntryId.isAcceptableOrUnknown(data['to_entry_id']!, _toEntryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_toEntryIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EntryLink map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryLink(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fromEntryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}from_entry_id'],
      )!,
      toEntryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}to_entry_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
    );
  }

  @override
  $EntryLinksTable createAlias(String alias) {
    return $EntryLinksTable(attachedDatabase, alias);
  }
}

class EntryLink extends DataClass implements Insertable<EntryLink> {
  final int id;
  final int fromEntryId;
  final int toEntryId;

  /// 关联描述,如“师徒”“位于”“幼年在此学艺”
  final String label;
  const EntryLink({
    required this.id,
    required this.fromEntryId,
    required this.toEntryId,
    required this.label,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['from_entry_id'] = Variable<int>(fromEntryId);
    map['to_entry_id'] = Variable<int>(toEntryId);
    map['label'] = Variable<String>(label);
    return map;
  }

  EntryLinksCompanion toCompanion(bool nullToAbsent) {
    return EntryLinksCompanion(
      id: Value(id),
      fromEntryId: Value(fromEntryId),
      toEntryId: Value(toEntryId),
      label: Value(label),
    );
  }

  factory EntryLink.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryLink(
      id: serializer.fromJson<int>(json['id']),
      fromEntryId: serializer.fromJson<int>(json['fromEntryId']),
      toEntryId: serializer.fromJson<int>(json['toEntryId']),
      label: serializer.fromJson<String>(json['label']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fromEntryId': serializer.toJson<int>(fromEntryId),
      'toEntryId': serializer.toJson<int>(toEntryId),
      'label': serializer.toJson<String>(label),
    };
  }

  EntryLink copyWith({
    int? id,
    int? fromEntryId,
    int? toEntryId,
    String? label,
  }) => EntryLink(
    id: id ?? this.id,
    fromEntryId: fromEntryId ?? this.fromEntryId,
    toEntryId: toEntryId ?? this.toEntryId,
    label: label ?? this.label,
  );
  EntryLink copyWithCompanion(EntryLinksCompanion data) {
    return EntryLink(
      id: data.id.present ? data.id.value : this.id,
      fromEntryId: data.fromEntryId.present
          ? data.fromEntryId.value
          : this.fromEntryId,
      toEntryId: data.toEntryId.present ? data.toEntryId.value : this.toEntryId,
      label: data.label.present ? data.label.value : this.label,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryLink(')
          ..write('id: $id, ')
          ..write('fromEntryId: $fromEntryId, ')
          ..write('toEntryId: $toEntryId, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, fromEntryId, toEntryId, label);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryLink &&
          other.id == this.id &&
          other.fromEntryId == this.fromEntryId &&
          other.toEntryId == this.toEntryId &&
          other.label == this.label);
}

class EntryLinksCompanion extends UpdateCompanion<EntryLink> {
  final Value<int> id;
  final Value<int> fromEntryId;
  final Value<int> toEntryId;
  final Value<String> label;
  const EntryLinksCompanion({
    this.id = const Value.absent(),
    this.fromEntryId = const Value.absent(),
    this.toEntryId = const Value.absent(),
    this.label = const Value.absent(),
  });
  EntryLinksCompanion.insert({
    this.id = const Value.absent(),
    required int fromEntryId,
    required int toEntryId,
    this.label = const Value.absent(),
  }) : fromEntryId = Value(fromEntryId),
       toEntryId = Value(toEntryId);
  static Insertable<EntryLink> custom({
    Expression<int>? id,
    Expression<int>? fromEntryId,
    Expression<int>? toEntryId,
    Expression<String>? label,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fromEntryId != null) 'from_entry_id': fromEntryId,
      if (toEntryId != null) 'to_entry_id': toEntryId,
      if (label != null) 'label': label,
    });
  }

  EntryLinksCompanion copyWith({
    Value<int>? id,
    Value<int>? fromEntryId,
    Value<int>? toEntryId,
    Value<String>? label,
  }) {
    return EntryLinksCompanion(
      id: id ?? this.id,
      fromEntryId: fromEntryId ?? this.fromEntryId,
      toEntryId: toEntryId ?? this.toEntryId,
      label: label ?? this.label,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fromEntryId.present) {
      map['from_entry_id'] = Variable<int>(fromEntryId.value);
    }
    if (toEntryId.present) {
      map['to_entry_id'] = Variable<int>(toEntryId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntryLinksCompanion(')
          ..write('id: $id, ')
          ..write('fromEntryId: $fromEntryId, ')
          ..write('toEntryId: $toEntryId, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }
}

class $EntrySetsTable extends EntrySets
    with TableInfo<$EntrySetsTable, EntrySet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntrySetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _novelIdMeta = const VerificationMeta(
    'novelId',
  );
  @override
  late final GeneratedColumn<int> novelId = GeneratedColumn<int>(
    'novel_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES novels (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryIdsMeta = const VerificationMeta(
    'entryIds',
  );
  @override
  late final GeneratedColumn<String> entryIds = GeneratedColumn<String>(
    'entry_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [id, novelId, name, entryIds];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entry_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntrySet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('novel_id')) {
      context.handle(
        _novelIdMeta,
        novelId.isAcceptableOrUnknown(data['novel_id']!, _novelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_novelIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('entry_ids')) {
      context.handle(
        _entryIdsMeta,
        entryIds.isAcceptableOrUnknown(data['entry_ids']!, _entryIdsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EntrySet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntrySet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      novelId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}novel_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      entryIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_ids'],
      )!,
    );
  }

  @override
  $EntrySetsTable createAlias(String alias) {
    return $EntrySetsTable(attachedDatabase, alias);
  }
}

class EntrySet extends DataClass implements Insertable<EntrySet> {
  final int id;
  final int novelId;
  final String name;

  /// 包含的设定卡 id(逗号分隔)
  final String entryIds;
  const EntrySet({
    required this.id,
    required this.novelId,
    required this.name,
    required this.entryIds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['novel_id'] = Variable<int>(novelId);
    map['name'] = Variable<String>(name);
    map['entry_ids'] = Variable<String>(entryIds);
    return map;
  }

  EntrySetsCompanion toCompanion(bool nullToAbsent) {
    return EntrySetsCompanion(
      id: Value(id),
      novelId: Value(novelId),
      name: Value(name),
      entryIds: Value(entryIds),
    );
  }

  factory EntrySet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntrySet(
      id: serializer.fromJson<int>(json['id']),
      novelId: serializer.fromJson<int>(json['novelId']),
      name: serializer.fromJson<String>(json['name']),
      entryIds: serializer.fromJson<String>(json['entryIds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'novelId': serializer.toJson<int>(novelId),
      'name': serializer.toJson<String>(name),
      'entryIds': serializer.toJson<String>(entryIds),
    };
  }

  EntrySet copyWith({int? id, int? novelId, String? name, String? entryIds}) =>
      EntrySet(
        id: id ?? this.id,
        novelId: novelId ?? this.novelId,
        name: name ?? this.name,
        entryIds: entryIds ?? this.entryIds,
      );
  EntrySet copyWithCompanion(EntrySetsCompanion data) {
    return EntrySet(
      id: data.id.present ? data.id.value : this.id,
      novelId: data.novelId.present ? data.novelId.value : this.novelId,
      name: data.name.present ? data.name.value : this.name,
      entryIds: data.entryIds.present ? data.entryIds.value : this.entryIds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntrySet(')
          ..write('id: $id, ')
          ..write('novelId: $novelId, ')
          ..write('name: $name, ')
          ..write('entryIds: $entryIds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, novelId, name, entryIds);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntrySet &&
          other.id == this.id &&
          other.novelId == this.novelId &&
          other.name == this.name &&
          other.entryIds == this.entryIds);
}

class EntrySetsCompanion extends UpdateCompanion<EntrySet> {
  final Value<int> id;
  final Value<int> novelId;
  final Value<String> name;
  final Value<String> entryIds;
  const EntrySetsCompanion({
    this.id = const Value.absent(),
    this.novelId = const Value.absent(),
    this.name = const Value.absent(),
    this.entryIds = const Value.absent(),
  });
  EntrySetsCompanion.insert({
    this.id = const Value.absent(),
    required int novelId,
    required String name,
    this.entryIds = const Value.absent(),
  }) : novelId = Value(novelId),
       name = Value(name);
  static Insertable<EntrySet> custom({
    Expression<int>? id,
    Expression<int>? novelId,
    Expression<String>? name,
    Expression<String>? entryIds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (novelId != null) 'novel_id': novelId,
      if (name != null) 'name': name,
      if (entryIds != null) 'entry_ids': entryIds,
    });
  }

  EntrySetsCompanion copyWith({
    Value<int>? id,
    Value<int>? novelId,
    Value<String>? name,
    Value<String>? entryIds,
  }) {
    return EntrySetsCompanion(
      id: id ?? this.id,
      novelId: novelId ?? this.novelId,
      name: name ?? this.name,
      entryIds: entryIds ?? this.entryIds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (novelId.present) {
      map['novel_id'] = Variable<int>(novelId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (entryIds.present) {
      map['entry_ids'] = Variable<String>(entryIds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntrySetsCompanion(')
          ..write('id: $id, ')
          ..write('novelId: $novelId, ')
          ..write('name: $name, ')
          ..write('entryIds: $entryIds')
          ..write(')'))
        .toString();
  }
}

class $ChaptersTable extends Chapters with TableInfo<$ChaptersTable, Chapter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChaptersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _novelIdMeta = const VerificationMeta(
    'novelId',
  );
  @override
  late final GeneratedColumn<int> novelId = GeneratedColumn<int>(
    'novel_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES novels (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    novelId,
    title,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapters';
  @override
  VerificationContext validateIntegrity(
    Insertable<Chapter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('novel_id')) {
      context.handle(
        _novelIdMeta,
        novelId.isAcceptableOrUnknown(data['novel_id']!, _novelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_novelIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Chapter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Chapter(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      novelId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}novel_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ChaptersTable createAlias(String alias) {
    return $ChaptersTable(attachedDatabase, alias);
  }
}

class Chapter extends DataClass implements Insertable<Chapter> {
  final int id;
  final int novelId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Chapter({
    required this.id,
    required this.novelId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['novel_id'] = Variable<int>(novelId);
    map['title'] = Variable<String>(title);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ChaptersCompanion toCompanion(bool nullToAbsent) {
    return ChaptersCompanion(
      id: Value(id),
      novelId: Value(novelId),
      title: Value(title),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Chapter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Chapter(
      id: serializer.fromJson<int>(json['id']),
      novelId: serializer.fromJson<int>(json['novelId']),
      title: serializer.fromJson<String>(json['title']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'novelId': serializer.toJson<int>(novelId),
      'title': serializer.toJson<String>(title),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Chapter copyWith({
    int? id,
    int? novelId,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Chapter(
    id: id ?? this.id,
    novelId: novelId ?? this.novelId,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Chapter copyWithCompanion(ChaptersCompanion data) {
    return Chapter(
      id: data.id.present ? data.id.value : this.id,
      novelId: data.novelId.present ? data.novelId.value : this.novelId,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Chapter(')
          ..write('id: $id, ')
          ..write('novelId: $novelId, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, novelId, title, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Chapter &&
          other.id == this.id &&
          other.novelId == this.novelId &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ChaptersCompanion extends UpdateCompanion<Chapter> {
  final Value<int> id;
  final Value<int> novelId;
  final Value<String> title;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ChaptersCompanion({
    this.id = const Value.absent(),
    this.novelId = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ChaptersCompanion.insert({
    this.id = const Value.absent(),
    required int novelId,
    required String title,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : novelId = Value(novelId),
       title = Value(title);
  static Insertable<Chapter> custom({
    Expression<int>? id,
    Expression<int>? novelId,
    Expression<String>? title,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (novelId != null) 'novel_id': novelId,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ChaptersCompanion copyWith({
    Value<int>? id,
    Value<int>? novelId,
    Value<String>? title,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return ChaptersCompanion(
      id: id ?? this.id,
      novelId: novelId ?? this.novelId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (novelId.present) {
      map['novel_id'] = Variable<int>(novelId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChaptersCompanion(')
          ..write('id: $id, ')
          ..write('novelId: $novelId, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ChapterEventsTable extends ChapterEvents
    with TableInfo<$ChapterEventsTable, ChapterEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChapterEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<int> chapterId = GeneratedColumn<int>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chapters (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _outlineMeta = const VerificationMeta(
    'outline',
  );
  @override
  late final GeneratedColumn<String> outline = GeneratedColumn<String>(
    'outline',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _chatLogMeta = const VerificationMeta(
    'chatLog',
  );
  @override
  late final GeneratedColumn<String> chatLog = GeneratedColumn<String>(
    'chat_log',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    chapterId,
    name,
    outline,
    content,
    chatLog,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapter_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChapterEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('outline')) {
      context.handle(
        _outlineMeta,
        outline.isAcceptableOrUnknown(data['outline']!, _outlineMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('chat_log')) {
      context.handle(
        _chatLogMeta,
        chatLog.isAcceptableOrUnknown(data['chat_log']!, _chatLogMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChapterEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChapterEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      outline: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outline'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      chatLog: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chat_log'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ChapterEventsTable createAlias(String alias) {
    return $ChapterEventsTable(attachedDatabase, alias);
  }
}

class ChapterEvent extends DataClass implements Insertable<ChapterEvent> {
  final int id;
  final int chapterId;
  final String name;
  final String outline;
  final String content;

  /// 写作对话历史(JSON)
  final String chatLog;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ChapterEvent({
    required this.id,
    required this.chapterId,
    required this.name,
    required this.outline,
    required this.content,
    required this.chatLog,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['chapter_id'] = Variable<int>(chapterId);
    map['name'] = Variable<String>(name);
    map['outline'] = Variable<String>(outline);
    map['content'] = Variable<String>(content);
    map['chat_log'] = Variable<String>(chatLog);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ChapterEventsCompanion toCompanion(bool nullToAbsent) {
    return ChapterEventsCompanion(
      id: Value(id),
      chapterId: Value(chapterId),
      name: Value(name),
      outline: Value(outline),
      content: Value(content),
      chatLog: Value(chatLog),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ChapterEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChapterEvent(
      id: serializer.fromJson<int>(json['id']),
      chapterId: serializer.fromJson<int>(json['chapterId']),
      name: serializer.fromJson<String>(json['name']),
      outline: serializer.fromJson<String>(json['outline']),
      content: serializer.fromJson<String>(json['content']),
      chatLog: serializer.fromJson<String>(json['chatLog']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'chapterId': serializer.toJson<int>(chapterId),
      'name': serializer.toJson<String>(name),
      'outline': serializer.toJson<String>(outline),
      'content': serializer.toJson<String>(content),
      'chatLog': serializer.toJson<String>(chatLog),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ChapterEvent copyWith({
    int? id,
    int? chapterId,
    String? name,
    String? outline,
    String? content,
    String? chatLog,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ChapterEvent(
    id: id ?? this.id,
    chapterId: chapterId ?? this.chapterId,
    name: name ?? this.name,
    outline: outline ?? this.outline,
    content: content ?? this.content,
    chatLog: chatLog ?? this.chatLog,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ChapterEvent copyWithCompanion(ChapterEventsCompanion data) {
    return ChapterEvent(
      id: data.id.present ? data.id.value : this.id,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      name: data.name.present ? data.name.value : this.name,
      outline: data.outline.present ? data.outline.value : this.outline,
      content: data.content.present ? data.content.value : this.content,
      chatLog: data.chatLog.present ? data.chatLog.value : this.chatLog,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChapterEvent(')
          ..write('id: $id, ')
          ..write('chapterId: $chapterId, ')
          ..write('name: $name, ')
          ..write('outline: $outline, ')
          ..write('content: $content, ')
          ..write('chatLog: $chatLog, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    chapterId,
    name,
    outline,
    content,
    chatLog,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChapterEvent &&
          other.id == this.id &&
          other.chapterId == this.chapterId &&
          other.name == this.name &&
          other.outline == this.outline &&
          other.content == this.content &&
          other.chatLog == this.chatLog &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ChapterEventsCompanion extends UpdateCompanion<ChapterEvent> {
  final Value<int> id;
  final Value<int> chapterId;
  final Value<String> name;
  final Value<String> outline;
  final Value<String> content;
  final Value<String> chatLog;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ChapterEventsCompanion({
    this.id = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.name = const Value.absent(),
    this.outline = const Value.absent(),
    this.content = const Value.absent(),
    this.chatLog = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ChapterEventsCompanion.insert({
    this.id = const Value.absent(),
    required int chapterId,
    this.name = const Value.absent(),
    this.outline = const Value.absent(),
    this.content = const Value.absent(),
    this.chatLog = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : chapterId = Value(chapterId);
  static Insertable<ChapterEvent> custom({
    Expression<int>? id,
    Expression<int>? chapterId,
    Expression<String>? name,
    Expression<String>? outline,
    Expression<String>? content,
    Expression<String>? chatLog,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chapterId != null) 'chapter_id': chapterId,
      if (name != null) 'name': name,
      if (outline != null) 'outline': outline,
      if (content != null) 'content': content,
      if (chatLog != null) 'chat_log': chatLog,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ChapterEventsCompanion copyWith({
    Value<int>? id,
    Value<int>? chapterId,
    Value<String>? name,
    Value<String>? outline,
    Value<String>? content,
    Value<String>? chatLog,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return ChapterEventsCompanion(
      id: id ?? this.id,
      chapterId: chapterId ?? this.chapterId,
      name: name ?? this.name,
      outline: outline ?? this.outline,
      content: content ?? this.content,
      chatLog: chatLog ?? this.chatLog,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<int>(chapterId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (outline.present) {
      map['outline'] = Variable<String>(outline.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (chatLog.present) {
      map['chat_log'] = Variable<String>(chatLog.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChapterEventsCompanion(')
          ..write('id: $id, ')
          ..write('chapterId: $chapterId, ')
          ..write('name: $name, ')
          ..write('outline: $outline, ')
          ..write('content: $content, ')
          ..write('chatLog: $chatLog, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SectionPlotsTable extends SectionPlots
    with TableInfo<$SectionPlotsTable, SectionPlot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SectionPlotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sectionIdMeta = const VerificationMeta(
    'sectionId',
  );
  @override
  late final GeneratedColumn<int> sectionId = GeneratedColumn<int>(
    'section_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chapter_events (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _plotEntryIdMeta = const VerificationMeta(
    'plotEntryId',
  );
  @override
  late final GeneratedColumn<int> plotEntryId = GeneratedColumn<int>(
    'plot_entry_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES entries (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [sectionId, plotEntryId, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'section_plots';
  @override
  VerificationContext validateIntegrity(
    Insertable<SectionPlot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('section_id')) {
      context.handle(
        _sectionIdMeta,
        sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sectionIdMeta);
    }
    if (data.containsKey('plot_entry_id')) {
      context.handle(
        _plotEntryIdMeta,
        plotEntryId.isAcceptableOrUnknown(
          data['plot_entry_id']!,
          _plotEntryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_plotEntryIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sectionId, plotEntryId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {plotEntryId},
  ];
  @override
  SectionPlot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SectionPlot(
      sectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}section_id'],
      )!,
      plotEntryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plot_entry_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $SectionPlotsTable createAlias(String alias) {
    return $SectionPlotsTable(attachedDatabase, alias);
  }
}

class SectionPlot extends DataClass implements Insertable<SectionPlot> {
  final int sectionId;
  final int plotEntryId;
  final int position;
  const SectionPlot({
    required this.sectionId,
    required this.plotEntryId,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['section_id'] = Variable<int>(sectionId);
    map['plot_entry_id'] = Variable<int>(plotEntryId);
    map['position'] = Variable<int>(position);
    return map;
  }

  SectionPlotsCompanion toCompanion(bool nullToAbsent) {
    return SectionPlotsCompanion(
      sectionId: Value(sectionId),
      plotEntryId: Value(plotEntryId),
      position: Value(position),
    );
  }

  factory SectionPlot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SectionPlot(
      sectionId: serializer.fromJson<int>(json['sectionId']),
      plotEntryId: serializer.fromJson<int>(json['plotEntryId']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sectionId': serializer.toJson<int>(sectionId),
      'plotEntryId': serializer.toJson<int>(plotEntryId),
      'position': serializer.toJson<int>(position),
    };
  }

  SectionPlot copyWith({int? sectionId, int? plotEntryId, int? position}) =>
      SectionPlot(
        sectionId: sectionId ?? this.sectionId,
        plotEntryId: plotEntryId ?? this.plotEntryId,
        position: position ?? this.position,
      );
  SectionPlot copyWithCompanion(SectionPlotsCompanion data) {
    return SectionPlot(
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      plotEntryId: data.plotEntryId.present
          ? data.plotEntryId.value
          : this.plotEntryId,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SectionPlot(')
          ..write('sectionId: $sectionId, ')
          ..write('plotEntryId: $plotEntryId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sectionId, plotEntryId, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SectionPlot &&
          other.sectionId == this.sectionId &&
          other.plotEntryId == this.plotEntryId &&
          other.position == this.position);
}

class SectionPlotsCompanion extends UpdateCompanion<SectionPlot> {
  final Value<int> sectionId;
  final Value<int> plotEntryId;
  final Value<int> position;
  final Value<int> rowid;
  const SectionPlotsCompanion({
    this.sectionId = const Value.absent(),
    this.plotEntryId = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SectionPlotsCompanion.insert({
    required int sectionId,
    required int plotEntryId,
    required int position,
    this.rowid = const Value.absent(),
  }) : sectionId = Value(sectionId),
       plotEntryId = Value(plotEntryId),
       position = Value(position);
  static Insertable<SectionPlot> custom({
    Expression<int>? sectionId,
    Expression<int>? plotEntryId,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sectionId != null) 'section_id': sectionId,
      if (plotEntryId != null) 'plot_entry_id': plotEntryId,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SectionPlotsCompanion copyWith({
    Value<int>? sectionId,
    Value<int>? plotEntryId,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return SectionPlotsCompanion(
      sectionId: sectionId ?? this.sectionId,
      plotEntryId: plotEntryId ?? this.plotEntryId,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sectionId.present) {
      map['section_id'] = Variable<int>(sectionId.value);
    }
    if (plotEntryId.present) {
      map['plot_entry_id'] = Variable<int>(plotEntryId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SectionPlotsCompanion(')
          ..write('sectionId: $sectionId, ')
          ..write('plotEntryId: $plotEntryId, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $NovelsTable novels = $NovelsTable(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $EntryLinksTable entryLinks = $EntryLinksTable(this);
  late final $EntrySetsTable entrySets = $EntrySetsTable(this);
  late final $ChaptersTable chapters = $ChaptersTable(this);
  late final $ChapterEventsTable chapterEvents = $ChapterEventsTable(this);
  late final $SectionPlotsTable sectionPlots = $SectionPlotsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    novels,
    entries,
    entryLinks,
    entrySets,
    chapters,
    chapterEvents,
    sectionPlots,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'novels',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'entries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('entry_links', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'entries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('entry_links', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'novels',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('entry_sets', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'novels',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('chapters', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chapters',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('chapter_events', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chapter_events',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('section_plots', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'entries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('section_plots', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$NovelsTableCreateCompanionBuilder =
    NovelsCompanion Function({
      Value<int> id,
      required String title,
      Value<String> description,
      Value<String> styleEntryIds,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$NovelsTableUpdateCompanionBuilder =
    NovelsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> description,
      Value<String> styleEntryIds,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$NovelsTableReferences
    extends BaseReferences<_$AppDatabase, $NovelsTable, Novel> {
  $$NovelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EntriesTable, List<Entry>> _entriesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.entries,
    aliasName: 'novels__id__entries__novel_id',
  );

  $$EntriesTableProcessedTableManager get entriesRefs {
    final manager = $$EntriesTableTableManager(
      $_db,
      $_db.entries,
    ).filter((f) => f.novelId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_entriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EntrySetsTable, List<EntrySet>>
  _entrySetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.entrySets,
    aliasName: 'novels__id__entry_sets__novel_id',
  );

  $$EntrySetsTableProcessedTableManager get entrySetsRefs {
    final manager = $$EntrySetsTableTableManager(
      $_db,
      $_db.entrySets,
    ).filter((f) => f.novelId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_entrySetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ChaptersTable, List<Chapter>> _chaptersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.chapters,
    aliasName: 'novels__id__chapters__novel_id',
  );

  $$ChaptersTableProcessedTableManager get chaptersRefs {
    final manager = $$ChaptersTableTableManager(
      $_db,
      $_db.chapters,
    ).filter((f) => f.novelId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_chaptersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NovelsTableFilterComposer
    extends Composer<_$AppDatabase, $NovelsTable> {
  $$NovelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get styleEntryIds => $composableBuilder(
    column: $table.styleEntryIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> entriesRefs(
    Expression<bool> Function($$EntriesTableFilterComposer f) f,
  ) {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.novelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableFilterComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> entrySetsRefs(
    Expression<bool> Function($$EntrySetsTableFilterComposer f) f,
  ) {
    final $$EntrySetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entrySets,
      getReferencedColumn: (t) => t.novelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntrySetsTableFilterComposer(
            $db: $db,
            $table: $db.entrySets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> chaptersRefs(
    Expression<bool> Function($$ChaptersTableFilterComposer f) f,
  ) {
    final $$ChaptersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.novelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableFilterComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NovelsTableOrderingComposer
    extends Composer<_$AppDatabase, $NovelsTable> {
  $$NovelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get styleEntryIds => $composableBuilder(
    column: $table.styleEntryIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NovelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NovelsTable> {
  $$NovelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get styleEntryIds => $composableBuilder(
    column: $table.styleEntryIds,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> entriesRefs<T extends Object>(
    Expression<T> Function($$EntriesTableAnnotationComposer a) f,
  ) {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.novelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> entrySetsRefs<T extends Object>(
    Expression<T> Function($$EntrySetsTableAnnotationComposer a) f,
  ) {
    final $$EntrySetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entrySets,
      getReferencedColumn: (t) => t.novelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntrySetsTableAnnotationComposer(
            $db: $db,
            $table: $db.entrySets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> chaptersRefs<T extends Object>(
    Expression<T> Function($$ChaptersTableAnnotationComposer a) f,
  ) {
    final $$ChaptersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.novelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableAnnotationComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NovelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NovelsTable,
          Novel,
          $$NovelsTableFilterComposer,
          $$NovelsTableOrderingComposer,
          $$NovelsTableAnnotationComposer,
          $$NovelsTableCreateCompanionBuilder,
          $$NovelsTableUpdateCompanionBuilder,
          (Novel, $$NovelsTableReferences),
          Novel,
          PrefetchHooks Function({
            bool entriesRefs,
            bool entrySetsRefs,
            bool chaptersRefs,
          })
        > {
  $$NovelsTableTableManager(_$AppDatabase db, $NovelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NovelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NovelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NovelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> styleEntryIds = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => NovelsCompanion(
                id: id,
                title: title,
                description: description,
                styleEntryIds: styleEntryIds,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<String> description = const Value.absent(),
                Value<String> styleEntryIds = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => NovelsCompanion.insert(
                id: id,
                title: title,
                description: description,
                styleEntryIds: styleEntryIds,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$NovelsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                entriesRefs = false,
                entrySetsRefs = false,
                chaptersRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (entriesRefs) db.entries,
                    if (entrySetsRefs) db.entrySets,
                    if (chaptersRefs) db.chapters,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (entriesRefs)
                        await $_getPrefetchedData<Novel, $NovelsTable, Entry>(
                          currentTable: table,
                          referencedTable: $$NovelsTableReferences
                              ._entriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NovelsTableReferences(
                                db,
                                table,
                                p0,
                              ).entriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.novelId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (entrySetsRefs)
                        await $_getPrefetchedData<
                          Novel,
                          $NovelsTable,
                          EntrySet
                        >(
                          currentTable: table,
                          referencedTable: $$NovelsTableReferences
                              ._entrySetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NovelsTableReferences(
                                db,
                                table,
                                p0,
                              ).entrySetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.novelId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (chaptersRefs)
                        await $_getPrefetchedData<Novel, $NovelsTable, Chapter>(
                          currentTable: table,
                          referencedTable: $$NovelsTableReferences
                              ._chaptersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NovelsTableReferences(
                                db,
                                table,
                                p0,
                              ).chaptersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.novelId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$NovelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NovelsTable,
      Novel,
      $$NovelsTableFilterComposer,
      $$NovelsTableOrderingComposer,
      $$NovelsTableAnnotationComposer,
      $$NovelsTableCreateCompanionBuilder,
      $$NovelsTableUpdateCompanionBuilder,
      (Novel, $$NovelsTableReferences),
      Novel,
      PrefetchHooks Function({
        bool entriesRefs,
        bool entrySetsRefs,
        bool chaptersRefs,
      })
    >;
typedef $$EntriesTableCreateCompanionBuilder =
    EntriesCompanion Function({
      Value<int> id,
      required int novelId,
      required String kind,
      required String name,
      Value<String> content,
      Value<String> imageData,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$EntriesTableUpdateCompanionBuilder =
    EntriesCompanion Function({
      Value<int> id,
      Value<int> novelId,
      Value<String> kind,
      Value<String> name,
      Value<String> content,
      Value<String> imageData,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$EntriesTableReferences
    extends BaseReferences<_$AppDatabase, $EntriesTable, Entry> {
  $$EntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NovelsTable _novelIdTable(_$AppDatabase db) =>
      db.novels.createAlias('entries__novel_id__novels__id');

  $$NovelsTableProcessedTableManager get novelId {
    final $_column = $_itemColumn<int>('novel_id')!;

    final manager = $$NovelsTableTableManager(
      $_db,
      $_db.novels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_novelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SectionPlotsTable, List<SectionPlot>>
  _sectionPlotsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sectionPlots,
    aliasName: 'entries__id__section_plots__plot_entry_id',
  );

  $$SectionPlotsTableProcessedTableManager get sectionPlotsRefs {
    final manager = $$SectionPlotsTableTableManager(
      $_db,
      $_db.sectionPlots,
    ).filter((f) => f.plotEntryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_sectionPlotsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EntriesTableFilterComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageData => $composableBuilder(
    column: $table.imageData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$NovelsTableFilterComposer get novelId {
    final $$NovelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableFilterComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> sectionPlotsRefs(
    Expression<bool> Function($$SectionPlotsTableFilterComposer f) f,
  ) {
    final $$SectionPlotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sectionPlots,
      getReferencedColumn: (t) => t.plotEntryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SectionPlotsTableFilterComposer(
            $db: $db,
            $table: $db.sectionPlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageData => $composableBuilder(
    column: $table.imageData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$NovelsTableOrderingComposer get novelId {
    final $$NovelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableOrderingComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableAnnotationComposer({
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

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get imageData =>
      $composableBuilder(column: $table.imageData, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$NovelsTableAnnotationComposer get novelId {
    final $$NovelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableAnnotationComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> sectionPlotsRefs<T extends Object>(
    Expression<T> Function($$SectionPlotsTableAnnotationComposer a) f,
  ) {
    final $$SectionPlotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sectionPlots,
      getReferencedColumn: (t) => t.plotEntryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SectionPlotsTableAnnotationComposer(
            $db: $db,
            $table: $db.sectionPlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntriesTable,
          Entry,
          $$EntriesTableFilterComposer,
          $$EntriesTableOrderingComposer,
          $$EntriesTableAnnotationComposer,
          $$EntriesTableCreateCompanionBuilder,
          $$EntriesTableUpdateCompanionBuilder,
          (Entry, $$EntriesTableReferences),
          Entry,
          PrefetchHooks Function({bool novelId, bool sectionPlotsRefs})
        > {
  $$EntriesTableTableManager(_$AppDatabase db, $EntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> novelId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> imageData = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => EntriesCompanion(
                id: id,
                novelId: novelId,
                kind: kind,
                name: name,
                content: content,
                imageData: imageData,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int novelId,
                required String kind,
                required String name,
                Value<String> content = const Value.absent(),
                Value<String> imageData = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => EntriesCompanion.insert(
                id: id,
                novelId: novelId,
                kind: kind,
                name: name,
                content: content,
                imageData: imageData,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({novelId = false, sectionPlotsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (sectionPlotsRefs) db.sectionPlots],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (novelId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.novelId,
                                referencedTable: $$EntriesTableReferences
                                    ._novelIdTable(db),
                                referencedColumn: $$EntriesTableReferences
                                    ._novelIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sectionPlotsRefs)
                    await $_getPrefetchedData<
                      Entry,
                      $EntriesTable,
                      SectionPlot
                    >(
                      currentTable: table,
                      referencedTable: $$EntriesTableReferences
                          ._sectionPlotsRefsTable(db),
                      managerFromTypedResult: (p0) => $$EntriesTableReferences(
                        db,
                        table,
                        p0,
                      ).sectionPlotsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.plotEntryId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$EntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntriesTable,
      Entry,
      $$EntriesTableFilterComposer,
      $$EntriesTableOrderingComposer,
      $$EntriesTableAnnotationComposer,
      $$EntriesTableCreateCompanionBuilder,
      $$EntriesTableUpdateCompanionBuilder,
      (Entry, $$EntriesTableReferences),
      Entry,
      PrefetchHooks Function({bool novelId, bool sectionPlotsRefs})
    >;
typedef $$EntryLinksTableCreateCompanionBuilder =
    EntryLinksCompanion Function({
      Value<int> id,
      required int fromEntryId,
      required int toEntryId,
      Value<String> label,
    });
typedef $$EntryLinksTableUpdateCompanionBuilder =
    EntryLinksCompanion Function({
      Value<int> id,
      Value<int> fromEntryId,
      Value<int> toEntryId,
      Value<String> label,
    });

final class $$EntryLinksTableReferences
    extends BaseReferences<_$AppDatabase, $EntryLinksTable, EntryLink> {
  $$EntryLinksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EntriesTable _fromEntryIdTable(_$AppDatabase db) =>
      db.entries.createAlias('entry_links__from_entry_id__entries__id');

  $$EntriesTableProcessedTableManager get fromEntryId {
    final $_column = $_itemColumn<int>('from_entry_id')!;

    final manager = $$EntriesTableTableManager(
      $_db,
      $_db.entries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_fromEntryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $EntriesTable _toEntryIdTable(_$AppDatabase db) =>
      db.entries.createAlias('entry_links__to_entry_id__entries__id');

  $$EntriesTableProcessedTableManager get toEntryId {
    final $_column = $_itemColumn<int>('to_entry_id')!;

    final manager = $$EntriesTableTableManager(
      $_db,
      $_db.entries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_toEntryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EntryLinksTableFilterComposer
    extends Composer<_$AppDatabase, $EntryLinksTable> {
  $$EntryLinksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  $$EntriesTableFilterComposer get fromEntryId {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fromEntryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableFilterComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EntriesTableFilterComposer get toEntryId {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.toEntryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableFilterComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntryLinksTableOrderingComposer
    extends Composer<_$AppDatabase, $EntryLinksTable> {
  $$EntryLinksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  $$EntriesTableOrderingComposer get fromEntryId {
    final $$EntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fromEntryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableOrderingComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EntriesTableOrderingComposer get toEntryId {
    final $$EntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.toEntryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableOrderingComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntryLinksTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntryLinksTable> {
  $$EntryLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  $$EntriesTableAnnotationComposer get fromEntryId {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fromEntryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EntriesTableAnnotationComposer get toEntryId {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.toEntryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntryLinksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntryLinksTable,
          EntryLink,
          $$EntryLinksTableFilterComposer,
          $$EntryLinksTableOrderingComposer,
          $$EntryLinksTableAnnotationComposer,
          $$EntryLinksTableCreateCompanionBuilder,
          $$EntryLinksTableUpdateCompanionBuilder,
          (EntryLink, $$EntryLinksTableReferences),
          EntryLink,
          PrefetchHooks Function({bool fromEntryId, bool toEntryId})
        > {
  $$EntryLinksTableTableManager(_$AppDatabase db, $EntryLinksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntryLinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntryLinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntryLinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> fromEntryId = const Value.absent(),
                Value<int> toEntryId = const Value.absent(),
                Value<String> label = const Value.absent(),
              }) => EntryLinksCompanion(
                id: id,
                fromEntryId: fromEntryId,
                toEntryId: toEntryId,
                label: label,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int fromEntryId,
                required int toEntryId,
                Value<String> label = const Value.absent(),
              }) => EntryLinksCompanion.insert(
                id: id,
                fromEntryId: fromEntryId,
                toEntryId: toEntryId,
                label: label,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EntryLinksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({fromEntryId = false, toEntryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (fromEntryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.fromEntryId,
                                referencedTable: $$EntryLinksTableReferences
                                    ._fromEntryIdTable(db),
                                referencedColumn: $$EntryLinksTableReferences
                                    ._fromEntryIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (toEntryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.toEntryId,
                                referencedTable: $$EntryLinksTableReferences
                                    ._toEntryIdTable(db),
                                referencedColumn: $$EntryLinksTableReferences
                                    ._toEntryIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EntryLinksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntryLinksTable,
      EntryLink,
      $$EntryLinksTableFilterComposer,
      $$EntryLinksTableOrderingComposer,
      $$EntryLinksTableAnnotationComposer,
      $$EntryLinksTableCreateCompanionBuilder,
      $$EntryLinksTableUpdateCompanionBuilder,
      (EntryLink, $$EntryLinksTableReferences),
      EntryLink,
      PrefetchHooks Function({bool fromEntryId, bool toEntryId})
    >;
typedef $$EntrySetsTableCreateCompanionBuilder =
    EntrySetsCompanion Function({
      Value<int> id,
      required int novelId,
      required String name,
      Value<String> entryIds,
    });
typedef $$EntrySetsTableUpdateCompanionBuilder =
    EntrySetsCompanion Function({
      Value<int> id,
      Value<int> novelId,
      Value<String> name,
      Value<String> entryIds,
    });

final class $$EntrySetsTableReferences
    extends BaseReferences<_$AppDatabase, $EntrySetsTable, EntrySet> {
  $$EntrySetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NovelsTable _novelIdTable(_$AppDatabase db) =>
      db.novels.createAlias('entry_sets__novel_id__novels__id');

  $$NovelsTableProcessedTableManager get novelId {
    final $_column = $_itemColumn<int>('novel_id')!;

    final manager = $$NovelsTableTableManager(
      $_db,
      $_db.novels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_novelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EntrySetsTableFilterComposer
    extends Composer<_$AppDatabase, $EntrySetsTable> {
  $$EntrySetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryIds => $composableBuilder(
    column: $table.entryIds,
    builder: (column) => ColumnFilters(column),
  );

  $$NovelsTableFilterComposer get novelId {
    final $$NovelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableFilterComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntrySetsTableOrderingComposer
    extends Composer<_$AppDatabase, $EntrySetsTable> {
  $$EntrySetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryIds => $composableBuilder(
    column: $table.entryIds,
    builder: (column) => ColumnOrderings(column),
  );

  $$NovelsTableOrderingComposer get novelId {
    final $$NovelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableOrderingComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntrySetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntrySetsTable> {
  $$EntrySetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get entryIds =>
      $composableBuilder(column: $table.entryIds, builder: (column) => column);

  $$NovelsTableAnnotationComposer get novelId {
    final $$NovelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableAnnotationComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntrySetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntrySetsTable,
          EntrySet,
          $$EntrySetsTableFilterComposer,
          $$EntrySetsTableOrderingComposer,
          $$EntrySetsTableAnnotationComposer,
          $$EntrySetsTableCreateCompanionBuilder,
          $$EntrySetsTableUpdateCompanionBuilder,
          (EntrySet, $$EntrySetsTableReferences),
          EntrySet,
          PrefetchHooks Function({bool novelId})
        > {
  $$EntrySetsTableTableManager(_$AppDatabase db, $EntrySetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntrySetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntrySetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntrySetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> novelId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> entryIds = const Value.absent(),
              }) => EntrySetsCompanion(
                id: id,
                novelId: novelId,
                name: name,
                entryIds: entryIds,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int novelId,
                required String name,
                Value<String> entryIds = const Value.absent(),
              }) => EntrySetsCompanion.insert(
                id: id,
                novelId: novelId,
                name: name,
                entryIds: entryIds,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EntrySetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({novelId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (novelId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.novelId,
                                referencedTable: $$EntrySetsTableReferences
                                    ._novelIdTable(db),
                                referencedColumn: $$EntrySetsTableReferences
                                    ._novelIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EntrySetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntrySetsTable,
      EntrySet,
      $$EntrySetsTableFilterComposer,
      $$EntrySetsTableOrderingComposer,
      $$EntrySetsTableAnnotationComposer,
      $$EntrySetsTableCreateCompanionBuilder,
      $$EntrySetsTableUpdateCompanionBuilder,
      (EntrySet, $$EntrySetsTableReferences),
      EntrySet,
      PrefetchHooks Function({bool novelId})
    >;
typedef $$ChaptersTableCreateCompanionBuilder =
    ChaptersCompanion Function({
      Value<int> id,
      required int novelId,
      required String title,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$ChaptersTableUpdateCompanionBuilder =
    ChaptersCompanion Function({
      Value<int> id,
      Value<int> novelId,
      Value<String> title,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$ChaptersTableReferences
    extends BaseReferences<_$AppDatabase, $ChaptersTable, Chapter> {
  $$ChaptersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NovelsTable _novelIdTable(_$AppDatabase db) =>
      db.novels.createAlias('chapters__novel_id__novels__id');

  $$NovelsTableProcessedTableManager get novelId {
    final $_column = $_itemColumn<int>('novel_id')!;

    final manager = $$NovelsTableTableManager(
      $_db,
      $_db.novels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_novelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ChapterEventsTable, List<ChapterEvent>>
  _chapterEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.chapterEvents,
    aliasName: 'chapters__id__chapter_events__chapter_id',
  );

  $$ChapterEventsTableProcessedTableManager get chapterEventsRefs {
    final manager = $$ChapterEventsTableTableManager(
      $_db,
      $_db.chapterEvents,
    ).filter((f) => f.chapterId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_chapterEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ChaptersTableFilterComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$NovelsTableFilterComposer get novelId {
    final $$NovelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableFilterComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> chapterEventsRefs(
    Expression<bool> Function($$ChapterEventsTableFilterComposer f) f,
  ) {
    final $$ChapterEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chapterEvents,
      getReferencedColumn: (t) => t.chapterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChapterEventsTableFilterComposer(
            $db: $db,
            $table: $db.chapterEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChaptersTableOrderingComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$NovelsTableOrderingComposer get novelId {
    final $$NovelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableOrderingComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChaptersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$NovelsTableAnnotationComposer get novelId {
    final $$NovelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.novelId,
      referencedTable: $db.novels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NovelsTableAnnotationComposer(
            $db: $db,
            $table: $db.novels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> chapterEventsRefs<T extends Object>(
    Expression<T> Function($$ChapterEventsTableAnnotationComposer a) f,
  ) {
    final $$ChapterEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chapterEvents,
      getReferencedColumn: (t) => t.chapterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChapterEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.chapterEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChaptersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChaptersTable,
          Chapter,
          $$ChaptersTableFilterComposer,
          $$ChaptersTableOrderingComposer,
          $$ChaptersTableAnnotationComposer,
          $$ChaptersTableCreateCompanionBuilder,
          $$ChaptersTableUpdateCompanionBuilder,
          (Chapter, $$ChaptersTableReferences),
          Chapter,
          PrefetchHooks Function({bool novelId, bool chapterEventsRefs})
        > {
  $$ChaptersTableTableManager(_$AppDatabase db, $ChaptersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChaptersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChaptersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChaptersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> novelId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ChaptersCompanion(
                id: id,
                novelId: novelId,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int novelId,
                required String title,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ChaptersCompanion.insert(
                id: id,
                novelId: novelId,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ChaptersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({novelId = false, chapterEventsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (chapterEventsRefs) db.chapterEvents,
                  ],
                  addJoins:
                      <
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
                          dynamic
                        >
                      >(state) {
                        if (novelId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.novelId,
                                    referencedTable: $$ChaptersTableReferences
                                        ._novelIdTable(db),
                                    referencedColumn: $$ChaptersTableReferences
                                        ._novelIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (chapterEventsRefs)
                        await $_getPrefetchedData<
                          Chapter,
                          $ChaptersTable,
                          ChapterEvent
                        >(
                          currentTable: table,
                          referencedTable: $$ChaptersTableReferences
                              ._chapterEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChaptersTableReferences(
                                db,
                                table,
                                p0,
                              ).chapterEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.chapterId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ChaptersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChaptersTable,
      Chapter,
      $$ChaptersTableFilterComposer,
      $$ChaptersTableOrderingComposer,
      $$ChaptersTableAnnotationComposer,
      $$ChaptersTableCreateCompanionBuilder,
      $$ChaptersTableUpdateCompanionBuilder,
      (Chapter, $$ChaptersTableReferences),
      Chapter,
      PrefetchHooks Function({bool novelId, bool chapterEventsRefs})
    >;
typedef $$ChapterEventsTableCreateCompanionBuilder =
    ChapterEventsCompanion Function({
      Value<int> id,
      required int chapterId,
      Value<String> name,
      Value<String> outline,
      Value<String> content,
      Value<String> chatLog,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$ChapterEventsTableUpdateCompanionBuilder =
    ChapterEventsCompanion Function({
      Value<int> id,
      Value<int> chapterId,
      Value<String> name,
      Value<String> outline,
      Value<String> content,
      Value<String> chatLog,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$ChapterEventsTableReferences
    extends BaseReferences<_$AppDatabase, $ChapterEventsTable, ChapterEvent> {
  $$ChapterEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ChaptersTable _chapterIdTable(_$AppDatabase db) =>
      db.chapters.createAlias('chapter_events__chapter_id__chapters__id');

  $$ChaptersTableProcessedTableManager get chapterId {
    final $_column = $_itemColumn<int>('chapter_id')!;

    final manager = $$ChaptersTableTableManager(
      $_db,
      $_db.chapters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_chapterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SectionPlotsTable, List<SectionPlot>>
  _sectionPlotsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sectionPlots,
    aliasName: 'chapter_events__id__section_plots__section_id',
  );

  $$SectionPlotsTableProcessedTableManager get sectionPlotsRefs {
    final manager = $$SectionPlotsTableTableManager(
      $_db,
      $_db.sectionPlots,
    ).filter((f) => f.sectionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_sectionPlotsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ChapterEventsTableFilterComposer
    extends Composer<_$AppDatabase, $ChapterEventsTable> {
  $$ChapterEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outline => $composableBuilder(
    column: $table.outline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chatLog => $composableBuilder(
    column: $table.chatLog,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ChaptersTableFilterComposer get chapterId {
    final $$ChaptersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableFilterComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> sectionPlotsRefs(
    Expression<bool> Function($$SectionPlotsTableFilterComposer f) f,
  ) {
    final $$SectionPlotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sectionPlots,
      getReferencedColumn: (t) => t.sectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SectionPlotsTableFilterComposer(
            $db: $db,
            $table: $db.sectionPlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChapterEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChapterEventsTable> {
  $$ChapterEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outline => $composableBuilder(
    column: $table.outline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chatLog => $composableBuilder(
    column: $table.chatLog,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChaptersTableOrderingComposer get chapterId {
    final $$ChaptersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableOrderingComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChapterEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChapterEventsTable> {
  $$ChapterEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get outline =>
      $composableBuilder(column: $table.outline, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get chatLog =>
      $composableBuilder(column: $table.chatLog, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ChaptersTableAnnotationComposer get chapterId {
    final $$ChaptersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableAnnotationComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> sectionPlotsRefs<T extends Object>(
    Expression<T> Function($$SectionPlotsTableAnnotationComposer a) f,
  ) {
    final $$SectionPlotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sectionPlots,
      getReferencedColumn: (t) => t.sectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SectionPlotsTableAnnotationComposer(
            $db: $db,
            $table: $db.sectionPlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChapterEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChapterEventsTable,
          ChapterEvent,
          $$ChapterEventsTableFilterComposer,
          $$ChapterEventsTableOrderingComposer,
          $$ChapterEventsTableAnnotationComposer,
          $$ChapterEventsTableCreateCompanionBuilder,
          $$ChapterEventsTableUpdateCompanionBuilder,
          (ChapterEvent, $$ChapterEventsTableReferences),
          ChapterEvent,
          PrefetchHooks Function({bool chapterId, bool sectionPlotsRefs})
        > {
  $$ChapterEventsTableTableManager(_$AppDatabase db, $ChapterEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChapterEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChapterEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChapterEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> chapterId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> outline = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> chatLog = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ChapterEventsCompanion(
                id: id,
                chapterId: chapterId,
                name: name,
                outline: outline,
                content: content,
                chatLog: chatLog,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int chapterId,
                Value<String> name = const Value.absent(),
                Value<String> outline = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> chatLog = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ChapterEventsCompanion.insert(
                id: id,
                chapterId: chapterId,
                name: name,
                outline: outline,
                content: content,
                chatLog: chatLog,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ChapterEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({chapterId = false, sectionPlotsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sectionPlotsRefs) db.sectionPlots,
                  ],
                  addJoins:
                      <
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
                          dynamic
                        >
                      >(state) {
                        if (chapterId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.chapterId,
                                    referencedTable:
                                        $$ChapterEventsTableReferences
                                            ._chapterIdTable(db),
                                    referencedColumn:
                                        $$ChapterEventsTableReferences
                                            ._chapterIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sectionPlotsRefs)
                        await $_getPrefetchedData<
                          ChapterEvent,
                          $ChapterEventsTable,
                          SectionPlot
                        >(
                          currentTable: table,
                          referencedTable: $$ChapterEventsTableReferences
                              ._sectionPlotsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChapterEventsTableReferences(
                                db,
                                table,
                                p0,
                              ).sectionPlotsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sectionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ChapterEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChapterEventsTable,
      ChapterEvent,
      $$ChapterEventsTableFilterComposer,
      $$ChapterEventsTableOrderingComposer,
      $$ChapterEventsTableAnnotationComposer,
      $$ChapterEventsTableCreateCompanionBuilder,
      $$ChapterEventsTableUpdateCompanionBuilder,
      (ChapterEvent, $$ChapterEventsTableReferences),
      ChapterEvent,
      PrefetchHooks Function({bool chapterId, bool sectionPlotsRefs})
    >;
typedef $$SectionPlotsTableCreateCompanionBuilder =
    SectionPlotsCompanion Function({
      required int sectionId,
      required int plotEntryId,
      required int position,
      Value<int> rowid,
    });
typedef $$SectionPlotsTableUpdateCompanionBuilder =
    SectionPlotsCompanion Function({
      Value<int> sectionId,
      Value<int> plotEntryId,
      Value<int> position,
      Value<int> rowid,
    });

final class $$SectionPlotsTableReferences
    extends BaseReferences<_$AppDatabase, $SectionPlotsTable, SectionPlot> {
  $$SectionPlotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ChapterEventsTable _sectionIdTable(_$AppDatabase db) => db
      .chapterEvents
      .createAlias('section_plots__section_id__chapter_events__id');

  $$ChapterEventsTableProcessedTableManager get sectionId {
    final $_column = $_itemColumn<int>('section_id')!;

    final manager = $$ChapterEventsTableTableManager(
      $_db,
      $_db.chapterEvents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $EntriesTable _plotEntryIdTable(_$AppDatabase db) =>
      db.entries.createAlias('section_plots__plot_entry_id__entries__id');

  $$EntriesTableProcessedTableManager get plotEntryId {
    final $_column = $_itemColumn<int>('plot_entry_id')!;

    final manager = $$EntriesTableTableManager(
      $_db,
      $_db.entries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_plotEntryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SectionPlotsTableFilterComposer
    extends Composer<_$AppDatabase, $SectionPlotsTable> {
  $$SectionPlotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$ChapterEventsTableFilterComposer get sectionId {
    final $$ChapterEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sectionId,
      referencedTable: $db.chapterEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChapterEventsTableFilterComposer(
            $db: $db,
            $table: $db.chapterEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EntriesTableFilterComposer get plotEntryId {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.plotEntryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableFilterComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SectionPlotsTableOrderingComposer
    extends Composer<_$AppDatabase, $SectionPlotsTable> {
  $$SectionPlotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChapterEventsTableOrderingComposer get sectionId {
    final $$ChapterEventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sectionId,
      referencedTable: $db.chapterEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChapterEventsTableOrderingComposer(
            $db: $db,
            $table: $db.chapterEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EntriesTableOrderingComposer get plotEntryId {
    final $$EntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.plotEntryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableOrderingComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SectionPlotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SectionPlotsTable> {
  $$SectionPlotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$ChapterEventsTableAnnotationComposer get sectionId {
    final $$ChapterEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sectionId,
      referencedTable: $db.chapterEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChapterEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.chapterEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EntriesTableAnnotationComposer get plotEntryId {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.plotEntryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SectionPlotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SectionPlotsTable,
          SectionPlot,
          $$SectionPlotsTableFilterComposer,
          $$SectionPlotsTableOrderingComposer,
          $$SectionPlotsTableAnnotationComposer,
          $$SectionPlotsTableCreateCompanionBuilder,
          $$SectionPlotsTableUpdateCompanionBuilder,
          (SectionPlot, $$SectionPlotsTableReferences),
          SectionPlot,
          PrefetchHooks Function({bool sectionId, bool plotEntryId})
        > {
  $$SectionPlotsTableTableManager(_$AppDatabase db, $SectionPlotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SectionPlotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SectionPlotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SectionPlotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> sectionId = const Value.absent(),
                Value<int> plotEntryId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SectionPlotsCompanion(
                sectionId: sectionId,
                plotEntryId: plotEntryId,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int sectionId,
                required int plotEntryId,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => SectionPlotsCompanion.insert(
                sectionId: sectionId,
                plotEntryId: plotEntryId,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SectionPlotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sectionId = false, plotEntryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (sectionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sectionId,
                                referencedTable: $$SectionPlotsTableReferences
                                    ._sectionIdTable(db),
                                referencedColumn: $$SectionPlotsTableReferences
                                    ._sectionIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (plotEntryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.plotEntryId,
                                referencedTable: $$SectionPlotsTableReferences
                                    ._plotEntryIdTable(db),
                                referencedColumn: $$SectionPlotsTableReferences
                                    ._plotEntryIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SectionPlotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SectionPlotsTable,
      SectionPlot,
      $$SectionPlotsTableFilterComposer,
      $$SectionPlotsTableOrderingComposer,
      $$SectionPlotsTableAnnotationComposer,
      $$SectionPlotsTableCreateCompanionBuilder,
      $$SectionPlotsTableUpdateCompanionBuilder,
      (SectionPlot, $$SectionPlotsTableReferences),
      SectionPlot,
      PrefetchHooks Function({bool sectionId, bool plotEntryId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$NovelsTableTableManager get novels =>
      $$NovelsTableTableManager(_db, _db.novels);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$EntryLinksTableTableManager get entryLinks =>
      $$EntryLinksTableTableManager(_db, _db.entryLinks);
  $$EntrySetsTableTableManager get entrySets =>
      $$EntrySetsTableTableManager(_db, _db.entrySets);
  $$ChaptersTableTableManager get chapters =>
      $$ChaptersTableTableManager(_db, _db.chapters);
  $$ChapterEventsTableTableManager get chapterEvents =>
      $$ChapterEventsTableTableManager(_db, _db.chapterEvents);
  $$SectionPlotsTableTableManager get sectionPlots =>
      $$SectionPlotsTableTableManager(_db, _db.sectionPlots);
}
