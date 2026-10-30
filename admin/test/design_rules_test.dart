import 'package:flutter_test/flutter_test.dart';

import '../../app/test/design_rules.dart';

// The ui-design skill's rules over the 管理后台's code (tech plan S24 WP24.2): colours from the theme's tokens, sizes
// from the scales. The rules themselves are tested in the app's grid_test.

void main() {
  test('every page of the 管理后台 keeps the design rules: colours, sizes, gaps and corners from the system', () {
    final found = designViolations('lib');
    expect(found, isEmpty, reason: '\n${found.join('\n')}');
  });
}
