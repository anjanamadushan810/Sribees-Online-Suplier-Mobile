import 'package:flutter_test/flutter_test.dart';
import 'package:sribees_supplier/core/state.dart';
import 'package:sribees_supplier/core/strings.dart';

void main() {
  test('every text exists in Sinhala and English', () {
    expect(si.keys.toSet(), en.keys.toSet());
    for (final v in [...si.values, ...en.values]) {
      expect(v.trim(), isNotEmpty);
    }
  });

  test('order statuses have text in both languages', () {
    for (final s in ['approved', 'accepted', 'declined', 'cancelled', 'received']) {
      expect(si.containsKey('status_$s'), isTrue);
    }
  });

  test('money format', () {
    expect(money('125.00'), '125.00');
    expect(money('37500'), '37,500.00');
    expect(money(null), '-');
  });
}
