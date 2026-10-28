// Rules for the widget tests themselves (docs/agent/MISTAKES.md), checked over test/.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every widget test scrolls through scrollTo() or scrollToFinder() in support.dart (rule 27)', () {
    // Escaped, so this file doesn't match itself.
    final direct = RegExp(r'\.scrollUntilVisible\(');
    final offenders = [
      for (final f in Directory('test').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') && !f.path.endsWith('support.dart') && direct.hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty, reason: 'scrollUntilVisible ends without a frame; the helpers pump around it');
  });
}
