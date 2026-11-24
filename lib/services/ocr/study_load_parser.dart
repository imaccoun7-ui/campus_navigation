import '../../data/models/scheduled_class.dart';

/// One class found in the recognised study-load text.
///
/// The parser never guesses silently: anything it could not read confidently is
/// listed in [issues] so the Review screen can ask the student to fix it.
class ParsedClass {
  const ParsedClass({
    required this.subject,
    required this.roomText,
    required this.days,
    this.startMinutes,
    this.endMinutes,
    this.issues = const <String>[],
  });

  final String subject;
  final String roomText;
  final List<ClassDay> days;
  final int? startMinutes;
  final int? endMinutes;
  final List<String> issues;

  bool get needsReview =>
      issues.isNotEmpty ||
      days.isEmpty ||
      startMinutes == null ||
      endMinutes == null ||
      roomText.trim().isEmpty;

  String get primaryIssue {
    if (issues.isNotEmpty) {
      return issues.first;
    }
    if (days.isEmpty) {
      return 'Day not recognised';
    }
    if (roomText.trim().isEmpty) {
      return 'Room not recognised';
    }
    return 'Check details';
  }
}

/// Pure-Dart study-load parser.
///
/// Input is the raw text from ML Kit or a PDF's embedded text; the output is a
/// list of candidate classes. It has no Flutter or platform dependencies, so it
/// is unit-testable with any sample text.
///
/// The parser only keeps three columns from a study load: the **Subject
/// Description**, the **Schedule** (days and time) and the **Room**. Class IDs,
/// subject codes, units, instructors and sections are used as anchors to find
/// those columns and are never reported as data.
///
/// Two layouts are supported:
///
/// * **Row layout** — one table row per line. Scanned images provide the
///   Class ID, Subject Description, Schedule and Room columns; embedded text
///   may contain every table column in reading order. Schedule and room data
///   are read from their own cells when available.
/// * **Stacked layout** — one table cell per line (`CS 219-RS4`,
///   `Information Management`, `3.0`, `3-4 pm MTh`, `TECH302`). This is what a
///   PDF text layer often produces.
class StudyLoadParser {
  const StudyLoadParser();

  /// Enrolment class IDs such as `C161`, `C21`, `C17`.
  static final RegExp _classIdOnly = RegExp(r'^[A-Z]{1,3}[- ]?\d{1,4}$');

  /// The class ID that opens a table row.
  static final RegExp _classIdPrefix = RegExp(
    r'^\s*([A-Z]{1,3}[- ]?\d{1,4})\b',
  );

  /// Units such as `3.0` or `3`.
  static final RegExp _unitsOnly = RegExp(r'^\d{1,2}(?:\.\d{1,2})?$');
  static final RegExp _unitsInText = RegExp(r'\b\d{1,2}\.\d{1,2}\b');

  /// `Room 204`, `RM 204`, `LAB 3` style rooms.
  static final RegExp _roomPrefixed = RegExp(
    r'^(?:room|rm\.?|lab)\s*[:#-]?\s*[A-Z]{0,12}[- ]?\d{2,4}[A-Z]?$',
    caseSensitive: false,
  );
  static final RegExp _roomPrefixedInText = RegExp(
    r'\b(?:room|rm\.?|lab)\s*[:#-]?\s*[A-Z]{0,12}[- ]?\d{2,4}[A-Z]?\b',
    caseSensitive: false,
  );

  /// Bare room codes: `TECH302`, `NURSING302`, `T-302`, `BIH101`, `C102`.
  ///
  /// Department prefixes can be long (`NURSING`, `MARITIME`, `TEACHERED`), so
  /// the letter run is not limited to the map's short room-code prefixes.
  static final RegExp _roomCode = RegExp(r'^[A-Z]{1,12}[- ]?\d{2,4}[A-Z]?$');

  /// Sections such as `BSCS 3C` — never a room and never a subject.
  static final RegExp _section = RegExp(
    r'^[A-Z]{2,6}\s*-?\s*\d{1,2}[A-Z]?$',
  );

  /// Instructor cells such as `Dr. R. Santianez`.
  static final RegExp _instructor = RegExp(
    r'^(?:mr|mrs|ms|dr|prof|engr|atty|sir|maam|ma)\.?\s',
    caseSensitive: false,
  );

  /// A token that is entirely upper-case (`CS`, `219-RS4`, `1-RS4`).
  static final RegExp _uppercaseToken = RegExp(r'^[A-Z0-9][A-Z0-9&./,-]*$');

  /// `9:00 - 10:30 AM`, `13:00-14:30`, `3-4 pm`, `10 am-12 pm`.
  static final RegExp _timeRangePattern = RegExp(
    r'(\d{1,2})(?:\s*[:.]\s*(\d{2}))?\s*([AP]\.?M\.?)?\s*(?:-|–|—|to|until)\s*(\d{1,2})(?:\s*[:.]\s*(\d{2}))?\s*([AP]\.?M\.?)?',
    caseSensitive: false,
  );

  /// A lone clock time such as `9:00 AM` (used only when no range is found).
  static final RegExp _singleTimePattern = RegExp(
    r'(\d{1,2})\s*[:.]\s*(\d{2})\s*([AP]\.?M\.?)?',
    caseSensitive: false,
  );

  List<ParsedClass> parse(String rawText) {
    final rows = _rows(rawText);
    if (rows.isEmpty) {
      return const <ParsedClass>[];
    }

    final hasClassIdRows = rows.any(_hasClassIdRow);
    final hasTableColumns = rows.any((row) => row.cells.length > 1);
    final hasStructuredRows = hasClassIdRows || hasTableColumns;
    final hasScheduleOnlyRows = rows.any((row) {
      final hits = _timeHits(row.text);
      return hits.isNotEmpty &&
          row.text.substring(0, hits.first.start).trim().isEmpty;
    });
    if (!hasClassIdRows &&
        !hasTableColumns &&
        !hasScheduleOnlyRows &&
        rows.length >= 2) {
      final scheduleRowIndex = rows.indexWhere(
        (row) => _timeHits(row.text).isNotEmpty,
      );
      if (scheduleRowIndex >= 0) {
        final scheduleHits = _timeHits(rows[scheduleRowIndex].text);
        final following = scheduleRowIndex + 1 < rows.length
            ? rows[scheduleRowIndex + 1].text
            : '';
        if (following.isNotEmpty &&
            (_isRoomCell(following) ||
                RegExp(
                  r'^[A-Z]{1,12}[- ]?\d{2,4}[A-Z]?$',
                  caseSensitive: false,
                ).hasMatch(following.trim()))) {
          final days = _daysForMeeting(
            rows[scheduleRowIndex].text,
            scheduleHits,
          );
          final result = <ParsedClass>[];
          for (final hit in scheduleHits) {
            if (days.isEmpty) {
              result.add(
                ParsedClass(
                  subject: scheduleRowIndex > 0
                      ? rows[scheduleRowIndex - 1].text
                      : 'Class',
                  roomText: _cleanRoom(following),
                  days: const <ClassDay>[],
                  startMinutes: hit.span.start,
                  endMinutes: hit.span.end,
                  issues: const <String>['Day not recognised'],
                ),
              );
            } else {
              for (final day in days) {
                result.add(
                  ParsedClass(
                    subject: scheduleRowIndex > 0
                        ? rows[scheduleRowIndex - 1].text
                        : 'Class',
                    roomText: _cleanRoom(following),
                    days: <ClassDay>[day],
                    startMinutes: hit.span.start,
                    endMinutes: hit.span.end,
                    issues: hit.span.issues,
                  ),
                );
              }
            }
          }
          return _finish(result);
        }
      }
    }

    final compact = hasClassIdRows || hasTableColumns || hasScheduleOnlyRows
        ? const <ParsedClass>[]
        : _parseCompactRows(rows);
    if (compact.isNotEmpty) {
      return _finish(compact);
    }

    final plainLayout =
        rows.every((row) => row.cells.length == 1) &&
        rows.any((row) => _timeHits(row.text).isNotEmpty) &&
        rows.any((row) => !_timeHits(row.text).isNotEmpty);
    final hasSubjectCodes = rows.any(_rowHasSubjectCode);
    if (!hasStructuredRows && plainLayout && !hasSubjectCodes) {
      final stacked = _parseStackedRows(rows);
      if (stacked.isNotEmpty) {
        return _finish(stacked);
      }
    }
    if (!hasStructuredRows && plainLayout) {
      final explicit = _parseExplicitSimpleRows(rows);
      if (explicit.isNotEmpty) {
        return _finish(explicit);
      }
    }

    if (!hasStructuredRows && plainLayout) {
      final simple = _parseSimpleLayout(rows);
      if (simple.isNotEmpty) {
        return _finish(simple);
      }
    }

    if (!hasStructuredRows && !hasSubjectCodes) {
      final simple = _parseSimpleLayout(rows);
      if (simple.isNotEmpty) {
        return _finish(simple);
      }
    }
    final blocks = _blocks(rows, hasSubjectCodes);

    final results = <ParsedClass>[];
    for (final block in blocks) {
      final rowLayout = _isRowLayout(block);
      final subject = rowLayout
          ? _subjectFromRowLayout(block)
          : _subjectFromStacked(block);
      if (subject.isEmpty && !rowLayout) {
        continue;
      }

      final meetings = rowLayout
          ? _meetingsFromRowLayout(block)
          : _meetingsFromStacked(block);
      for (final meeting in meetings) {
        final days = meeting.days.isEmpty
            ? const <ClassDay?>[null]
            : meeting.days.map<ClassDay?>((day) => day).toList();
        final spans = meeting.spans.isEmpty
            ? const <_TimeSpan?>[null]
            : meeting.spans.map<_TimeSpan?>((span) => span).toList();
        for (final day in days) {
          for (final span in spans) {
            results.add(
              ParsedClass(
                subject: subject.isEmpty ? 'Class' : subject,
                roomText: meeting.room,
                days: day == null ? const <ClassDay>[] : <ClassDay>[day],
                startMinutes: span?.start,
                endMinutes: span?.end,
                issues: <String>[
                  ...meeting.issues,
                  if (span != null) ...span.issues,
                ],
              ),
            );
          }
        }
      }
    }
    return _finish(results);
  }

  // ---------------------------------------------------------------------------
  // Rows and blocks
  // ---------------------------------------------------------------------------

  List<ParsedClass> _parseCompactRows(List<_Row> rows) {
    final results = <ParsedClass>[];
    for (var i = 0; i < rows.length; i++) {
      final text = rows[i].text;
      final hits = _timeHits(text);
      if (hits.isEmpty) {
        continue;
      }

      var subject = text.substring(0, hits.first.start).trim();
      subject = subject
          .replaceAll(
            RegExp(
              r'\b(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tue|Wed|Thu|Fri|Sat|Sun|MWF|MTh|TTh|TF)\b',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (subject.isEmpty && i > 0) {
        subject = rows[i - 1].text;
      }

      var room = _roomAfterSchedule(text, hits);
      if (room.isEmpty) {
        final tail = text.substring(hits.last.end);
        final roomMatch = RegExp(
          r'(?:Room\s*)?[A-Z]{1,12}[- ]?\d{2,4}[A-Z]?',
          caseSensitive: false,
        ).firstMatch(tail);
        if (roomMatch != null) {
          room = _cleanRoom(roomMatch.group(0)!);
        }
      }
      if (room.isEmpty &&
          i + 1 < rows.length &&
          _isRoomCell(rows[i + 1].text)) {
        room = _cleanRoom(rows[i + 1].text);
      }

      final days = _daysForMeeting(text, hits);
      for (final hit in hits) {
        if (days.isEmpty) {
          results.add(
            ParsedClass(
              subject: subject.isEmpty ? 'Class' : subject,
              roomText: room,
              days: const <ClassDay>[],
              startMinutes: hit.span.start,
              endMinutes: hit.span.end,
              issues: <String>[
                'Day not recognised',
                if (room.isEmpty) 'Room not recognised',
                ...hit.span.issues,
              ],
            ),
          );
        } else {
          for (final day in days) {
            results.add(
              ParsedClass(
                subject: subject.isEmpty ? 'Class' : subject,
                roomText: room,
                days: <ClassDay>[day],
                startMinutes: hit.span.start,
                endMinutes: hit.span.end,
                issues: <String>[
                  if (room.isEmpty) 'Room not recognised',
                  ...hit.span.issues,
                ],
              ),
            );
          }
        }
      }
    }
    return results;
  }

  List<ParsedClass> _parseStackedRows(List<_Row> rows) {
    final results = <ParsedClass>[];
    var previousSubject = '';
    var previousRoom = '';
    for (var i = 0; i < rows.length; i++) {
      final hits = _timeHits(rows[i].text);
      if (hits.isEmpty) {
        continue;
      }

      var subject = i > 0 ? rows[i - 1].text : '';
      final beforeTime = rows[i].text.substring(0, hits.first.start).trim();
      final inlineSubject = beforeTime
          .replaceAll(
            RegExp(
              r'\b(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tue|Wed|Thu|Fri|Sat|Sun|MWF|MTh|TTh|TF)\b',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (inlineSubject.isNotEmpty && RegExp(r'\d').hasMatch(inlineSubject)) {
        subject = inlineSubject;
      }
      if (i >= 2 && rows[i - 2].text.contains(RegExp(r'[A-Za-z]'))) {
        final candidate = rows[i - 2].text;
        if (!_looksLikeCode(candidate) &&
            !_isRoomCell(candidate) &&
            !_timeHits(candidate).isNotEmpty) {
          subject = '$candidate $subject'.trim();
        }
      }
      if (subject.isEmpty ||
          _isRoomCell(subject) ||
          _timeHits(subject).isNotEmpty) {
        subject = previousSubject;
      } else {
        previousSubject = subject;
      }

      var room = '';
      if (i + 1 < rows.length && _isRoomCell(rows[i + 1].text)) {
        room = _cleanRoom(rows[i + 1].text);
      }
      if (room.isEmpty) {
        room = _roomAfterSchedule(rows[i].text, hits);
      }
      if (room.isEmpty) {
        room = previousRoom;
      } else {
        previousRoom = room;
      }
      if (room.isEmpty) {
        final tail = rows[i].text.substring(hits.last.end);
        final prefixed = _roomPrefixedInText.firstMatch(tail);
        if (prefixed != null) {
          room = _cleanRoom(prefixed.group(0)!);
        }
      }

      final days = _daysForMeeting(rows[i].text, hits);
      for (final hit in hits) {
        if (days.isEmpty) {
          results.add(
            ParsedClass(
              subject: subject,
              roomText: room,
              days: const <ClassDay>[],
              startMinutes: hit.span.start,
              endMinutes: hit.span.end,
              issues: <String>[
                'Day not recognised',
                if (room.isEmpty) 'Room not recognised',
                ...hit.span.issues,
              ],
            ),
          );
        } else {
          for (final day in days) {
            results.add(
              ParsedClass(
                subject: subject,
                roomText: room,
                days: <ClassDay>[day],
                startMinutes: hit.span.start,
                endMinutes: hit.span.end,
                issues: <String>[
                  if (room.isEmpty) 'Room not recognised',
                  ...hit.span.issues,
                ],
              ),
            );
          }
        }
      }
    }
    return results;
  }

  List<ParsedClass> _parseExplicitSimpleRows(List<_Row> rows) {
    final results = <ParsedClass>[];
    for (var i = 0; i < rows.length; i++) {
      final text = rows[i].text;
      final hits = _timeHits(text);
      if (hits.isEmpty) {
        continue;
      }

      final beforeTime = text.substring(0, hits.first.start).trim();
      var subject = beforeTime
          .replaceAll(
            RegExp(
              r'\b(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tue|Wed|Thu|Fri|Sat|Sun|MWF|MTh|TTh|TF)\b',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (subject.isEmpty && i > 0) {
        subject = rows[i - 1].text;
      }

      var room = _roomAfterSchedule(text, hits);
      if (room.isEmpty) {
        final tail = text.substring(hits.last.end);
        final prefixed = _roomPrefixedInText.firstMatch(tail);
        if (prefixed != null) {
          room = _cleanRoom(prefixed.group(0)!);
        }
      }
      if (room.isEmpty && i + 1 < rows.length) {
        final next = rows[i + 1].text;
        if (_isRoomCell(next)) {
          room = _cleanRoom(next);
        }
      }

      final days = _daysForMeeting(text, hits);
      for (final hit in hits) {
        if (days.isEmpty) {
          results.add(
            ParsedClass(
              subject: subject.isEmpty ? 'Class' : subject,
              roomText: room,
              days: const <ClassDay>[],
              startMinutes: hit.span.start,
              endMinutes: hit.span.end,
              issues: <String>[
                'Day not recognised',
                if (room.isEmpty) 'Room not recognised',
                ...hit.span.issues,
              ],
            ),
          );
        } else {
          for (final day in days) {
            results.add(
              ParsedClass(
                subject: subject.isEmpty ? 'Class' : subject,
                roomText: room,
                days: <ClassDay>[day],
                startMinutes: hit.span.start,
                endMinutes: hit.span.end,
                issues: <String>[
                  if (room.isEmpty) 'Room not recognised',
                  ...hit.span.issues,
                ],
              ),
            );
          }
        }
      }
    }
    return results;
  }

  List<ParsedClass> _parseSimpleLayout(List<_Row> rows) {
    final results = <ParsedClass>[];

    for (var i = 0; i < rows.length; i++) {
      final text = rows[i].text;
      final hits = _timeHits(text);
      if (hits.isNotEmpty) {
        String room = _roomAfterSchedule(text, hits);
        final beforeTime = text.substring(0, hits.first.start).trim();
        final inlineSubject = beforeTime
            .replaceAll(
              RegExp(
                r'\b(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tue|Wed|Thu|Fri|Sat|Sun|MWF|MTh|TTh|TF)\b',
                caseSensitive: false,
              ),
              '',
            )
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final looksInline =
            inlineSubject.isNotEmpty &&
            (RegExp(r'\d').hasMatch(inlineSubject) ||
                inlineSubject.toLowerCase().contains('subject'));
        var subject = looksInline
            ? inlineSubject
            : (i > 0 ? rows[i - 1].text : '');

        if (room.isEmpty) {
          final prefixed = _roomPrefixedInText.firstMatch(
            text.substring(hits.last.end),
          );
          if (prefixed != null) {
            room = _cleanRoom(prefixed.group(0)!);
          }
        }
        if (room.isEmpty) {
          final tail = text.substring(hits.last.end).trim();
          final tailTokens = tail.split(RegExp(r'\s+'));
          for (var j = 0; j < tailTokens.length; j++) {
            final candidate = _trimEdgePunctuation(tailTokens[j]);
            if (_isRoomCell(candidate)) {
              room = _cleanRoom(candidate);
              break;
            }
            if (j + 1 < tailTokens.length &&
                _isRoomPrefixedJoin(tailTokens[j], tailTokens[j + 1])) {
              room = _cleanRoom('${tailTokens[j]} ${tailTokens[j + 1]}');
              break;
            }
          }
        }
        if (room.isEmpty && i + 1 < rows.length) {
          final next = rows[i + 1].text;
          if (_isRoomCell(next)) {
            room = _cleanRoom(next);
          }
        }
        for (final hit in hits) {
          final days = _daysForMeeting(text, hits);
          if (days.isEmpty) {
            results.add(
              ParsedClass(
                subject: subject.isEmpty ? 'Class' : subject,
                roomText: room,
                days: const <ClassDay>[],
                startMinutes: hit.span.start,
                endMinutes: hit.span.end,
                issues: <String>[
                  'Day not recognised',
                  if (room.isEmpty) 'Room not recognised',
                  ...hit.span.issues,
                ],
              ),
            );
          } else {
            for (final day in days) {
              results.add(
                ParsedClass(
                  subject: subject.isEmpty ? 'Class' : subject,
                  roomText: room,
                  days: <ClassDay>[day],
                  startMinutes: hit.span.start,
                  endMinutes: hit.span.end,
                  issues: <String>[
                    if (room.isEmpty) 'Room not recognised',
                    ...hit.span.issues,
                  ],
                ),
              );
            }
          }
        }
      } else if (_isRoomCell(text) && i > 0) {
        continue;
      } else if (text.isNotEmpty &&
          i + 1 < rows.length &&
          _timeHits(rows[i + 1].text).isNotEmpty &&
          !_isRoomCell(text)) {
        continue;
      }
    }
    return results;
  }

  List<_Row> _rows(String rawText) {
    final rows = <_Row>[];
    for (final rawLine in rawText.split(RegExp(r'[\r\n]+'))) {
      final cells = rawLine.split('\t').map(_clean).toList(growable: false);
      final nonEmptyCells = cells.where((cell) => cell.isNotEmpty).toList();
      if (nonEmptyCells.isEmpty || _isHeaderRow(nonEmptyCells)) {
        continue;
      }
      rows.add(_Row(cells));
    }
    return rows;
  }

  bool _hasClassIdRow(_Row row) {
    if (row.cells.length == 1 && _isRoomCell(row.text)) {
      return false;
    }
    final match = _classIdPrefix.firstMatch(row.text);
    if (match == null) {
      return false;
    }
    final prefix = match.group(1)!;
    final letters = prefix.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (_daysFromToken(letters) != null) {
      return false;
    }
    final tail = row.text.substring(match.end).trimLeft();
    if (tail.startsWith(':') || tail.startsWith('-')) {
      return false;
    }
    if (tail.isEmpty) {
      return letters.length == 1 && RegExp(r'\d').hasMatch(prefix);
    }
    final tokens = tail.split(RegExp(r'\s+'));
    final tokenCount = tokens.length < 4 ? tokens.length : 4;
    for (var count = 1; count <= tokenCount; count++) {
      if (_looksLikeCode(tokens.take(count).join(' '))) {
        return true;
      }
    }
    return false;
  }

  /// Table headings are not data; they must never become a class.
  bool _isHeaderRow(List<String> cells) {
    final joined = cells.join(' ').toUpperCase();
    if (joined.contains('SUBJECT DESCRIPTION')) {
      return true;
    }
    if (joined.contains('SUBJECT') &&
        joined.contains('SCHEDULE') &&
        joined.contains('ROOM')) {
      return true;
    }
    const labels = <String>{
      'CLASS',
      'SUBJECT CODE',
      'SUBJECT DESCRIPTION',
      'UNITS',
      'SCHEDULE',
      'ROOM',
      'INSTRUCTOR',
      'SECTION',
      'DAY',
      'TIME',
    };
    return cells.every((cell) => labels.contains(cell.toUpperCase()));
  }

  List<List<_Row>> _blocks(List<_Row> rows, bool hasSubjectCodes) {
    final blocks = <List<_Row>>[];
    var current = <_Row>[];
    for (final row in rows) {
      if (current.isNotEmpty && _startsBlock(row, hasSubjectCodes)) {
        blocks.add(current);
        current = <_Row>[];
      }
      current.add(row);
    }
    if (current.isNotEmpty) {
      blocks.add(current);
    }
    return blocks;
  }

  /// A new class starts at its subject-code or class-ID cell, or at a filtered
  /// scanner row that carries both a description and a schedule.
  bool _startsBlock(_Row row, bool hasSubjectCodes) {
    if (row.cells.length == 4 &&
        row.cells[1].isNotEmpty &&
        _timeHits(row.cells[2]).isNotEmpty) {
      return true;
    }
    if (row.cells.length > 1 &&
        _classIdOnly.hasMatch(row.cells.first.trim())) {
      return true;
    }
    if (hasSubjectCodes) {
      if (_subjectCodeOf(row) != null) {
        return true;
      }
      // A flattened table row carries its columns in one cell, so look for the
      // code column inside the row. Continuation rows (schedule only) and bare
      // stacked cells never start with a code, so they cannot start a class.
      if (row.cells.length == 1) {
        final text = row.cells.first;
        final hits = _timeHits(text);
        if (hits.isEmpty || hits.first.start <= 1) {
          return false;
        }
        return _leadingCode(text) != null;
      }
      return false;
    }
    if (row.cells.length > 1) {
      return _classIdOnly.hasMatch(row.cells.first.trim()) ||
          _subjectCodeOf(row) != null;
    }
    final text = row.text;
    return _classIdPrefix.hasMatch(text) && _timeHits(text).isNotEmpty;
  }

  bool _isRowLayout(List<_Row> block) {
    for (final row in block) {
      if (row.cells.length > 1) {
        return true;
      }
      final text = row.cells.first;
      if (_timeHits(text).isNotEmpty &&
          (_rowHasSubjectCode(row) || _classIdPrefix.hasMatch(text))) {
        return true;
      }
    }
    return false;
  }

  bool _rowHasSubjectCode(_Row row) {
    if (_subjectCodeOf(row) != null) {
      return true;
    }
    if (row.cells.length != 1) {
      return false;
    }
    final text = row.cells.first;
    return _timeHits(text).isNotEmpty && _leadingCode(text) != null;
  }

  /// The subject code that opens a flattened table row, after the class ID:
  /// `CS 219-RS4`, `GE-FIL 1-RS4`, `GEES-RS4`, `PROF ELEC 2-CS-RS4`.
  String? _leadingCode(String rowText) {
    final text = rowText.replaceFirst(_classIdPrefix, '').trim();
    final tokens = text
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    final code = <String>[];
    var hasDigit = false;
    var hasLetter = false;
    for (final token in tokens) {
      final clean = _trimEdgePunctuation(token);
      if (clean.isEmpty || _timeHits(clean).isNotEmpty) {
        break;
      }
      if (!_uppercaseToken.hasMatch(clean)) {
        break;
      }
      if (RegExp(r'\d').hasMatch(clean)) {
        hasDigit = true;
      }
      if (RegExp(r'[A-Z]').hasMatch(clean)) {
        hasLetter = true;
      }
      code.add(clean);
      if (code.length >= 4) {
        break;
      }
    }
    if (!hasDigit || !hasLetter || code.isEmpty) {
      return null;
    }
    return code.join(' ');
  }

  /// The subject-code column of a row (`CS 219-RS4`, `GE-FIL 1-RS4`, ...).
  ///
  /// Only cells before the schedule are considered, because subject codes
  /// always sit left of it. This also keeps a long department-style subject
  /// code (`NURSING302`) from being mistaken for the room of a flattened row.
  String? _subjectCodeOf(_Row row) {
    final scheduleIndex = row.cells.indexWhere(
      (cell) => _timeHits(cell).isNotEmpty,
    );
    final limit = scheduleIndex >= 0 ? scheduleIndex : row.cells.length;
    for (var index = 0; index < limit; index++) {
      final text = row.cells[index].trim();
      if (text.isEmpty) {
        continue;
      }
      if (_classIdOnly.hasMatch(text) ||
          _unitsOnly.hasMatch(text) ||
          _section.hasMatch(text.toUpperCase())) {
        continue;
      }
      // In a stacked layout a room sits on its own line, so it must not be
      // read as a subject code; in a flattened row a room never precedes the
      // schedule.
      if (scheduleIndex < 0 && _isRoomCell(text)) {
        continue;
      }
      if (_looksLikeCode(text)) {
        return text;
      }
    }
    return null;
  }

  /// True for an all-caps code that contains a digit or a hyphen, so a prose
  /// subject description is never mistaken for a subject code.
  bool _looksLikeCode(String text) {
    final tokens = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty || tokens.length > 4) {
      return false;
    }
    if (!tokens.every(_uppercaseToken.hasMatch)) {
      return false;
    }
    return RegExp(r'\d').hasMatch(text) || text.contains('-');
  }

  // ---------------------------------------------------------------------------
  // Subject Description column
  // ---------------------------------------------------------------------------

  String _subjectFromRowLayout(List<_Row> block) {
    var fallback = '';
    for (final row in block) {
      if (row.cells.length == 4 && row.cells[1].isNotEmpty) {
        return _clean(row.cells[1]);
      }
      final candidate = _subjectFromFlattenedRow(row.text);
      if (candidate.isEmpty) {
        continue;
      }
      final carriesTiming =
          _timeHits(row.text).isNotEmpty || _unitsInText.hasMatch(row.text);
      if (carriesTiming) {
        return candidate;
      }
      if (fallback.isEmpty) {
        fallback = candidate;
      }
    }
    return fallback;
  }

  /// Reads the description out of a flattened table row: everything after the
  /// subject code and before the units or schedule columns.
  String _subjectFromFlattenedRow(String rowText) {
    var text = rowText.trim();
    text = text.replaceFirst(_classIdPrefix, '').trim();
    if (text.isEmpty) {
      return '';
    }

    var end = text.length;
    final hits = _timeHits(text);
    if (hits.isNotEmpty) {
      end = hits.first.start;
    }
    final units = _unitsInText.firstMatch(text.substring(0, end));
    if (units != null) {
      end = units.start;
    }

    var head = text.substring(0, end).trim();
    head = _stripLeadingCode(head);
    head = _trimEdgePunctuation(head);
    if (!RegExp(r'[A-Za-z]{2,}').hasMatch(head)) {
      return '';
    }
    return _clean(head);
  }

  /// Drops the leading subject-code tokens (`CS 219-RS4`) but keeps real words.
  String _stripLeadingCode(String text) {
    final tokens = text
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    var count = 0;
    var sawDigitOrHyphen = false;
    while (count < tokens.length) {
      final token = _trimEdgePunctuation(tokens[count]);
      if (!_uppercaseToken.hasMatch(token)) {
        break;
      }
      if (RegExp(r'\d').hasMatch(token) || token.contains('-')) {
        sawDigitOrHyphen = true;
      }
      count++;
    }
    if (count == 0 || !sawDigitOrHyphen) {
      return text.trim();
    }
    return tokens.skip(count).join(' ').trim();
  }

  /// Reads the description in a stacked layout: the prose cells that follow the
  /// subject-code cell and precede the units/schedule.
  String _subjectFromStacked(List<_Row> block) {
    final parts = <String>[];
    var ended = false;
    for (final row in block) {
      for (final cell in row.cells) {
        final text = cell.trim();
        if (text.isEmpty) {
          continue;
        }
        if (!ended && _isDescriptionCell(text)) {
          parts.add(text);
        } else if (parts.isNotEmpty) {
          ended = true;
        }
      }
    }
    return _clean(parts.join(' '));
  }

  bool _isDescriptionCell(String text) {
    if (!RegExp(r'[A-Za-z]{2,}').hasMatch(text)) {
      return false;
    }
    if (_classIdOnly.hasMatch(text) ||
        _unitsOnly.hasMatch(text) ||
        _isRoomCell(text) ||
        _section.hasMatch(text.toUpperCase()) ||
        _instructor.hasMatch(text) ||
        _looksLikeCode(text) ||
        _isDayOnly(text) ||
        _timeHits(text).isNotEmpty) {
      return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Schedule and Room columns
  // ---------------------------------------------------------------------------

  List<_Meeting> _meetingsFromRowLayout(List<_Row> block) {
    final meetings = <_Meeting>[];
    var previousRoom = '';
    for (var index = 0; index < block.length; index++) {
      final row = block[index];
      final text = _scheduleTextForRow(row);
      final hits = _timeHits(text);
      if (hits.isEmpty) {
        continue;
      }
      final meeting = _meeting(
        row,
        text,
        hits,
        block,
        index,
        fallbackRoom: previousRoom,
      );
      if (meeting.room.isNotEmpty) {
        previousRoom = meeting.room;
      }
      meetings.add(meeting);
    }
    return meetings;
  }

  String _scheduleTextForRow(_Row row) {
    for (final cell in row.cells) {
      if (_timeHits(cell).isNotEmpty) {
        return cell;
      }
    }
    return row.cells.length == 1 ? row.text : '';
  }

  List<_Meeting> _meetingsFromStacked(List<_Row> block) {
    final meetings = <_Meeting>[];
    var previousRoom = '';
    for (var index = 0; index < block.length; index++) {
      final row = block[index];
      final text = row.text;
      final hits = _timeHits(text);
      if (hits.isEmpty) {
        continue;
      }
      final meeting = _meeting(
        row,
        text,
        hits,
        block,
        index,
        fallbackRoom: previousRoom,
      );
      if (meeting.room.isNotEmpty) {
        previousRoom = meeting.room;
      }
      meetings.add(meeting);
    }
    return meetings;
  }

  _Meeting _meeting(
    _Row row,
    String text,
    List<_TimeHit> hits,
    List<_Row> block,
    int index, {
    String fallbackRoom = '',
  }) {
    final days = _daysForMeeting(text, hits);
    var room = _roomForMeeting(row, text, hits);
    if (room.isEmpty) {
      room = _roomFromFollowingRows(block, index);
    }
    if (room.isEmpty) {
      room = fallbackRoom;
    }
    return _Meeting(
      spans: <_TimeSpan>[for (final hit in hits) hit.span],
      days: days,
      room: room,
      issues: <String>[
        if (days.isEmpty) 'Day not recognised',
        if (room.isEmpty) 'Room not recognised',
      ],
    );
  }

  /// Days are read only from the schedule columns, so an instructor such as
  /// `Ms. A. Trapal` can never be read as Monday/Saturday.
  List<ClassDay> _daysForMeeting(String text, List<_TimeHit> hits) {
    final days = <ClassDay>[];
    final tail = text.substring(hits.last.end);
    final tokens = tail
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    for (var i = 0; i < tokens.length && i < 3; i++) {
      final token = tokens[i];
      if (token.contains('.')) {
        break;
      }
      final parsed = _daysFromToken(_trimEdgePunctuation(token));
      if (parsed == null) {
        break;
      }
      for (final day in parsed) {
        if (!days.contains(day)) {
          days.add(day);
        }
      }
    }
    if (days.isNotEmpty) {
      return days;
    }

    // Some study loads print the day before the time (`MTh 3-4 pm`).
    final before = text
        .substring(0, hits.first.start)
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    for (var i = before.length - 1; i >= 0 && i >= before.length - 2; i--) {
      final token = before[i];
      if (token.contains('.')) {
        break;
      }
      final parsed = _daysFromToken(_trimEdgePunctuation(token));
      if (parsed == null) {
        break;
      }
      for (final day in parsed) {
        if (!days.contains(day)) {
          days.add(day);
        }
      }
    }
    return days;
  }

  String _roomForMeeting(_Row row, String text, List<_TimeHit> hits) {
    final cells = row.cells;
    if (cells.length == 4) {
      final room = _roomCodeFromColumn(cells[3]);
      if (room != null) {
        return _cleanRoom(room);
      }
    }
    final scheduleIndex = cells.indexWhere(
      (cell) => _timeHits(cell).isNotEmpty,
    );
    if (scheduleIndex >= 0) {
      final scheduleCell = cells[scheduleIndex];
      final inline = _roomAfterSchedule(scheduleCell, _timeHits(scheduleCell));
      if (inline.isNotEmpty) {
        return inline;
      }
      for (var i = scheduleIndex + 1; i < cells.length; i++) {
        final cell = cells[i];
        if (_isDayOnly(cell) || _unitsOnly.hasMatch(cell)) {
          continue;
        }
        final room = _roomCodeFromColumn(cell);
        if (room != null) {
          return _cleanRoom(room);
        }
        if (_instructor.hasMatch(cell) ||
            _section.hasMatch(cell.toUpperCase())) {
          break;
        }
      }
    }

    if (cells.length > 1) {
      for (var i = 1; i < cells.length; i++) {
        if (i == scheduleIndex) {
          continue;
        }
        if (_isRoomCell(cells[i])) {
          return _cleanRoom(cells[i]);
        }
      }
    }

    return _roomAfterSchedule(text, hits);
  }

  String? _roomCodeFromColumn(String raw) {
    final cell = _trimEdgePunctuation(raw.trim());
    if (_isRoomCell(cell)) {
      return cell;
    }
    final match = RegExp(
      r'^\s*([A-Z]{1,12}[- ]?[0-9OIL]{2,4}[A-Z]?)(?:\s|$)',
      caseSensitive: false,
    ).firstMatch(cell);
    if (match == null) {
      return null;
    }
    final candidate = match.group(1)!;
    return _section.hasMatch(candidate.toUpperCase()) ? null : candidate;
  }

  /// A room printed on the same line as the schedule, after the day codes.
  String _roomAfterSchedule(String text, List<_TimeHit> hits) {
    if (hits.isEmpty) {
      return '';
    }
    final tail = text.substring(hits.last.end);
    final prefixed = _roomPrefixedInText.firstMatch(tail);
    if (prefixed != null) {
      return _cleanRoom(prefixed.group(0)!);
    }
    final tokens = tail
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    var index = 0;
    while (index < tokens.length &&
        _daysFromToken(_trimEdgePunctuation(tokens[index])) != null) {
      index++;
    }
    for (; index < tokens.length; index++) {
      final token = _trimEdgePunctuation(tokens[index]);
      if (token.isEmpty) {
        continue;
      }
      final room = _roomCodeFromColumn(token);
      if (room != null) {
        return _cleanRoom(room);
      }
      if (_instructor.hasMatch(token)) {
        break;
      }
    }
    return '';
  }

  /// Stacked layouts put the room on the row after the schedule.
  String _roomFromFollowingRows(List<_Row> block, int index) {
    for (var i = index + 1; i < block.length; i++) {
      final row = block[i];
      if (_timeHits(row.text).isNotEmpty) {
        break;
      }
      for (final cell in row.cells) {
        if (_isRoomCell(cell)) {
          return _cleanRoom(cell);
        }
      }
    }
    return '';
  }

  bool _isRoomCell(String raw) {
    final cell = _trimEdgePunctuation(raw.trim());
    if (cell.isEmpty) {
      return false;
    }
    final upper = cell.toUpperCase();
    if (_isDayOnly(upper) ||
        _unitsOnly.hasMatch(cell) ||
        _section.hasMatch(upper) ||
        _timeHits(cell).isNotEmpty) {
      return false;
    }
    if (_roomPrefixed.hasMatch(cell)) {
      return true;
    }
    return _roomCode.hasMatch(upper) && RegExp(r'\d').hasMatch(cell);
  }

  bool _isRoomPrefixedJoin(String first, String second) {
    return RegExp(
          r'^(room|rm\.?|lab)$',
          caseSensitive: false,
        ).hasMatch(first) &&
        _roomCode.hasMatch(second.toUpperCase());
  }

  // ---------------------------------------------------------------------------
  // Days
  // ---------------------------------------------------------------------------

  bool _isDayOnly(String raw) => _daysFromCell(raw) != null;

  /// A cell that consists only of day codes (`MTh`, `TF`, `M/W`, `Monday`).
  List<ClassDay>? _daysFromCell(String raw) {
    final tokens = raw
        .trim()
        .split(RegExp(r'[\s,]+'))
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) {
      return null;
    }
    final days = <ClassDay>[];
    for (final token in tokens) {
      final parsed = _daysFromToken(token);
      if (parsed == null) {
        return null;
      }
      for (final day in parsed) {
        if (!days.contains(day)) {
          days.add(day);
        }
      }
    }
    return days.isEmpty ? null : days;
  }

  List<ClassDay>? _daysFromToken(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z/&-]'), '');
    if (cleaned.isEmpty) {
      return null;
    }
    if (cleaned.contains(RegExp(r'[/&-]'))) {
      final parts = cleaned
          .split(RegExp(r'[/&-]'))
          .where((part) => part.isNotEmpty)
          .toList();
      if (parts.isEmpty) {
        return null;
      }
      final days = <ClassDay>[];
      for (final part in parts) {
        final parsed = _daysFromWord(part);
        if (parsed == null) {
          return null;
        }
        days.addAll(parsed.where((day) => !days.contains(day)));
      }
      return days.isEmpty ? null : days;
    }
    return _daysFromWord(cleaned);
  }

  static const Map<String, ClassDay> _dayNames = <String, ClassDay>{
    'MONDAY': ClassDay.monday,
    'TUESDAY': ClassDay.tuesday,
    'WEDNESDAY': ClassDay.wednesday,
    'THURSDAY': ClassDay.thursday,
    'FRIDAY': ClassDay.friday,
    'SATURDAY': ClassDay.saturday,
    'SUNDAY': ClassDay.sunday,
    'MON': ClassDay.monday,
    'TUES': ClassDay.tuesday,
    'TUE': ClassDay.tuesday,
    'WEDS': ClassDay.wednesday,
    'WED': ClassDay.wednesday,
    'THURS': ClassDay.thursday,
    'THUR': ClassDay.thursday,
    'THU': ClassDay.thursday,
    'FRI': ClassDay.friday,
    'SAT': ClassDay.saturday,
    'SUN': ClassDay.sunday,
  };

  /// `MTh` is Monday + Thursday, `TF` is Tuesday + Friday, `W` is Wednesday.
  List<ClassDay>? _daysFromWord(String raw) {
    final upper = raw.toUpperCase();
    final named = _dayNames[upper];
    if (named != null) {
      return <ClassDay>[named];
    }
    if (!RegExp(r'^[MTWHFSU]{1,7}$').hasMatch(upper)) {
      return null;
    }
    final days = <ClassDay>[];
    var index = 0;
    while (index < upper.length) {
      final two = index + 1 < upper.length
          ? upper.substring(index, index + 2)
          : '';
      if (two == 'TH') {
        if (!days.contains(ClassDay.thursday)) {
          days.add(ClassDay.thursday);
        }
        index += 2;
        continue;
      }
      if (two == 'SU') {
        if (!days.contains(ClassDay.sunday)) {
          days.add(ClassDay.sunday);
        }
        index += 2;
        continue;
      }
      final day = switch (upper[index]) {
        'M' => ClassDay.monday,
        'T' => ClassDay.tuesday,
        'W' => ClassDay.wednesday,
        'H' => ClassDay.thursday,
        'F' => ClassDay.friday,
        'S' => ClassDay.saturday,
        _ => null,
      };
      if (day == null) {
        return null;
      }
      if (!days.contains(day)) {
        days.add(day);
      }
      index += 1;
    }
    return days.isEmpty ? null : days;
  }

  // ---------------------------------------------------------------------------
  // Times
  // ---------------------------------------------------------------------------

  List<_TimeHit> _timeHits(String text) {
    final hits = <_TimeHit>[];
    for (final match in _timeRangePattern.allMatches(text)) {
      if (!_rangeIsBounded(text, match)) {
        continue;
      }
      final startHour = int.tryParse(match.group(1)!) ?? 99;
      final endHour = int.tryParse(match.group(4)!) ?? 99;
      if (startHour > 23 || endHour > 23) {
        continue;
      }
      final span = _buildRange(match);
      if (span != null) {
        hits.add(_TimeHit(match.start, match.end, span));
      }
    }
    if (hits.isNotEmpty) {
      return hits;
    }
    final single = _singleTimePattern.firstMatch(text);
    if (single != null) {
      final minutes = _toMinutes(
        single.group(1)!,
        single.group(2)!,
        single.group(3),
        fallbackPeriod: null,
      );
      if (minutes == null) {
        return const <_TimeHit>[];
      }
      return <_TimeHit>[
        _TimeHit(
          single.start,
          single.end,
          _TimeSpan(
            start: minutes,
            end: minutes + 60,
            issues: const <String>['End time not found'],
          ),
        ),
      ];
    }
    return const <_TimeHit>[];
  }

  /// True when the range is not part of a longer number (`2026-2027`).
  bool _rangeIsBounded(String text, RegExpMatch match) {
    final before = match.start == 0 ? null : text[match.start - 1];
    final after = match.end >= text.length ? null : text[match.end];
    return !_isDigit(before) && !_isDigit(after);
  }

  bool _isDigit(String? character) {
    if (character == null) {
      return false;
    }
    final code = character.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  _TimeSpan? _buildRange(RegExpMatch match) {
    final startPeriod = _period(match.group(3));
    final endPeriod = _period(match.group(6));
    final issues = <String>[];

    String? effectiveStartPeriod = startPeriod;
    if (startPeriod == null && endPeriod != null) {
      effectiveStartPeriod = endPeriod;
    }
    if (startPeriod == null && endPeriod == null) {
      // `13:00-14:30` is already a 24-hour range and needs no AM/PM.
      final startHour24 = int.tryParse(match.group(1)!) ?? 0;
      if (startHour24 < 13) {
        issues.add('AM/PM not stated');
      }
    }

    var start = _toMinutes(
      match.group(1)!,
      match.group(2) ?? '00',
      effectiveStartPeriod,
      fallbackPeriod: null,
    );
    var end = _toMinutes(
      match.group(4)!,
      match.group(5) ?? '00',
      endPeriod,
      fallbackPeriod: effectiveStartPeriod,
    );
    if (start == null || end == null) {
      return null;
    }

    // "11:00 - 1:00 PM" means the start is also PM.
    if (startPeriod == null && endPeriod != null && start > end) {
      start = start + 12 * 60;
    }
    if (end <= start) {
      end += 12 * 60;
    }
    if (start < 0 || start >= 24 * 60 || end >= 24 * 60) {
      issues.add('Class time looks wrong');
    }
    return _TimeSpan(start: start, end: end, issues: issues);
  }

  int? _toMinutes(
    String hour,
    String minute,
    String? period, {
    required String? fallbackPeriod,
  }) {
    final h = int.tryParse(hour);
    final m = int.tryParse(minute);
    if (h == null || m == null || m > 59) {
      return null;
    }
    final normalised = _period(period) ?? _period(fallbackPeriod);
    if (normalised == null) {
      if (h > 23) {
        return null;
      }
      // No AM/PM anywhere: treat 13-23 as 24-hour, otherwise assume AM.
      return h * 60 + m;
    }
    final hour12 = h % 12;
    return (normalised == 'PM' ? hour12 + 12 : hour12) * 60 + m;
  }

  String? _period(String? value) {
    if (value == null) {
      return null;
    }
    final upper = value.replaceAll('.', '').toUpperCase();
    if (upper.contains('PM')) {
      return 'PM';
    }
    if (upper.contains('AM')) {
      return 'AM';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _clean(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

  String _trimEdgePunctuation(String value) => value
      .trim()
      .replaceAll(RegExp(r'^[\s,;:.\-–—|]+'), '')
      .replaceAll(RegExp(r'[\s,;:|\-–—]+$'), '')
      .trim();

  String _cleanRoom(String value) {
    var cleaned = _trimEdgePunctuation(_clean(value));
    if (RegExp(r'^Room\s+', caseSensitive: false).hasMatch(cleaned)) {
      return _clean(cleaned);
    }
    cleaned = cleaned.replaceFirst(
      RegExp(r'^Room\s+', caseSensitive: false),
      '',
    );
    final match = RegExp(
      r'^([A-Z]{1,12})[- ]?([0-9OIL]{2,4}[A-Z]?)$',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (match == null) {
      return cleaned;
    }
    final number = match
        .group(2)!
        .toUpperCase()
        .replaceAll('O', '0')
        .replaceAll(RegExp(r'[IL]'), '1');
    return '${match.group(1)!.toUpperCase()}-$number';
  }

  List<ParsedClass> _finish(List<ParsedClass> classes) {
    final unique = _dedupe(classes);
    final groups = <String, List<ParsedClass>>{};
    final groupOrder = <String>[];
    for (var index = 0; index < unique.length; index++) {
      final item = unique[index];
      final canMerge =
          item.days.isNotEmpty &&
          item.startMinutes != null &&
          item.endMinutes != null;
      final key = canMerge
          ? '${item.subject.trim().toUpperCase()}|'
                '${item.roomText.trim().toUpperCase()}|'
                '${item.days.map((day) => day.name).join(',')}'
          : 'unmerged:$index';
      if (!groups.containsKey(key)) {
        groups[key] = <ParsedClass>[];
        groupOrder.add(key);
      }
      groups[key]!.add(item);
    }

    final result = <ParsedClass>[];
    for (final key in groupOrder) {
      final group = groups[key]!;
      group.sort(
        (a, b) => (a.startMinutes ?? 0).compareTo(b.startMinutes ?? 0),
      );
      ParsedClass? current;
      for (final item in group) {
        final previous = current;
        if (previous != null &&
            previous.endMinutes == item.startMinutes &&
            !previous.issues.contains('End time not found') &&
            !item.issues.contains('End time not found')) {
          final issues = <String>[...previous.issues];
          for (final issue in item.issues) {
            if (!issues.contains(issue)) {
              issues.add(issue);
            }
          }
          current = ParsedClass(
            subject: previous.subject,
            roomText: previous.roomText,
            days: previous.days,
            startMinutes: previous.startMinutes,
            endMinutes: item.endMinutes,
            issues: issues,
          );
        } else {
          if (previous != null) {
            result.add(previous);
          }
          current = item;
        }
      }
      if (current != null) {
        result.add(current);
      }
    }
    return result;
  }

  List<ParsedClass> _dedupe(List<ParsedClass> classes) {
    final seen = <String>{};
    final result = <ParsedClass>[];
    for (final item in classes) {
      final key =
          '${item.subject.toUpperCase()}|'
          '${item.days.map((day) => day.name).join(',')}|'
          '${item.startMinutes}|${item.roomText.toUpperCase()}';
      if (seen.add(key)) {
        result.add(item);
      }
    }
    return result;
  }
}

/// One visual row of the table, split into cells when the scanner supplies
/// tab-separated columns.
class _Row {
  _Row(this.cells);

  final List<String> cells;

  String get text => cells.where((cell) => cell.isNotEmpty).join(' ').trim();
}

class _TimeHit {
  const _TimeHit(this.start, this.end, this.span);

  final int start;
  final int end;
  final _TimeSpan span;
}

class _TimeSpan {
  const _TimeSpan({
    required this.start,
    required this.end,
    required this.issues,
  });

  final int start;
  final int end;
  final List<String> issues;
}

class _Meeting {
  const _Meeting({
    required this.spans,
    required this.days,
    required this.room,
    required this.issues,
  });

  final List<_TimeSpan> spans;
  final List<ClassDay> days;
  final String room;
  final List<String> issues;
}
