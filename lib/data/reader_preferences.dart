import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum TranslationMode { original, translated, bilingual }

enum ReadingTheme { day, sepia, night }

enum ReaderFontFamily { system, serif, sansSerif, monospace }

class ReaderPreferences {
  const ReaderPreferences({
    this.prefetchAhead = 3,
    this.translationLanguage = '简体中文',
    this.translationStyle = '',
    this.translationMode = TranslationMode.original,
    this.readingTheme = ReadingTheme.day,
    this.readerFontFamily = ReaderFontFamily.system,
    this.translationBatchChars = 4000,
    this.glossaryMaxSize = 80,
    this.discoveryTranslateOn = false,
  });
  final int prefetchAhead;
  final String translationLanguage;
  final String translationStyle;
  final TranslationMode translationMode;
  final ReadingTheme readingTheme;
  final ReaderFontFamily readerFontFamily;
  final int translationBatchChars;
  final int glossaryMaxSize;
  final bool discoveryTranslateOn;
  ReaderPreferences copyWith({
    int? prefetchAhead,
    String? translationLanguage,
    String? translationStyle,
    TranslationMode? translationMode,
    ReadingTheme? readingTheme,
    ReaderFontFamily? readerFontFamily,
    int? translationBatchChars,
    int? glossaryMaxSize,
    bool? discoveryTranslateOn,
  }) => ReaderPreferences(
    prefetchAhead: prefetchAhead ?? this.prefetchAhead,
    translationLanguage: translationLanguage ?? this.translationLanguage,
    translationStyle: translationStyle ?? this.translationStyle,
    translationMode: translationMode ?? this.translationMode,
    readingTheme: readingTheme ?? this.readingTheme,
    readerFontFamily: readerFontFamily ?? this.readerFontFamily,
    translationBatchChars: translationBatchChars ?? this.translationBatchChars,
    glossaryMaxSize: glossaryMaxSize ?? this.glossaryMaxSize,
    discoveryTranslateOn: discoveryTranslateOn ?? this.discoveryTranslateOn,
  );
  Map<String, dynamic> toJson() => {
    'prefetchAhead': prefetchAhead,
    'translationLanguage': translationLanguage,
    'translationStyle': translationStyle,
    'translationMode': translationMode.name,
    'readingTheme': readingTheme.name,
    'readerFontFamily': readerFontFamily.name,
    'translationBatchChars': translationBatchChars,
    'glossaryMaxSize': glossaryMaxSize,
    'discoveryTranslateOn': discoveryTranslateOn,
  };
  factory ReaderPreferences.fromJson(Map<String, dynamic> j) =>
      ReaderPreferences(
        prefetchAhead: ((j['prefetchAhead'] as num?)?.toInt() ?? 3).clamp(
          0,
          20,
        ),
        translationLanguage:
            j['translationLanguage']?.toString().trim().isNotEmpty == true
            ? j['translationLanguage'].toString()
            : '简体中文',
        translationStyle: j['translationStyle']?.toString() ?? '',
        translationMode: TranslationMode.values.firstWhere(
          (x) => x.name == j['translationMode'],
          orElse: () => TranslationMode.original,
        ),
        readingTheme: ReadingTheme.values.firstWhere(
          (x) => x.name == j['readingTheme'],
          orElse: () => ReadingTheme.day,
        ),
        readerFontFamily: ReaderFontFamily.values.firstWhere(
          (x) => x.name == j['readerFontFamily'],
          orElse: () => ReaderFontFamily.system,
        ),
        translationBatchChars:
            ((j['translationBatchChars'] as num?)?.toInt() ?? 4000).clamp(
              500,
              12000,
            ),
        glossaryMaxSize: ((j['glossaryMaxSize'] as num?)?.toInt() ?? 80).clamp(
          1,
          5000,
        ),
        discoveryTranslateOn: j['discoveryTranslateOn'] == true,
      );
}

class ReaderPreferencesStore {
  static const _key = 'reader_preferences';
  static Future<ReaderPreferences> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return const ReaderPreferences();
    try {
      return ReaderPreferences.fromJson(jsonDecode(raw));
    } catch (_) {
      return const ReaderPreferences();
    }
  }

  static Future<void> save(ReaderPreferences value) async =>
      (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode(value.toJson()),
      );
  static Future<String> loadPixivCookie() async =>
      (await SharedPreferences.getInstance()).getString(
        'reader_pixiv_phpsessid',
      ) ??
      '';
  static Future<void> savePixivCookie(String value) async =>
      (await SharedPreferences.getInstance()).setString(
        'reader_pixiv_phpsessid',
        value.trim(),
      );
}
