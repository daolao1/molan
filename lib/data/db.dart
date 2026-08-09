import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart' show IconData, Icons;

part 'db.g.dart';

/// 小说
class Novels extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 小说下的设定条目(人物/地点/物品/场景)
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get novelId =>
      integer().references(Novels, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()();
  TextColumn get name => text()();
  TextColumn get content => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

enum EntryKind {
  character('人物', Icons.person_outline),
  location('地点', Icons.place_outlined),
  item('物品', Icons.category_outlined),
  scene('场景', Icons.theaters_outlined);

  const EntryKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

@DriftDatabase(tables: [Novels, Entries])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'molan',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // ---- 小说 ----
  Stream<List<Novel>> watchNovels() => (select(novels)
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
      .watch();

  Future<int> createNovel(String title, String description) =>
      into(novels).insert(
          NovelsCompanion.insert(title: title, description: Value(description)));

  Future<void> deleteNovel(int id) =>
      (delete(novels)..where((t) => t.id.equals(id))).go();

  // ---- 条目 ----
  Stream<List<Entry>> watchEntries(int novelId, EntryKind kind) =>
      (select(entries)
            ..where((t) => t.novelId.equals(novelId) & t.kind.equals(kind.name))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  Future<int> createEntry(
          int novelId, EntryKind kind, String name, String content) =>
      into(entries).insert(EntriesCompanion.insert(
          novelId: novelId,
          kind: kind.name,
          name: name,
          content: Value(content)));

  /// 同类型已有条目名(供 AI 生成时避免重名)
  Future<List<String>> entryNames(int novelId, EntryKind kind) async {
    final rows = await (select(entries)
          ..where((t) => t.novelId.equals(novelId) & t.kind.equals(kind.name)))
        .get();
    return [for (final r in rows) r.name];
  }

  Future<void> updateEntry(int id, String name, String content) =>
      (update(entries)..where((t) => t.id.equals(id))).write(EntriesCompanion(
          name: Value(name),
          content: Value(content),
          updatedAt: Value(DateTime.now())));

  Future<void> deleteEntry(int id) =>
      (delete(entries)..where((t) => t.id.equals(id))).go();
}
