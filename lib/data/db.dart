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

/// 小说下的设定条目(人物/地点/物品/场景/设定)
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

/// 通用条目关联(任意卡片 → 任意卡片,有向、带描述):人物关系、场景归属等一律用它
class EntryLinks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get fromEntryId =>
      integer().references(Entries, #id, onDelete: KeyAction.cascade)();
  IntColumn get toEntryId =>
      integer().references(Entries, #id, onDelete: KeyAction.cascade)();

  /// 关联描述,如“师徒”“位于”“幼年在此学艺”
  TextColumn get label => text().withDefault(const Constant(''))();
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

  /// 写作对话历史(JSON)
  TextColumn get chatLog => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

enum EntryKind {
  character('人物', Icons.person_outline),
  location('地点', Icons.place_outlined),
  item('物品', Icons.category_outlined),
  scene('场景', Icons.pin_drop_outlined),
  lore('设定', Icons.public_outlined),
  foreshadow('伏笔', Icons.visibility_off_outlined);

  const EntryKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

@DriftDatabase(
    tables: [Novels, Entries, EntryLinks, Chapters, ChapterEvents])
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
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 3) {
            await customStatement(
                'ALTER TABLE entries ADD COLUMN parent_id INTEGER NULL');
          }
          if (from < 4) await m.createTable(entryLinks);
          if (from < 5) {
            await m.createTable(chapters);
            await m.createTable(chapterEvents);
          }
          // createTable 用当前表定义(已含新列),只有更老的库才需补列
          if (from < 6 && from >= 5) {
            await m.addColumn(chapterEvents, chapterEvents.chatLog);
          }
          if (from < 7 && from >= 4) {
            await m.addColumn(entryLinks, entryLinks.label);
          }
          if (from < 8) {
            // 人物关系与场景归属并入通用关联
            if (from >= 2) {
              await customStatement(
                  'INSERT INTO entry_links (from_entry_id, to_entry_id, label) '
                  'SELECT from_entry_id, to_entry_id, label FROM character_relations');
              await customStatement(
                  'DROP TABLE IF EXISTS character_relations');
            }
            await customStatement(
                'INSERT INTO entry_links (from_entry_id, to_entry_id, label) '
                "SELECT id, parent_id, '位于' FROM entries WHERE parent_id IS NOT NULL");
            await m.alterTable(TableMigration(entries));
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

  Future<Novel?> novelById(int id) =>
      (select(novels)..where((t) => t.id.equals(id))).getSingleOrNull();

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

  /// 本小说全部条目(供 AI 生成构建上下文)
  Future<List<Entry>> allEntriesOf(int novelId) =>
      (select(entries)..where((t) => t.novelId.equals(novelId))).get();

  // ---- 通用关联 ----
  Future<List<EntryLink>> linksFrom(int entryId) =>
      (select(entryLinks)..where((t) => t.fromEntryId.equals(entryId))).get();

  Future<List<EntryLink>> linksTo(int entryId) =>
      (select(entryLinks)..where((t) => t.toEntryId.equals(entryId))).get();

  Future<List<EntryLink>> linksOfNovel(int novelId) async {
    final q = select(entryLinks).join([
      innerJoin(entries, entries.id.equalsExp(entryLinks.fromEntryId))
    ])
      ..where(entries.novelId.equals(novelId));
    return [for (final r in await q.get()) r.readTable(entryLinks)];
  }

  /// 重写某条目发起的全部关联
  Future<void> replaceLinksFrom(
          int entryId, List<({int toId, String label})> links) =>
      transaction(() async {
        await (delete(entryLinks)
              ..where((t) => t.fromEntryId.equals(entryId)))
            .go();
        for (final l in links) {
          await into(entryLinks).insert(EntryLinksCompanion.insert(
              fromEntryId: entryId,
              toEntryId: l.toId,
              label: Value(l.label)));
        }
      });

  /// 新增一条关联;完全相同(from→to+label)的已存在则跳过(同对卡片可有多条不同描述)
  Future<void> upsertLink(int fromId, int toId, String label) async {
    final existing = await (select(entryLinks)
          ..where((t) =>
              t.fromEntryId.equals(fromId) &
              t.toEntryId.equals(toId) &
              t.label.equals(label)))
        .get();
    if (existing.isEmpty) {
      await into(entryLinks).insert(EntryLinksCompanion.insert(
          fromEntryId: fromId, toEntryId: toId, label: Value(label)));
    }
  }

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

  Future<void> updateEvent(int id,
          {String? outline, String? content, String? chatLog}) =>
      (update(chapterEvents)..where((t) => t.id.equals(id)))
          .write(ChapterEventsCompanion(
        outline: outline == null ? const Value.absent() : Value(outline),
        content: content == null ? const Value.absent() : Value(content),
        chatLog: chatLog == null ? const Value.absent() : Value(chatLog),
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

  /// 本小说全部人物(供选择器)
  Future<List<Entry>> charactersOf(int novelId) => (select(entries)
        ..where((t) =>
            t.novelId.equals(novelId) &
            t.kind.equals(EntryKind.character.name))
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .get();

  /// 导入一本小说(条目用数组索引引用关联),返回新小说 id
  Future<int> importNovel(
    String title,
    String description,
    List<({String kind, String name, String content, int? parent})> entryRows,
    List<({int from, int to, String label})> linkRows,
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
        // 旧格式的场景归属转为关联
        for (var i = 0; i < entryRows.length; i++) {
          final p = entryRows[i].parent;
          if (p != null && p >= 0 && p < ids.length && p != i) {
            await into(entryLinks).insert(EntryLinksCompanion.insert(
                fromEntryId: ids[i],
                toEntryId: ids[p],
                label: const Value('位于')));
          }
        }
        for (final l in linkRows) {
          if (l.from < 0 || l.from >= ids.length) continue;
          if (l.to < 0 || l.to >= ids.length) continue;
          await into(entryLinks).insert(EntryLinksCompanion.insert(
              fromEntryId: ids[l.from],
              toEntryId: ids[l.to],
              label: Value(l.label)));
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
