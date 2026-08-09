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

  /// 场景所属的地点条目 id
  IntColumn get parentId => integer()
      .nullable()
      .references(Entries, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 人物间关系(有向:from → to)
class CharacterRelations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get fromEntryId =>
      integer().references(Entries, #id, onDelete: KeyAction.cascade)();
  IntColumn get toEntryId =>
      integer().references(Entries, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text()();
}

/// 通用条目关联(设定 → 任意卡片)
class EntryLinks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get fromEntryId =>
      integer().references(Entries, #id, onDelete: KeyAction.cascade)();
  IntColumn get toEntryId =>
      integer().references(Entries, #id, onDelete: KeyAction.cascade)();
}

/// 章节:只有标题,内容由事件拼接
class Chapters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get novelId =>
      integer().references(Novels, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 章节内的事件:大纲驱动正文
class ChapterEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get chapterId =>
      integer().references(Chapters, #id, onDelete: KeyAction.cascade)();
  TextColumn get outline => text().withDefault(const Constant(''))();
  TextColumn get content => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

enum EntryKind {
  character('人物', Icons.person_outline),
  location('地点', Icons.place_outlined),
  item('物品', Icons.category_outlined),
  scene('场景', Icons.pin_drop_outlined),
  lore('设定', Icons.public_outlined);

  const EntryKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

@DriftDatabase(
    tables: [Novels, Entries, CharacterRelations, EntryLinks, Chapters, ChapterEvents])
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
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(characterRelations);
          if (from < 3) await m.addColumn(entries, entries.parentId);
          if (from < 4) await m.createTable(entryLinks);
          if (from < 5) {
            await m.createTable(chapters);
            await m.createTable(chapterEvents);
          }
        },
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
          int novelId, EntryKind kind, String name, String content,
          {int? parentId}) =>
      into(entries).insert(EntriesCompanion.insert(
          novelId: novelId,
          kind: kind.name,
          name: name,
          content: Value(content),
          parentId: Value(parentId)));

  /// 某地点下的场景列表
  Stream<List<Entry>> watchScenesOf(int locationId) => (select(entries)
        ..where((t) =>
            t.parentId.equals(locationId) &
            t.kind.equals(EntryKind.scene.name))
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
      .watch();

  /// 本小说全部条目(供 AI 生成构建上下文)
  Future<List<Entry>> allEntriesOf(int novelId) =>
      (select(entries)..where((t) => t.novelId.equals(novelId))).get();

  /// 本小说全部人物关系
  Future<List<CharacterRelation>> relationsOfNovel(int novelId) async {
    final q = select(characterRelations).join([
      innerJoin(entries, entries.id.equalsExp(characterRelations.fromEntryId))
    ])
      ..where(entries.novelId.equals(novelId));
    return [for (final r in await q.get()) r.readTable(characterRelations)];
  }

  // ---- 通用关联 ----
  Future<List<EntryLink>> linksFrom(int entryId) =>
      (select(entryLinks)..where((t) => t.fromEntryId.equals(entryId))).get();

  Future<List<EntryLink>> linksOfNovel(int novelId) async {
    final q = select(entryLinks).join([
      innerJoin(entries, entries.id.equalsExp(entryLinks.fromEntryId))
    ])
      ..where(entries.novelId.equals(novelId));
    return [for (final r in await q.get()) r.readTable(entryLinks)];
  }

  /// 重写某条目发起的全部关联
  Future<void> replaceLinksFrom(int entryId, List<int> toIds) =>
      transaction(() async {
        await (delete(entryLinks)
              ..where((t) => t.fromEntryId.equals(entryId)))
            .go();
        for (final toId in toIds) {
          await into(entryLinks).insert(EntryLinksCompanion.insert(
              fromEntryId: entryId, toEntryId: toId));
        }
      });

  // ---- 章节与事件 ----
  Stream<List<Chapter>> watchChapters(int novelId) => (select(chapters)
        ..where((t) => t.novelId.equals(novelId))
        ..orderBy([(t) => OrderingTerm.asc(t.id)]))
      .watch();

  Future<int> createChapter(int novelId, String title) =>
      into(chapters).insert(
          ChaptersCompanion.insert(novelId: novelId, title: title));

  Future<void> renameChapter(int id, String title) =>
      (update(chapters)..where((t) => t.id.equals(id))).write(
          ChaptersCompanion(
              title: Value(title), updatedAt: Value(DateTime.now())));

  Future<void> deleteChapter(int id) =>
      (delete(chapters)..where((t) => t.id.equals(id))).go();

  Stream<List<ChapterEvent>> watchEvents(int chapterId) =>
      (select(chapterEvents)
            ..where((t) => t.chapterId.equals(chapterId))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .watch();

  Future<List<ChapterEvent>> eventsOf(int chapterId) => (select(chapterEvents)
        ..where((t) => t.chapterId.equals(chapterId))
        ..orderBy([(t) => OrderingTerm.asc(t.id)]))
      .get();

  Future<int> createEvent(int chapterId, String outline) =>
      into(chapterEvents).insert(ChapterEventsCompanion.insert(
          chapterId: chapterId, outline: Value(outline)));

  Future<void> updateEvent(int id, {String? outline, String? content}) =>
      (update(chapterEvents)..where((t) => t.id.equals(id)))
          .write(ChapterEventsCompanion(
        outline: outline == null ? const Value.absent() : Value(outline),
        content: content == null ? const Value.absent() : Value(content),
        updatedAt: Value(DateTime.now()),
      ));

  Future<void> deleteEvent(int id) =>
      (delete(chapterEvents)..where((t) => t.id.equals(id))).go();

  Future<void> updateEntry(int id, String name, String content) =>
      (update(entries)..where((t) => t.id.equals(id))).write(EntriesCompanion(
          name: Value(name),
          content: Value(content),
          updatedAt: Value(DateTime.now())));

  Future<void> deleteEntry(int id) =>
      (delete(entries)..where((t) => t.id.equals(id))).go();

  // ---- 人物关系 ----
  /// 本小说全部人物(供关系选择器)
  Future<List<Entry>> charactersOf(int novelId) => (select(entries)
        ..where((t) =>
            t.novelId.equals(novelId) &
            t.kind.equals(EntryKind.character.name))
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .get();

  Future<List<CharacterRelation>> relationsFrom(int entryId) =>
      (select(characterRelations)..where((t) => t.fromEntryId.equals(entryId)))
          .get();

  Future<List<CharacterRelation>> relationsTo(int entryId) =>
      (select(characterRelations)..where((t) => t.toEntryId.equals(entryId)))
          .get();

  /// 重写某人物发起的全部关系
  Future<void> replaceRelationsFrom(
      int entryId, List<({int toId, String label})> rels) =>
      transaction(() async {
        await (delete(characterRelations)
              ..where((t) => t.fromEntryId.equals(entryId)))
            .go();
        for (final r in rels) {
          await into(characterRelations).insert(CharacterRelationsCompanion
              .insert(fromEntryId: entryId, toEntryId: r.toId, label: r.label));
        }
      });

  /// 导入一本小说(条目用数组索引引用关系与父级),返回新小说 id
  Future<int> importNovel(
    String title,
    String description,
    List<({String kind, String name, String content, int? parent})> entryRows,
    List<({int from, int to, String label})> relRows,
    List<({int from, int to})> linkRows,
    List<({String title, List<({String outline, String content})> events})>
        chapterRows,
  ) =>
      transaction(() async {
        final novelId = await createNovel(title, description);
        final ids = <int>[];
        for (final e in entryRows) {
          ids.add(await into(entries).insert(EntriesCompanion.insert(
              novelId: novelId,
              kind: e.kind,
              name: e.name,
              content: Value(e.content))));
        }
        // 二次遍历补父级,因父条目可能排在子条目之后
        for (var i = 0; i < entryRows.length; i++) {
          final p = entryRows[i].parent;
          if (p != null && p >= 0 && p < ids.length && p != i) {
            await (update(entries)..where((t) => t.id.equals(ids[i])))
                .write(EntriesCompanion(parentId: Value(ids[p])));
          }
        }
        for (final r in relRows) {
          if (r.from < 0 || r.from >= ids.length) continue;
          if (r.to < 0 || r.to >= ids.length) continue;
          await into(characterRelations).insert(
              CharacterRelationsCompanion.insert(
                  fromEntryId: ids[r.from],
                  toEntryId: ids[r.to],
                  label: r.label));
        }
        for (final l in linkRows) {
          if (l.from < 0 || l.from >= ids.length) continue;
          if (l.to < 0 || l.to >= ids.length) continue;
          await into(entryLinks).insert(EntryLinksCompanion.insert(
              fromEntryId: ids[l.from], toEntryId: ids[l.to]));
        }
        for (final c in chapterRows) {
          final chapterId = await createChapter(novelId, c.title);
          for (final e in c.events) {
            final eventId = await createEvent(chapterId, e.outline);
            if (e.content.isNotEmpty) {
              await updateEvent(eventId, content: e.content);
            }
          }
        }
        return novelId;
      });
}
