import 'package:expenso/core/format/money.dart';
import 'package:expenso/domain/amount_input.dart';
import 'package:flutter_test/flutter_test.dart';

/// The keypad rules are the ones `AddEntry.dc.html`'s `press()` implements.
void main() {
  AmountInput type(String keys) {
    var input = const AmountInput();
    for (final key in keys.split('')) {
      input = input.press(key);
    }
    return input;
  }

  group('Typing', () {
    test('starts empty and shows zero', () {
      const input = AmountInput();
      expect(input.display, '0');
      expect(input.paise, 0);
      expect(input.isValid, isFalse);
    });

    test('builds up an amount', () {
      expect(type('250').display, '250');
      expect(type('250').paise, 25000);
      expect(type('250').isValid, isTrue);
    });

    test('groups Indian-style as it grows', () {
      expect(type('112739').display, '1,12,739');
    });

    test('replaces a leading zero rather than appending to it', () {
      expect(type('05').display, '5');
    });
  });

  group('Decimal point', () {
    test('is accepted once only', () {
      expect(type('33.3.3').display, '33.33');
    });

    test('inserts a leading zero when typed first', () {
      expect(type('.5').display, '0.5');
      expect(type('.50').paise, 50); // ₹0.50
    });

    test('caps at two places', () {
      expect(type('333.333').display, '333.33');
      expect(type('333.33').paise, 33333);
    });

    test('a trailing point survives, so the field does not fight the user', () {
      expect(type('333.').display, '333.');
      expect(type('333.').paise, 33300);
    });
  });

  group('Limits', () {
    test('stops at nine digits', () {
      expect(type('1234567890').display, Money.groupDigits('123456789'));
    });

    test('the decimal point does not count toward the nine', () {
      expect(type('1234567.89').display, '12,34,567.89');
    });
  });

  group('Backspace', () {
    test('removes the last character', () {
      expect(type('250').press('del').display, '25');
    });

    test('on an empty amount does nothing', () {
      expect(const AmountInput().press('del').display, '0');
    });

    test('clears back to invalid', () {
      var input = type('25');
      input = input.press('del').press('del');
      expect(input.isValid, isFalse);
      expect(input.display, '0');
    });
  });

  group('Large amounts', () {
    test('₹10 lakh exactly does not need confirmation', () {
      expect(type('1000000').needsConfirmation, isFalse);
    });

    test('above ₹10 lakh does', () {
      expect(type('1000001').needsConfirmation, isTrue);
      expect(type('1000001').display, '10,00,001');
    });
  });

  group('Seeding from a stored entry', () {
    test('whole rupees carry no decimal', () {
      expect(AmountInput.fromPaise(25000).display, '250');
    });

    test('paise are restored', () {
      expect(AmountInput.fromPaise(33333).display, '333.33');
      expect(AmountInput.fromPaise(33305).display, '333.05');
    });

    test('round-trips through the keypad', () {
      final seeded = AmountInput.fromPaise(189900);
      expect(seeded.paise, 189900);
      expect(seeded.press('del').paise, 18900); // ₹1,899 -> ₹189
    });
  });
}
