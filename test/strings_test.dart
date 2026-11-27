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

  test('partner statuses and return reasons have text in both languages', () {
    // the backend's values (fulfilment_requests.status, partner_returns.status / reason)
    for (final s in ['new', 'seen', 'ready', 'handed', 'cancelled']) {
      expect(si.containsKey('pst_$s') && en.containsKey('pst_$s'), isTrue, reason: s);
    }
    for (final s in ['waiting', 'sent', 'accepted']) {
      expect(si.containsKey('rst_$s'), isTrue, reason: s);
    }
    for (final s in ['cancelled', 'rto', 'undelivered', 'returned']) {
      expect(si.containsKey('why_$s'), isTrue, reason: s);
    }
  });

  test('money format', () {
    expect(money('125.00'), '125.00');
    expect(money('37500'), '37,500.00');
    expect(money(null), '-');
  });
}
