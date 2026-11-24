import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Best-effort pure-Dart extraction of a PDF's embedded text layer.
///
/// Study loads are usually exported from a word processor, so their content
/// streams are plain Flate-compressed text operators. When a PDF has no useful
/// text layer (a scan, or an unusual font encoding) [looksUsable] returns false
/// and the scanner falls back to rendering pages and running OCR.
class PdfTextExtractor {
  const PdfTextExtractor();

  Future<String> extractFile(File file) async {
    final bytes = await file.readAsBytes();
    return extractBytes(bytes);
  }

  String extractBytes(Uint8List bytes) {
    final raw = latin1.decode(bytes, allowInvalid: true);
    final buffer = StringBuffer();

    var index = 0;
    while (true) {
      final start = raw.indexOf('stream', index);
      if (start < 0) {
        break;
      }
      final afterKeyword = start + 'stream'.length;
      var contentStart = afterKeyword;
      if (contentStart < raw.length && raw[contentStart] == '\r') {
        contentStart++;
      }
      if (contentStart < raw.length && raw[contentStart] == '\n') {
        contentStart++;
      }
      final end = raw.indexOf('endstream', contentStart);
      if (end < 0) {
        break;
      }
      final dictionary = raw.substring(start > 400 ? start - 400 : 0, start);
      final payload = bytes.sublist(contentStart, end);

      Uint8List? decoded;
      if (dictionary.contains('/FlateDecode')) {
        try {
          decoded = Uint8List.fromList(ZLibCodec().decode(payload));
        } on Exception {
          decoded = null;
        }
      }
      if (decoded != null) {
        final text = _extractFromContent(
          latin1.decode(decoded, allowInvalid: true),
        );
        if (text.trim().isNotEmpty) {
          buffer.writeln(text);
        }
      }
      index = end + 'endstream'.length;
    }

    return buffer.toString();
  }

  /// True when the extracted text is worth parsing instead of running OCR.
  static bool looksUsable(String text) {
    final trimmed = text.trim();
    if (trimmed.length < 20) {
      return false;
    }
    final runes = trimmed.runes.toList(growable: false);
    var readable = 0;
    for (final rune in runes) {
      final isLetter =
          (rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A);
      if (isLetter || rune == 0x20 || rune == 0x0A) {
        readable++;
      }
    }
    return readable / runes.length > 0.6;
  }

  String _extractFromContent(String content) {
    final buffer = StringBuffer();
    var index = 0;
    while (index < content.length) {
      final char = content[index];
      if (char == '(') {
        final result = _readLiteral(content, index);
        buffer.write(result.text);
        index = result.next;
        continue;
      }
      if (char == '[') {
        index++;
        while (index < content.length && content[index] != ']') {
          if (content[index] == '(') {
            final result = _readLiteral(content, index);
            buffer.write(result.text);
            index = result.next;
          } else {
            index++;
          }
        }
        index++;
        continue;
      }
      if (content.startsWith('Td', index) ||
          content.startsWith('TD', index) ||
          content.startsWith('T*', index) ||
          content.startsWith('ET', index)) {
        final current = buffer.toString();
        if (current.isNotEmpty && !current.endsWith('\n')) {
          buffer.write('\n');
        }
        index += 2;
        continue;
      }
      index++;
    }
    return buffer.toString();
  }

  ({String text, int next}) _readLiteral(String content, int start) {
    final buffer = StringBuffer();
    var index = start + 1;
    while (index < content.length) {
      final char = content[index];
      if (char == r'\') {
        if (index + 1 >= content.length) {
          break;
        }
        final escaped = content[index + 1];
        switch (escaped) {
          case 'n':
            buffer.write('\n');
          case 'r':
            buffer.write('\r');
          case 't':
            buffer.write('\t');
          case '(':
          case ')':
          case r'\':
            buffer.write(escaped);
          default:
            // Octal escapes such as \050.
            final octal = RegExp(
              r'^[0-7]{1,3}',
            ).firstMatch(content.substring(index + 1));
            if (octal != null) {
              buffer.writeCharCode(int.parse(octal.group(0)!, radix: 8));
              index += octal.group(0)!.length;
            } else {
              buffer.write(escaped);
            }
        }
        index += 2;
        continue;
      }
      if (char == ')') {
        return (text: buffer.toString(), next: index + 1);
      }
      buffer.write(char);
      index++;
    }
    return (text: buffer.toString(), next: index);
  }
}
