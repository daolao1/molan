import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart' show IconData, Icons;

part 'db.g.dart';

/// 小说
class Novels extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();

  /// 挂载到写作会话的文风设定卡 id(逗号分隔)
  TextColumn get styleEntryIds => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 小说下的设定条目(人物/地点/物品/场景/情节/设定等)
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get novelId =>
      integer().references(Novels, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()();
  TextColumn get name => text()();
  TextColumn get content => text().withDefault(const Constant(''))();

  /// 卡面图片(base64,空=无图)
  TextColumn get imageData => text().withDefault(const Constant(''))();
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

/// 设定集:若干设定卡的命名组合,可整组挂载到写作会话
class EntrySets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get novelId =>
      integer().references(Novels, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();

  /// 包含的设定卡 id(逗号分隔)
  TextColumn get entryIds => text().withDefault(const Constant(''))();
}

/// 章节:只有标题,内容由小节拼接
class Chapters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get novelId =>
      integer().references(Novels, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 章节内的小节:大纲驱动正文
class ChapterEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get chapterId =>
      integer().references(Chapters, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get outline => text().withDefault(const Constant(''))();
  TextColumn get content => text().withDefault(const Constant(''))();

  /// 写作对话历史(JSON)
  TextColumn get chatLog => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 小节内的有序情节;情节内容复用 Entries 中的 plot 卡
class SectionPlots extends Table {
  IntColumn get sectionId =>
      integer().references(ChapterEvents, #id, onDelete: KeyAction.cascade)();
  IntColumn get plotEntryId =>
      integer().references(Entries, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {sectionId, plotEntryId};

  @override
  List<Set<Column>> get uniqueKeys => [
    {plotEntryId},
  ];
}

/// Imported books used by the reader, kept separate from writing novels.
class ReaderBooks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get author => text().withDefault(const Constant(''))();
  TextColumn get sourceId => text().withDefault(const Constant('local'))();
  TextColumn get canonicalUrl => text().nullable()();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class ReaderChapters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId =>
      integer().references(ReaderBooks, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get title => text()();
  TextColumn get originalHtml => text().withDefault(const Constant(''))();
  TextColumn get translatedHtml => text().withDefault(const Constant(''))();
  TextColumn get translationState =>
      text().withDefault(const Constant('idle'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class ReaderProgress extends Table {
  IntColumn get bookId =>
      integer().references(ReaderBooks, #id, onDelete: KeyAction.cascade)();
  IntColumn get chapterId => integer().nullable().references(
    ReaderChapters,
    #id,
    onDelete: KeyAction.setNull,
  )();
  RealColumn get scrollFraction => real().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {bookId};
}

enum EntryKind {
  character('人物', Icons.person_outline),
  location('地点', Icons.place_outlined),
  item('物品', Icons.category_outlined),
  scene('场景', Icons.pin_drop_outlined),
  plot('情节', Icons.timeline_outlined),
  lore('设定', Icons.public_outlined),
  foreshadow('伏笔', Icons.visibility_off_outlined);

  const EntryKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

@DriftDatabase(
  tables: [
    Novels,
    Entries,
    EntryLinks,
    EntrySets,
    Chapters,
    ChapterEvents,
    SectionPlots,
    ReaderBooks,
    ReaderChapters,
    ReaderProgress,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'molan',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );

  @override
  int get schemaVersion => 14;

  /// 迁移中断重跑时列可能已存在,跳过避免 duplicate column 崩库
  Future<void> _addColumnIfAbsent(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    final rows = await customSelect(
      'PRAGMA table_info(${table.actualTableName})',
    ).get();
    if (rows.any((r) => r.data['name'] == column.name)) return;
    await m.addColumn(table, column);
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 3) {
        final cols = await customSelect('PRAGMA table_info(entries)').get();
        if (!cols.any((r) => r.data['name'] == 'parent_id')) {
          await customStatement(
            'ALTER TABLE entries ADD COLUMN parent_id INTEGER NULL',
          );
        }
      }
      if (from < 4) await m.createTable(entryLinks);
      if (from < 5) {
        await m.createTable(chapters);
        await m.createTable(chapterEvents);
      }
      // createTable 用当前表定义(已含新列),只有更老的库才需补列
      if (from < 6 && from >= 5) {
        await _addColumnIfAbsent(m, chapterEvents, chapterEvents.chatLog);
      }
      if (from < 7 && from >= 4) {
        await _addColumnIfAbsent(m, entryLinks, entryLinks.label);
      }
      if (from < 8) {
        // 人物关系与场景归属并入通用关联;重跑安全:表/列不存在则跳过
        final hasRelations = (await customSelect(
          "SELECT 1 FROM sqlite_master WHERE type='table' AND name='character_relations'",
        ).get()).isNotEmpty;
        if (hasRelations) {
          await customStatement(
            'INSERT INTO entry_links (from_entry_id, to_entry_id, label) '
            'SELECT from_entry_id, to_entry_id, label FROM character_relations',
          );
          await customStatement('DROP TABLE IF EXISTS character_relations');
        }
        final entryCols = await customSelect(
          'PRAGMA table_info(entries)',
        ).get();
        if (entryCols.any((r) => r.data['name'] == 'parent_id')) {
          await customStatement(
            'INSERT INTO entry_links (from_entry_id, to_entry_id, label) '
            "SELECT id, parent_id, '位于' FROM entries WHERE parent_id IS NOT NULL",
          );
          await m.alterTable(TableMigration(entries));
        }
      }
      if (from < 9) {
        await _addColumnIfAbsent(m, novels, novels.styleEntryIds);
      }
      if (from < 10) {
        await m.createTable(entrySets);
      }
      if (from < 11) {
        await _addColumnIfAbsent(m, entries, entries.imageData);
      }
      if (from < 12 && from >= 5) {
        await _addColumnIfAbsent(m, chapterEvents, chapterEvents.name);
      }
      if (from < 13) {
        await m.createTable(sectionPlots);
      }
      if (from < 14) {
        await m.createTable(readerBooks);
        await m.createTable(readerChapters);
        await m.createTable(readerProgress);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // ---- 小说 ----
  Stream<List<Novel>> watchNovels() => (select(
    novels,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  Future<Novel?> novelById(int id) =>
      (select(novels)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> createNovel(String title, String description) =>
      into(novels).insert(
        NovelsCompanion.insert(title: title, description: Value(description)),
      );

  Future<void> deleteNovel(int id) =>
      (delete(novels)..where((t) => t.id.equals(id))).go();

  Stream<List<ReaderBook>> watchReaderBooks() => (select(
    readerBooks,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();
  Future<int> createReaderBook({
    required String title,
    String author = '',
    String description = '',
  }) => into(readerBooks).insert(
    ReaderBooksCompanion.insert(
      title: title,
      author: Value(author),
      description: Value(description),
    ),
  );
  Future<ReaderBook?> readerBookById(int id) =>
      (select(readerBooks)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<List<ReaderChapter>> readerChaptersOf(int bookId) =>
      (select(readerChapters)
            ..where((t) => t.bookId.equals(bookId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .get();
  Future<int> createReaderChapter({
    required int bookId,
    required int position,
    required String title,
    required String originalHtml,
  }) => into(readerChapters).insert(
    ReaderChaptersCompanion.insert(
      bookId: bookId,
      position: position,
      title: title,
      originalHtml: Value(originalHtml),
    ),
  );
  Future<void> updateReaderTranslation(
    int id, {
    required String html,
    required String state,
  }) => (update(readerChapters)..where((t) => t.id.equals(id))).write(
    ReaderChaptersCompanion(
      translatedHtml: Value(html),
      translationState: Value(state),
      updatedAt: Value(DateTime.now()),
    ),
  );
  Future<ReaderProgressData?> readerProgressFor(int bookId) => (select(
    readerProgress,
  )..where((t) => t.bookId.equals(bookId))).getSingleOrNull();
  Future<void> saveReaderProgress({
    required int bookId,
    int? chapterId,
    required double fraction,
  }) => into(readerProgress).insertOnConflictUpdate(
    ReaderProgressCompanion.insert(
      bookId: Value(bookId),
      chapterId: Value(chapterId),
      scrollFraction: Value(fraction),
      updatedAt: Value(DateTime.now()),
    ),
  );
  Future<void> deleteReaderBook(int id) =>
      (delete(readerBooks)..where((t) => t.id.equals(id))).go();

  /// 更新挂载(逗号分隔令牌:纯数字=单卡 id,set:{id}=设定集)
  Future<void> updateNovelStyle(int id, String styleEntryIds) =>
      (update(novels)..where((t) => t.id.equals(id))).write(
        NovelsCompanion(
          styleEntryIds: Value(styleEntryIds),
          updatedAt: Value(DateTime.now()),
        ),
      );

  // ---- 设定集 ----
  Future<List<EntrySet>> setsOf(int novelId) =>
      (select(entrySets)
            ..where((t) => t.novelId.equals(novelId))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  Stream<List<EntrySet>> watchSets(int novelId) =>
      (select(entrySets)
            ..where((t) => t.novelId.equals(novelId))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .watch();

  Future<int> createSet(int novelId, String name, String entryIds) =>
      into(entrySets).insert(
        EntrySetsCompanion.insert(
          novelId: novelId,
          name: name,
          entryIds: Value(entryIds),
        ),
      );

  Future<void> updateSet(int id, String name, String entryIds) =>
      (update(entrySets)..where((t) => t.id.equals(id))).write(
        EntrySetsCompanion(name: Value(name), entryIds: Value(entryIds)),
      );

  Future<void> deleteSet(int id) =>
      (delete(entrySets)..where((t) => t.id.equals(id))).go();

  // ---- 条目 ----
  Stream<List<Entry>> watchEntries(int novelId, EntryKind kind) =>
      (select(entries)
            ..where((t) => t.novelId.equals(novelId) & t.kind.equals(kind.name))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  Future<int> createEntry(
    int novelId,
    EntryKind kind,
    String name,
    String content,
  ) => into(entries).insert(
    EntriesCompanion.insert(
      novelId: novelId,
      kind: kind.name,
      name: name,
      content: Value(content),
    ),
  );

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
      innerJoin(entries, entries.id.equalsExp(entryLinks.fromEntryId)),
    ])..where(entries.novelId.equals(novelId));
    return [for (final r in await q.get()) r.readTable(entryLinks)];
  }

  /// 重写某条目发起的全部关联
  Future<void> replaceLinksFrom(
    int entryId,
    List<({int toId, String label})> links,
  ) => transaction(() async {
    await (delete(
      entryLinks,
    )..where((t) => t.fromEntryId.equals(entryId))).go();
    for (final l in links) {
      await into(entryLinks).insert(
        EntryLinksCompanion.insert(
          fromEntryId: entryId,
          toEntryId: l.toId,
          label: Value(l.label),
        ),
      );
    }
  });

  /// 新增一条关联;完全相同(from→to+label)的已存在则跳过(同对卡片可有多条不同描述)
  Future<void> upsertLink(int fromId, int toId, String label) async {
    final existing =
        await (select(entryLinks)..where(
              (t) =>
                  t.fromEntryId.equals(fromId) &
                  t.toEntryId.equals(toId) &
                  t.label.equals(label),
            ))
            .get();
    if (existing.isEmpty) {
      await into(entryLinks).insert(
        EntryLinksCompanion.insert(
          fromEntryId: fromId,
          toEntryId: toId,
          label: Value(label),
        ),
      );
    }
  }

  // ---- 章节与小节 ----
  Stream<List<Chapter>> watchChapters(int novelId) =>
      (select(chapters)
            ..where((t) => t.novelId.equals(novelId))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .watch();

  Future<int> createChapter(int novelId, String title) => into(
    chapters,
  ).insert(ChaptersCompanion.insert(novelId: novelId, title: title));

  Future<void> renameChapter(int id, String title) =>
      (update(chapters)..where((t) => t.id.equals(id))).write(
        ChaptersCompanion(
          title: Value(title),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> deleteChapter(int id) =>
      (delete(chapters)..where((t) => t.id.equals(id))).go();

  Stream<List<ChapterEvent>> watchEvents(int chapterId) =>
      (select(chapterEvents)
            ..where((t) => t.chapterId.equals(chapterId))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .watch();

  Future<List<ChapterEvent>> eventsOf(int chapterId) =>
      (select(chapterEvents)
            ..where((t) => t.chapterId.equals(chapterId))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  Future<int> createEvent(int chapterId, String name, String outline) =>
      into(chapterEvents).insert(
        ChapterEventsCompanion.insert(
          chapterId: chapterId,
          name: Value(name),
          outline: Value(outline),
        ),
      );

  Future<void> updateEvent(
    int id, {
    String? name,
    String? outline,
    String? content,
    String? chatLog,
  }) => (update(chapterEvents)..where((t) => t.id.equals(id))).write(
    ChapterEventsCompanion(
      name: name == null ? const Value.absent() : Value(name),
      outline: outline == null ? const Value.absent() : Value(outline),
      content: content == null ? const Value.absent() : Value(content),
      chatLog: chatLog == null ? const Value.absent() : Value(chatLog),
      updatedAt: Value(DateTime.now()),
    ),
  );

  Future<void> deleteEvent(int id) =>
      (delete(chapterEvents)..where((t) => t.id.equals(id))).go();

  Future<List<Entry>> plotsOfEvent(int sectionId) async {
    final q =
        select(sectionPlots).join([
            innerJoin(entries, entries.id.equalsExp(sectionPlots.plotEntryId)),
          ])
          ..where(sectionPlots.sectionId.equals(sectionId))
          ..orderBy([OrderingTerm.asc(sectionPlots.position)]);
    return [for (final row in await q.get()) row.readTable(entries)];
  }

  /// 尚未编排进任何小节的情节,供旧数据重新归档
  Future<List<Entry>> unassignedPlotsOfNovel(int novelId) async {
    final assigned = selectOnly(sectionPlots)
      ..addColumns([sectionPlots.plotEntryId]);
    return (select(entries)
          ..where(
            (t) =>
                t.novelId.equals(novelId) &
                t.kind.equals(EntryKind.plot.name) &
                t.id.isNotInQuery(assigned),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
  }

  /// 保存小节的完整情节编排;移除的专属情节同时删除
  Future<void> replaceEventPlots(
    int sectionId,
    int novelId,
    List<({int? id, String name, String description})> plots,
  ) async {
    await transaction(() async {
      final old = await plotsOfEvent(sectionId);
      final kept = <int>{};
      await (delete(
        sectionPlots,
      )..where((t) => t.sectionId.equals(sectionId))).go();
      for (final (position, plot) in plots.indexed) {
        final content = jsonEncode({'description': plot.description});
        final plotId = plot.id == null
            ? await createEntry(novelId, EntryKind.plot, plot.name, content)
            : plot.id!;
        if (plot.id != null) await updateEntry(plotId, plot.name, content);
        kept.add(plotId);
        await into(sectionPlots).insert(
          SectionPlotsCompanion.insert(
            sectionId: sectionId,
            plotEntryId: plotId,
            position: position,
          ),
        );
      }
      for (final entry in old) {
        if (!kept.contains(entry.id)) await deleteEntry(entry.id);
      }
    });
  }

  Future<void> updateEntry(int id, String name, String content) =>
      (update(entries)..where((t) => t.id.equals(id))).write(
        EntriesCompanion(
          name: Value(name),
          content: Value(content),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> updateEntryImage(int id, String imageData) =>
      (update(entries)..where((t) => t.id.equals(id))).write(
        EntriesCompanion(
          imageData: Value(imageData),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> deleteEntry(int id) =>
      (delete(entries)..where((t) => t.id.equals(id))).go();

  /// 本小说全部人物(供选择器)
  Future<List<Entry>> charactersOf(int novelId) =>
      (select(entries)
            ..where(
              (t) =>
                  t.novelId.equals(novelId) &
                  t.kind.equals(EntryKind.character.name),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  /// 导入一本小说(条目用数组索引引用关联),返回新小说 id
  Future<int> importNovel(
    String title,
    String description,
    List<({String kind, String name, String content, int? parent})> entryRows,
    List<({int from, int to, String label})> linkRows,
    List<
      ({
        String title,
        List<({String name, String outline, String content, List<int> plots})>
        events,
      })
    >
    chapterRows,
  ) => transaction(() async {
    final novelId = await createNovel(title, description);
    final ids = <int>[];
    for (final e in entryRows) {
      ids.add(
        await into(entries).insert(
          EntriesCompanion.insert(
            novelId: novelId,
            kind: e.kind,
            name: e.name,
            content: Value(e.content),
          ),
        ),
      );
    }
    // 旧格式的场景归属转为关联
    for (var i = 0; i < entryRows.length; i++) {
      final p = entryRows[i].parent;
      if (p != null && p >= 0 && p < ids.length && p != i) {
        await into(entryLinks).insert(
          EntryLinksCompanion.insert(
            fromEntryId: ids[i],
            toEntryId: ids[p],
            label: const Value('位于'),
          ),
        );
      }
    }
    for (final l in linkRows) {
      if (l.from < 0 || l.from >= ids.length) continue;
      if (l.to < 0 || l.to >= ids.length) continue;
      await into(entryLinks).insert(
        EntryLinksCompanion.insert(
          fromEntryId: ids[l.from],
          toEntryId: ids[l.to],
          label: Value(l.label),
        ),
      );
    }
    for (final c in chapterRows) {
      final chapterId = await createChapter(novelId, c.title);
      for (final e in c.events) {
        final eventId = await createEvent(chapterId, e.name, e.outline);
        if (e.content.isNotEmpty) {
          await updateEvent(eventId, content: e.content);
        }
        for (final (position, plotIndex) in e.plots.indexed) {
          if (plotIndex < 0 || plotIndex >= ids.length) continue;
          if (entryRows[plotIndex].kind != EntryKind.plot.name) continue;
          await into(sectionPlots).insert(
            SectionPlotsCompanion.insert(
              sectionId: eventId,
              plotEntryId: ids[plotIndex],
              position: position,
            ),
          );
        }
      }
    }
    return novelId;
  });
}
