import 'package:campus_nav/data/models/scheduled_class.dart';
import 'package:campus_nav/services/ocr/study_load_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = StudyLoadParser();

  test('parses a stacked study load layout', () {
    const raw = '''
CS 101 - Introduction to Computing
MWF 9:00 AM - 10:30 AM
Room 204
''';
    final classes = parser.parse(raw);
    expect(classes.length, 3);
    expect(classes.first.subject, 'CS 101 - Introduction to Computing');
    expect(classes.first.roomText, 'Room 204');
    expect(classes.first.startMinutes, 9 * 60);
    expect(classes.first.endMinutes, 10 * 60 + 30);
    expect(
      classes.map((item) => item.days.first),
      containsAll(<ClassDay>[
        ClassDay.monday,
        ClassDay.wednesday,
        ClassDay.friday,
      ]),
    );
  });

  test('parses a room code on its own line', () {
    const raw = '''
MATH 120
Tue 1:00 PM - 2:30 PM
T-201
''';
    final classes = parser.parse(raw);
    expect(classes.length, 1);
    expect(classes.single.roomText, 'T-201');
    expect(classes.single.days.single, ClassDay.tuesday);
    expect(classes.single.needsReview, isFalse);
  });

  test('handles 24-hour times', () {
    final classes = parser.parse('IT 201\nThu 13:00 - 14:30\nMB-104');
    expect(classes.single.startMinutes, 13 * 60);
    expect(classes.single.endMinutes, 14 * 60 + 30);
  });

  test('flags a missing end time instead of guessing silently', () {
    final classes = parser.parse('ENG 102\nWed 9:00 AM\nA-105');
    expect(classes, hasLength(1));
    expect(classes.single.endMinutes, 9 * 60 + 60);
    expect(classes.single.issues, contains('End time not found'));
    expect(classes.single.needsReview, isTrue);
  });

  test('flags an unrecognised room', () {
    final classes = parser.parse('BIO 110\nMon 8:00 AM - 9:30 AM\nTBA');
    expect(classes.single.roomText, isEmpty);
    expect(classes.single.needsReview, isTrue);
    expect(classes.single.issues, contains('Room not recognised'));
  });

  test('flags AM/PM that the scan did not state', () {
    final classes = parser.parse('CS 102\nMWF 1:00 - 2:30\nT-202');
    expect(classes.first.issues, contains('AM/PM not stated'));
  });

  test('reads compact day codes such as TTh', () {
    final classes = parser.parse('PE 1\nTTh 7:30-9:00 AM\nGym');
    expect(
      classes.map((item) => item.days.single),
      containsAll(<ClassDay>[ClassDay.tuesday, ClassDay.thursday]),
    );
  });

  test('returns nothing for text without classes', () {
    expect(parser.parse(''), isEmpty);
    expect(
      parser.parse('Republic of the Philippines\nBiPSU Main Campus'),
      isEmpty,
    );
  });

  test('reads a real SIAS enrolment table', () {
    const raw = '''
Student 24-1-02029 Carbero, Gregor M.
Period 26-1 School Year 2026-2027 1st Seme
Class Subject Code Subject Description Units Schedule Room Instructor Section
C161 CS 219-RS4 Information Management 3.0 3-4 pm MTh TECH302 Dr. R. Santian** BSCS 2C
4-5 pm MTh TECH302 Dr. R. Santian**
C21 GE-FIL 1-RS4 Global na Perspektibo sa Sarili 3.0 5-6 pm MTh BI1101 Ms. A. Trapal BSCS 3C
C17 CS 3112-RS4 Architecture & Organization w** 3.0 9-10 am TF TECH302 Mr. E Peñara** BSCS 3C
9-10 am MTh TECH203 Mr. E Peñara**
C23 PROF ELEC 1--- Observational Visits & Seminars 3.0 4-5 pm TF C102 Mrs. M. Bustil** BSCS 3C
C22 GEES-RS4 Environmental Science 3.0 6-7 pm TF C202 Mr. R. Quinto BSCS 3C
C19 CS 3114-RS4 Application Development & Em** 3.0 10 am-12 pm W TECH302 Ms. MA Palma BSCS 3C
C20 CS 3115-RS4 Programming Languages 3.0 1-3 pm W TECH202 Mr. Jake Abor** BSCS 3C
3-5 pm W TECH202 Mr. Jake Abor**
C24 PROF ELEC 2--- Graphics & Visual Computing 3.0 5-7 pm W TECH203 Ms. X. Victoria BSCS 3C
10-11 am MTh TECH202 Ms. X. Victoria BSCS 3C
''';
    final classes = parser.parse(raw);

    ParsedClass find(String subject, ClassDay day, int start) =>
        classes.firstWhere(
          (item) =>
              item.subject.contains(subject) &&
              item.days.single == day &&
              item.startMinutes == start,
          orElse: () => throw StateError('missing $subject $day $start'),
        );

    expect(
      find('Information Management', ClassDay.monday, 15 * 60).roomText,
      'TECH-302',
    );
    expect(
      find('Information Management', ClassDay.monday, 15 * 60).subject,
      'Information Management',
    );
    expect(
      find('Information Management', ClassDay.monday, 15 * 60).endMinutes,
      17 * 60,
    );
    expect(
      find('Information Management', ClassDay.monday, 15 * 60).roomText,
      'TECH-302',
    );
    expect(
      find('Information Management', ClassDay.thursday, 15 * 60).endMinutes,
      17 * 60,
    );
    expect(
      classes.where(
        (item) =>
            item.subject == 'Information Management' &&
            item.days.single == ClassDay.monday,
      ),
      hasLength(1),
    );
    expect(
      classes.every(
        (item) =>
            !item.subject.contains('C161') &&
            !item.subject.contains('219-RS4') &&
            !item.subject.contains('Santian') &&
            !item.subject.contains('BSCS'),
      ),
      isTrue,
    );
    expect(find('Architecture', ClassDay.tuesday, 9 * 60).roomText, 'TECH-302');
    expect(
      find('Global na Perspektibo', ClassDay.monday, 17 * 60).roomText,
      'BI-1101',
    );
    expect(
      find('Application Development', ClassDay.wednesday, 10 * 60).endMinutes,
      12 * 60,
    );
    expect(
      find('Programming Languages', ClassDay.wednesday, 13 * 60).roomText,
      'TECH-202',
    );
    expect(
      find('Programming Languages', ClassDay.wednesday, 13 * 60).endMinutes,
      17 * 60,
    );
    expect(
      find('Graphics & Visual Computing', ClassDay.monday, 10 * 60).roomText,
      'TECH-202',
    );
    expect(
      find('Environmental Science', ClassDay.friday, 18 * 60).endMinutes,
      19 * 60,
    );
    expect(classes.where((item) => item.subject == 'Class'), isEmpty);
    expect(classes.every((item) => item.issues.isEmpty), isTrue);
  });

  test('reads schedule and room from their own table columns', () {
    const raw = '''
Class\tSubject Code\tSubject Description\tUnits\tSchedule\tRoom\tInstructor\tSection
C161\tCS 219-RS4\tInformation Management\t3.0\t3-4 pm MTh\tTECH302\tDr. R. Santianez\tBSCS 2C
\t\t\t\t4-5 pm MTh\tTECH302\tDr. R. Santianez\t
C17\tCS 3112-RS4\tArchitecture & Organization\t3.0\t9-10 am TF\tTECH302\tMr. E. Penara\tBSCS 3C
\t\t\t\t9-10 am MTh\tTECH203\tMr. E. Penara\t
C22\tGEES-RS4\tEnvironmental Science\t3.0\t6-7 pm TF\tC202\tDr. R. Quinto 3:06 pm\tBSCS 3C
C19\t\tApplication Development\t3.0\t10 am-12 pm W\tTECH302\tMs. M. Palma\tBSCS 3C
\t\t\t\t8-10 am W\tTECH302\tMs. M. Palma\t
C20\tCS 3115-RS4\tProgramming Languages\t3.0\t1-3 pm W\tTECH202\tMr. Jake Abor\tBSCS 3C
\t\t\t\t3-5 pm W\tTECH202\tMr. Jake Abor\t
C24\tPROF ELEC 2\tGraphics & Visual Computing\t3.0\t5-7 pm W\tTECH203\tMs. X. Victoria\tBSCS 3C
\t\t\t\t10-11 am MTh\tTECH202\tMs. X. Victoria\t
''';
    final classes = parser.parse(raw);

    ParsedClass find(String subject, ClassDay day, int start) =>
        classes.firstWhere(
          (item) =>
              item.subject.contains(subject) &&
              item.days.single == day &&
              item.startMinutes == start,
          orElse: () => throw StateError('missing $subject $day $start'),
        );

    expect(
      find('Information Management', ClassDay.monday, 15 * 60).endMinutes,
      17 * 60,
    );
    expect(find('Architecture', ClassDay.tuesday, 9 * 60).roomText, 'TECH-302');
    expect(
      find('Architecture', ClassDay.thursday, 9 * 60).roomText,
      'TECH-203',
    );
    expect(
      find('Environmental Science', ClassDay.tuesday, 18 * 60).startMinutes,
      18 * 60,
    );
    expect(
      find('Environmental Science', ClassDay.tuesday, 18 * 60).roomText,
      'C-202',
    );
    expect(
      find('Application Development', ClassDay.wednesday, 8 * 60).endMinutes,
      12 * 60,
    );
    expect(
      find('Application Development', ClassDay.wednesday, 8 * 60).roomText,
      'TECH-302',
    );
    expect(
      find('Programming Languages', ClassDay.wednesday, 13 * 60).endMinutes,
      17 * 60,
    );
    expect(
      find('Programming Languages', ClassDay.wednesday, 13 * 60).roomText,
      'TECH-202',
    );
    expect(
      find('Graphics & Visual Computing', ClassDay.wednesday, 17 * 60).roomText,
      'TECH-203',
    );
    expect(
      find('Graphics & Visual Computing', ClassDay.monday, 10 * 60).roomText,
      'TECH-202',
    );
    expect(classes.every((item) => !item.roomText.startsWith('BSCS')), isTrue);
    expect(classes.every((item) => item.startMinutes != 15 * 60 + 6), isTrue);
  });

  test('parses filtered scanner rows without subject codes', () {
    const raw = '''
C19\tApplication Development\t10 am-12 pm W\tTECH302
\t\t8-10 am W\tTECH302
C20\tProgramming Languages\t1-3 pm W\tTECH202
\t\t3-5 pm W\tTECH202
''';
    final classes = parser.parse(raw);

    expect(classes, hasLength(2));
    final application = classes.firstWhere(
      (item) => item.subject == 'Application Development',
    );
    final programming = classes.firstWhere(
      (item) => item.subject == 'Programming Languages',
    );
    expect(application.startMinutes, 8 * 60);
    expect(application.endMinutes, 12 * 60);
    expect(application.roomText, 'TECH-302');
    expect(programming.startMinutes, 13 * 60);
    expect(programming.endMinutes, 17 * 60);
    expect(programming.roomText, 'TECH-202');
    expect(application.days.single, ClassDay.wednesday);
    expect(programming.days.single, ClassDay.wednesday);
  });

  test('recovers OCR letter substitutions from the room column', () {
    final classes = parser.parse(
      'C20\tProgramming Languages\t1-3 pm W\tTECH3O2',
    );

    expect(classes, hasLength(1));
    expect(classes.single.roomText, 'TECH-302');
    expect(classes.single.needsReview, isFalse);
  });

  test('extracts a room code when OCR appends text from an adjacent column', () {
    final classes = parser.parse(
      'C20\tProgramming Languages\t1-3 pm W\tTECH302 Dr. J. Abor',
    );

    expect(classes, hasLength(1));
    expect(classes.single.roomText, 'TECH-302');
    expect(classes.single.needsReview, isFalse);
  });

  test('does not treat a section like BSCS-30C as a room', () {
    final classes = parser.parse(
      'C24\tGraphics & Visual Computing\t5-7 pm W\tBSCS-30C',
    );

    expect(classes, hasLength(1));
    expect(classes.single.roomText, isEmpty);
    expect(classes.single.issues, contains('Room not recognised'));
  });

  test('merges stacked consecutive times and carries the subject and room', () {
    const raw = '''
Information Management
3-4 pm MTh
TECH302
4-5 pm MTh
''';
    final classes = parser.parse(raw);
    expect(classes, hasLength(2));
    expect(
      classes.map((item) => item.subject),
      everyElement('Information Management'),
    );
    expect(classes.map((item) => item.roomText), everyElement('TECH-302'));
    expect(classes.map((item) => item.startMinutes), everyElement(15 * 60));
    expect(classes.map((item) => item.endMinutes), everyElement(17 * 60));
    expect(
      classes.map((item) => item.days.single),
      containsAll(<ClassDay>[ClassDay.monday, ClassDay.thursday]),
    );
  });

  test('keeps multiple subjects apart', () {
    const raw = '''
CS 101 Mon 9:00 AM - 10:30 AM T-201
ENG 102 Wed 10:30 AM - 12:00 PM A-105
MATH 120 Fri 1:00 PM - 2:30 PM T-202
''';
    final classes = parser.parse(raw);
    expect(classes.length, 3);
    expect(classes.map((item) => item.roomText), ['T-201', 'A-105', 'T-202']);
  });
}
