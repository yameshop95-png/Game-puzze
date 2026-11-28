import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Các khóa bắt buộc ở cấp trên cùng của một bản ghi manifest,
/// theo schema gốc `content_pipeline/manifest.schema.json`
/// (contract S1-01 §5.3).
const List<String> _requiredKeys = [
  'image_id',
  'theme',
  'level',
  'title',
  'creator',
  'creation_year',
  'source',
  'rights',
  'image',
  'text',
  'reviewed_by',
  'reviewed_on',
];

/// Một hình đã nạp từ manifest. Bất biến (contract S1-01, SA-4).
class PuzzleAsset {
  final String id;
  final String theme;
  final int level;
  final String title;
  final String textEn;

  /// Câu ghép chữ đã biên tập (`text.en_word`, contract
  /// S2-01 SA-WP-2): null khi bản ghi không có field —
  /// asset đó không hỗ trợ word mode.
  final String? textEnWord;

  /// Các đáp án thay thế đầy đủ (`text.en_alt`, contract
  /// S2-01 SA-WP-3): danh sách không sửa được, rỗng khi
  /// bản ghi không có field. Luật cùng multiset khóa do
  /// AnswerValidator (engine E4) giữ, không kiểm ở đây.
  final List<String> textEnAlt;
  final String playPath;
  final String thumbPath;
  final String creator;
  final String institution;

  const PuzzleAsset({
    required this.id,
    required this.theme,
    required this.level,
    required this.title,
    required this.textEn,
    this.textEnWord,
    this.textEnAlt = const [],
    required this.playPath,
    required this.thumbPath,
    required this.creator,
    required this.institution,
  });
}

/// Đọc `content/manifest.json`, kiểm cấu trúc theo contract
/// S1-01 (SA-3) và trả danh sách [PuzzleAsset] theo đúng thứ
/// tự mảng. Luật bản quyền của validator Python không lặp lại
/// ở đây; lỗi cấu trúc đầu tiên gặp phải ném [FormatException]
/// toàn cục.
class AssetLoader {
  /// Đường dẫn manifest mặc định (tương đối so với asset root
  /// của app, khớp cây §1: content/manifest.json).
  static const String manifestPath = 'content/manifest.json';

  final Future<String> Function(String) _loadString;

  /// [loadString] tùy chọn: hàm đọc chuỗi theo đường dẫn, mặc
  /// định là `rootBundle.loadString`. Test tiêm hàm giả.
  AssetLoader({Future<String> Function(String)? loadString})
    : _loadString = loadString ?? rootBundle.loadString;

  /// Đọc manifest tại [manifestPath], kiểm cấu trúc, trả danh
  /// sách theo đúng thứ tự mảng. Ném [FormatException] ở bản
  /// ghi hỏng đầu tiên.
  Future<List<PuzzleAsset>> load() async {
    final body = await _loadString(manifestPath);
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      throw const FormatException('manifest top level must be a JSON array');
    }
    return [for (final record in decoded) _parseRecord(record)];
  }

  PuzzleAsset _parseRecord(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('manifest record must be a JSON object');
    }
    for (final key in _requiredKeys) {
      if (!raw.containsKey(key)) {
        throw FormatException('manifest record is missing "$key"');
      }
    }
    final id = _stringField(raw, 'image_id');
    final theme = _stringField(raw, 'theme');
    final title = _stringField(raw, 'title');
    _stringField(raw, 'reviewed_by');
    _stringField(raw, 'reviewed_on');
    final level = _intField(raw, 'level');
    _intField(raw, 'creation_year');
    final creator = _objectField(raw, 'creator');
    final source = _objectField(raw, 'source');
    _objectField(raw, 'rights');
    _objectField(raw, 'image');
    final text = _objectField(raw, 'text');

    if (id.isEmpty) {
      throw const FormatException(
        'manifest field "image_id" must not be empty',
      );
    }
    if (theme.isEmpty) {
      throw const FormatException('manifest field "theme" must not be empty');
    }
    if (title.isEmpty) {
      throw const FormatException('manifest field "title" must not be empty');
    }
    final textEn = _stringField(text, 'en');
    if (textEn.isEmpty) {
      throw const FormatException('manifest field "text.en" must not be empty');
    }
    // SA-WP-2: text.en_word tùy chọn — có mặt thì phải là
    // chuỗi không rỗng; vắng thì textEnWord là null.
    String? textEnWord;
    if (text.containsKey('en_word')) {
      final value = _stringField(text, 'en_word');
      if (value.isEmpty) {
        throw const FormatException(
          'manifest field "text.en_word" must not be empty',
        );
      }
      textEnWord = value;
    }
    // SA-WP-3: text.en_alt tùy chọn — có mặt thì phải là
    // mảng chuỗi không rỗng phần tử; vắng thì rỗng.
    var textEnAlt = const <String>[];
    if (text.containsKey('en_alt')) {
      final rawAlt = text['en_alt'];
      if (rawAlt is! List) {
        throw const FormatException(
          'manifest field "text.en_alt" must be an array',
        );
      }
      final parsed = <String>[];
      for (final element in rawAlt) {
        if (element is! String || element.isEmpty) {
          throw const FormatException(
            'manifest field "text.en_alt" must contain only non-empty strings',
          );
        }
        parsed.add(element);
      }
      textEnAlt = List<String>.unmodifiable(parsed);
    }
    final creatorName = _stringField(creator, 'name');
    final institution = _stringField(source, 'institution');

    return PuzzleAsset(
      id: id,
      theme: theme,
      level: level,
      title: title,
      textEn: textEn,
      textEnWord: textEnWord,
      textEnAlt: textEnAlt,
      playPath: 'packs/$theme/$level/$id/play.webp',
      thumbPath: 'packs/$theme/$level/$id/thumb.webp',
      creator: creatorName,
      institution: institution,
    );
  }

  String _stringField(Map<String, dynamic> record, String key) {
    final value = record[key];
    if (value is! String) {
      throw FormatException('manifest field "$key" must be a string');
    }
    return value;
  }

  int _intField(Map<String, dynamic> record, String key) {
    final value = record[key];
    if (value is! int) {
      throw FormatException('manifest field "$key" must be an integer');
    }
    return value;
  }

  Map<String, dynamic> _objectField(Map<String, dynamic> record, String key) {
    final value = record[key];
    if (value is! Map<String, dynamic>) {
      throw FormatException('manifest field "$key" must be an object');
    }
    return value;
  }
}
