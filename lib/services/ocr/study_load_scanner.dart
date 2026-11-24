import 'dart:io';
import 'dart:math' as math;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfx/pdfx.dart';

import 'pdf_text_extractor.dart';
import 'study_load_parser.dart';

/// The file a student picked or photographed.
class StudyLoadFile {
  const StudyLoadFile({
    required this.path,
    required this.isPdf,
    required this.label,
  });

  final String path;
  final bool isPdf;
  final String label;
}

/// Progress stage reported to the Scanning screen.
enum ScanStage { reading, subjects, schedule, rooms }

class ScanProgress {
  const ScanProgress({required this.value, required this.stage});

  final double value;
  final ScanStage stage;
}

/// One OCR line plus where it sits on the page, so table rows and columns can
/// be reconstructed.
class _OcrLine {
  _OcrLine({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.isElement = false,
    this.hasElements = false,
    this.parentText,
  });

  String text;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final bool isElement;
  final bool hasElements;
  final String? parentText;
  String? column;

  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
  double get height => math.max(bottom - top, 1);
}

/// A scan failure with a message that can be shown to the student as-is.
class ScanException implements Exception {
  const ScanException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Runs on-device OCR over a photo or PDF and parses the study load.
///
/// Everything happens locally: ML Kit for images, embedded PDF text first and
/// page rendering plus OCR only when a PDF has no text layer.
class StudyLoadScanner {
  const StudyLoadScanner();

  Future<List<ParsedClass>> scan(
    StudyLoadFile file, {
    void Function(ScanProgress progress)? onProgress,
  }) async {
    void report(double value, ScanStage stage) =>
        onProgress?.call(ScanProgress(value: value, stage: stage));

    report(0.1, ScanStage.reading);
    final String rawText;
    try {
      rawText = file.isPdf
          ? await _readPdf(file.path, report)
          : await _recogniseImage(file.path);
    } on ScanException {
      rethrow;
    } on Exception catch (error) {
      throw ScanException(
        'Could not read the study load on this device. '
        '(${error.runtimeType})',
      );
    }

    report(0.7, ScanStage.subjects);
    final parser = const StudyLoadParser();
    final classes = parser.parse(rawText);
    report(0.85, ScanStage.schedule);
    report(1, ScanStage.rooms);

    if (classes.isEmpty) {
      throw const ScanException(
        'No classes were found in that file. Try a clearer photo or a different '
        'page.',
      );
    }
    return classes;
  }

  /// Opens a table row: the leftmost cell is an enrolment class ID such as
  /// `C161` or `C21`.
  static final RegExp _classIdAtStart = RegExp(r'^\s*[A-Z]{1,3}-?\d{1,4}\b');

  /// A schedule cell such as `3-4 pm`, `9-10 am` or `10 am-12 pm`.
  static final RegExp _scheduleHint = RegExp(
    r'\d{1,2}(?::\d{2})?\s*(?:[ap]\.?m\.?)?\s*[-–—]\s*\d{1,2}',
    caseSensitive: false,
  );
  static final RegExp _roomCodeHint = RegExp(
    r'^[A-Z]{1,12}[- ]?[A-Z0-9]{2,4}$',
    caseSensitive: false,
  );
  static final RegExp _sectionHint = RegExp(
    r'^[A-Z]{2,6}\s*-?\s*\d{1,2}[A-Z]?$',
    caseSensitive: false,
  );

  Future<String> _recogniseImage(String path) async {
    final recogniser = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(path);
      final recognised = await recogniser.processImage(input);

      final allLines = <_OcrLine>[];
      for (final block in recognised.blocks) {
        for (final line in block.lines) {
          final text = line.text.trim();
          if (text.isEmpty) {
            continue;
          }
          final box = line.boundingBox;
          allLines.add(
            _OcrLine(
              text: text,
              left: box.left,
              top: box.top,
              right: box.right,
              bottom: box.bottom,
              hasElements: line.elements.isNotEmpty,
            ),
          );
          for (final element in line.elements) {
            final elementText = element.text.trim();
            if (elementText.isEmpty) {
              continue;
            }
            final elementBox = element.boundingBox;
            allLines.add(
              _OcrLine(
                text: elementText,
                left: elementBox.left,
                top: elementBox.top,
                right: elementBox.right,
                bottom: elementBox.bottom,
                isElement: true,
                parentText: text,
              ),
            );
          }
        }
      }
      if (allLines.isEmpty) {
        return '';
      }
      return _tableText(allLines);
    } finally {
      await recogniser.close();
    }
  }

  /// Rebuilds the table as text rows, one cell per column, separated by tabs.
  ///
  /// ML Kit splits a page into blocks and lines, and a table's columns often
  /// arrive as separate blocks. Grouping lines by vertical overlap restores a
  /// visual row, and a row that carries no class ID and no schedule is a
  /// wrapped line of the row above, so its cells are folded into the matching
  /// column instead of becoming a class of their own.
  String _tableText(List<_OcrLine> allLines) {
    final lineLevel = allLines.where((line) => !line.isElement).toList()
      ..sort((a, b) => a.top.compareTo(b.top));
    final columns = _columnCenters(allLines);
    final sorted = <_OcrLine>[
      if (columns == null)
        ...lineLevel
      else ...[
        ...lineLevel.where(
          (line) => _headerColumn(line.text) != null || !line.hasElements,
        ),
        ...allLines.where((line) => line.isElement),
      ],
    ]..sort((a, b) => a.top.compareTo(b.top));

    final rows = <List<_OcrLine>>[];
    for (final line in sorted) {
      List<_OcrLine>? target;
      for (final row in rows.reversed.take(4)) {
        if (_sameRow(row, line)) {
          target = row;
          break;
        }
      }
      if (target != null) {
        target.add(line);
      } else {
        rows.add(<_OcrLine>[line]);
      }
    }

    if (columns != null) {
      return _tableTextForColumns(rows, sorted, columns);
    }

    // The class-ID column is located from the lines that look like class IDs,
    // not from the whole page, so a page header at the far left does not widen
    // the first column.
    var classLeft = sorted.first.left;
    var hasClassId = false;
    for (final line in sorted) {
      if (!_classIdAtStart.hasMatch(line.text)) {
        continue;
      }
      if (!hasClassId || line.left < classLeft) {
        classLeft = line.left;
        hasClassId = true;
      }
    }
    if (!hasClassId) {
      classLeft = sorted.map((line) => line.left).reduce(math.min);
    }
    final tableRight = sorted.map((line) => line.right).reduce(math.max);

    final merged = <List<_OcrLine>>[];
    for (final row in rows) {
      final startsRecord = _startsRecord(row, classLeft, tableRight);
      final hasSchedule = row.any((line) => _scheduleHint.hasMatch(line.text));
      if (merged.isNotEmpty && !startsRecord && !hasSchedule) {
        for (final cell in row) {
          _appendToColumn(merged.last, cell);
        }
        continue;
      }
      merged.add(<_OcrLine>[...row]);
    }

    final buffer = StringBuffer();
    for (final row in merged) {
      row.sort((a, b) => a.left.compareTo(b.left));
      final cells = row
          .map((line) => line.text.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((text) => text.isNotEmpty);
      if (cells.isEmpty) {
        continue;
      }
      buffer.writeln(cells.join('\t'));
    }
    return buffer.toString().trim();
  }

  Map<String, double>? _columnCenters(List<_OcrLine> lines) {
    final centers = <String, double>{};
    for (final line in lines.where((line) => !line.isElement)) {
      final column = _headerColumn(line.text);
      if (column != null) {
        centers[column] = line.centerX;
      }
    }
    final elementGroups = <String, List<_OcrLine>>{};
    for (final element in lines.where((line) => line.isElement)) {
      final parentText = element.parentText;
      if (parentText == null) {
        continue;
      }
      final normalizedParent = parentText
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z]'), '');
      if (!normalizedParent.contains('subject') ||
          !normalizedParent.contains('schedule') ||
          !normalizedParent.contains('room')) {
        continue;
      }
      elementGroups.putIfAbsent(parentText, () => <_OcrLine>[]).add(element);
    }
    for (final elements in elementGroups.values) {
      elements.sort((a, b) => a.left.compareTo(b.left));
      for (var index = 0; index < elements.length; index++) {
        final normalized = elements[index]
            .text
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z]'), '');
        final singleWordColumn = switch (normalized) {
          'class' => 'class',
          'units' || 'unit' => 'units',
          'schedule' => 'schedule',
          'room' => 'room',
          'instructor' => 'instructor',
          'section' => 'section',
          _ => null,
        };
        if (singleWordColumn != null) {
          centers[singleWordColumn] = elements[index].centerX;
        }
        if (normalized != 'subject' || index + 1 >= elements.length) {
          continue;
        }
        final next = elements[index + 1]
            .text
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z]'), '');
        if (next != 'code' && next != 'description') {
          continue;
        }
        final column = next == 'code' ? 'subjectCode' : 'description';
        centers[column] =
            (elements[index].centerX + elements[index + 1].centerX) / 2;
      }
    }
    const required = <String>{
      'subjectCode',
      'description',
      'units',
      'schedule',
      'room',
      'instructor',
    };
    if (!required.every(centers.containsKey)) {
      return null;
    }
    return centers;
  }

  String? _headerColumn(String text) {
    final normalized = text.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (normalized == 'class') {
      return 'class';
    }
    if (normalized.contains('subjectcode')) {
      return 'subjectCode';
    }
    if (normalized.contains('subjectdescription')) {
      return 'description';
    }
    if (normalized == 'unit' || normalized == 'units') {
      return 'units';
    }
    if (normalized.contains('schedule')) {
      return 'schedule';
    }
    if (normalized == 'room') {
      return 'room';
    }
    if (normalized.contains('instructor')) {
      return 'instructor';
    }
    if (normalized == 'section') {
      return 'section';
    }
    return null;
  }

  String? _columnAt(double centerX, Map<String, double> centers) {
    String? closest;
    var closestDistance = double.infinity;
    centers.forEach((column, center) {
      final distance = (centerX - center).abs();
      if (distance < closestDistance) {
        closest = column;
        closestDistance = distance;
      }
    });
    return closest;
  }

  String? _columnForDataLine(_OcrLine line, Map<String, double> centers) {
    final header = _headerColumn(line.text);
    if (header != null) {
      return header;
    }
    final nearest = _columnAt(line.centerX, centers);
    final text = line.text.trim();
    if (nearest != 'class' &&
        _roomCodeHint.hasMatch(text) &&
        !_sectionHint.hasMatch(text)) {
      return 'room';
    }
    return nearest;
  }

  String _tableTextForColumns(
    List<List<_OcrLine>> rows,
    List<_OcrLine> allLines,
    Map<String, double> centers,
  ) {
    final headerBottom = allLines
        .where((line) => _headerColumn(line.text) != null)
        .map((line) => line.bottom)
        .reduce(math.max);
    for (final line in allLines) {
      line.column = _columnForDataLine(line, centers);
    }

    const targetColumns = <String>{'class', 'description', 'schedule', 'room'};

    String cellText(List<_OcrLine> row, String column) {
      final cells = row.where((line) => line.column == column).toList()
        ..sort((a, b) => a.left.compareTo(b.left));
      return cells
          .map((line) => line.text.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((text) => text.isNotEmpty)
          .join(' ');
    }

    final merged = <List<_OcrLine>>[];
    for (final row in rows) {
      final cells = row
          .where(
            (line) =>
                line.centerY > headerBottom &&
                !line.hasElements &&
                targetColumns.contains(line.column),
          )
          .toList();
      if (cells.isEmpty) {
        continue;
      }
      final scheduleText = cellText(cells, 'schedule');
      final startsRecord =
          cells.any(
            (line) =>
                line.column == 'class' && _classIdAtStart.hasMatch(line.text),
          ) ||
          (cells.any((line) => line.column == 'description') &&
              _scheduleHint.hasMatch(scheduleText));
      final hasSchedule = _scheduleHint.hasMatch(scheduleText);
      if (merged.isNotEmpty && !startsRecord && !hasSchedule) {
        for (final cell in cells) {
          _appendToColumn(merged.last, cell);
        }
      } else {
        merged.add(cells);
      }
    }

    final buffer = StringBuffer();
    for (final row in merged) {
      final values = <String>[
        cellText(row, 'class'),
        cellText(row, 'description'),
        cellText(row, 'schedule'),
        cellText(row, 'room'),
      ];
      if (values.every((value) => value.isEmpty)) {
        continue;
      }
      buffer.writeln(values.join('\t'));
    }
    return buffer.toString().trimRight();
  }

  bool _sameRow(List<_OcrLine> row, _OcrLine line) {
    var top = row.first.top;
    var bottom = row.first.bottom;
    for (final other in row) {
      top = math.min(top, other.top);
      bottom = math.max(bottom, other.bottom);
    }
    final overlap = math.min(bottom, line.bottom) - math.max(top, line.top);
    if (overlap > 0 && overlap >= math.min(bottom - top, line.height) * 0.5) {
      return true;
    }
    return ((top + bottom) / 2 - line.centerY).abs() <= 6;
  }

  /// True when the row opens a class record.
  ///
  /// A wrapped Subject Code cell also looks like a class ID (`RS4` under
  /// `PROF ELEC 1-`), so a row only starts a record when its leftmost line is
  /// in the table's first column rather than in a later column.
  bool _startsRecord(List<_OcrLine> row, double classLeft, double tableRight) {
    if (row.isEmpty) {
      return false;
    }
    final leftmost = row.reduce((a, b) => a.left <= b.left ? a : b);
    final margin = math.max(
      leftmost.height * 2,
      (tableRight - classLeft) * 0.05,
    );
    if (leftmost.left > classLeft + margin) {
      return false;
    }
    return _classIdAtStart.hasMatch(leftmost.text);
  }

  /// Folds a wrapped cell's text into the column of the row above it.
  ///
  /// Columns are chosen by horizontal overlap rather than by centre distance:
  /// a wrapped second line of a description (`Seminars` under `Observational
  /// Visits &`) is narrower than the cell above it, so its centre can sit
  /// closer to the neighbouring Subject Code cell even though the line lies
  /// inside the Subject Description column.
  void _appendToColumn(List<_OcrLine> row, _OcrLine cell) {
    if (row.isEmpty) {
      row.add(cell);
      return;
    }
    final candidates = cell.column == null
        ? row
        : row.where((existing) => existing.column == cell.column).toList();
    if (candidates.isEmpty) {
      row.add(cell);
      return;
    }
    _OcrLine? best;
    var bestOverlap = 0.0;
    var bestDistance = double.infinity;
    for (final existing in candidates) {
      final overlap =
          math.min(existing.right, cell.right) -
          math.max(existing.left, cell.left);
      final distance = (existing.centerX - cell.centerX).abs();
      if (overlap > bestOverlap ||
          (overlap > 0 && overlap == bestOverlap && distance < bestDistance)) {
        best = existing;
        bestOverlap = overlap;
        bestDistance = distance;
      }
    }
    if (best == null) {
      // No horizontal overlap: fall back to the nearest centre, but only when
      // it is close enough to be the same wrapped cell.
      for (final existing in candidates) {
        final distance = (existing.centerX - cell.centerX).abs();
        if (distance < bestDistance) {
          best = existing;
          bestDistance = distance;
        }
      }
      if (best == null ||
          bestDistance > math.max(best.height, cell.height) * 4) {
        row.add(cell);
        return;
      }
    }
    best.text = '${best.text} ${cell.text}';
  }

  Future<String> _readPdf(
    String path,
    void Function(double value, ScanStage stage) report,
  ) async {
    // Embedded text first: it is exact and needs no OCR.
    try {
      final embedded = await const PdfTextExtractor().extractFile(File(path));
      if (PdfTextExtractor.looksUsable(embedded)) {
        report(0.6, ScanStage.reading);
        return embedded;
      }
    } on Exception {
      // Fall through to rendering.
    }

    // No usable text layer: render every page and OCR the pixels instead.
    final rendered = await PdfDocument.openFile(path);
    try {
      final buffer = StringBuffer();
      for (var index = 1; index <= rendered.pagesCount; index++) {
        final page = await rendered.getPage(index);
        final image = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );
        await page.close();
        final bytes = image?.bytes;
        if (bytes == null) {
          continue;
        }
        final temp = File(
          '${Directory.systemTemp.path}/campus_nav_page_$index.png',
        );
        await temp.writeAsBytes(bytes, flush: true);
        try {
          buffer.writeln(await _recogniseImage(temp.path));
        } finally {
          if (await temp.exists()) {
            await temp.delete();
          }
        }
        report(0.1 + 0.5 * (index / rendered.pagesCount), ScanStage.reading);
      }
      return buffer.toString();
    } finally {
      await rendered.close();
    }
  }
}
