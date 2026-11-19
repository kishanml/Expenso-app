import 'package:expenso/core/format/money.dart';
import 'package:expenso/domain/sms/sms_parser.dart';
import 'package:expenso/domain/sms/transaction_sms.dart';
import 'package:flutter_test/flutter_test.dart';

/// The parser decides what lands in someone's ledger, so it is tested from
/// both directions: it must read real messages correctly, and it must refuse
/// everything that is not a completed transaction.
void main() {
  final received = DateTime(2026, 11, 19, 14, 30);

  TransactionSms? parse(String body) =>
      SmsParser.parse(body, receivedAt: received);

  group('UPI debits', () {
    test('HDFC VPA payment', () {
      final sms = parse(
        'Rs.250.00 debited from A/c XX1234 on 10-11-26 to VPA '
        'swiggy@okhdfcbank. Ref 123456789. -HDFC Bank',
      )!;

      expect(Money.rupees(sms.amountPaise), '₹250');
      expect(sms.isCredit, isFalse);
      expect(sms.accountTail, '1234');
      expect(sms.merchant, 'swiggy');
      expect(sms.bank, 'HDFC Bank');
      expect(sms.date, DateTime(2026, 11, 10));
      expect(sms.confidence, ParseConfidence.high);
    });

    test('lower-case bank wording with paise', () {
      final sms = parse(
        'Dear Customer, Rs.70.50 has been debited from account **1234 '
        'to VPA autodriver@ybl on 10-11-26',
      )!;

      expect(sms.amountPaise, 7050);
      expect(Money.rupeesPaise(sms.amountPaise), '₹70.50');
      expect(sms.merchant, 'autodriver');
      expect(sms.isCredit, isFalse);
    });

    test('INR prefix and a comma-grouped amount', () {
      final sms = parse(
        'INR 1,240.00 debited from your A/c no. XXXXXX1234 on 10/11/26 '
        'towards ELECTRICITY BILL. Avl Bal INR 45,000.00',
      )!;

      expect(Money.rupees(sms.amountPaise), '₹1,240');
      expect(sms.merchant, 'ELECTRICITY BILL');
    });

    test('the available balance is never mistaken for the amount', () {
      final sms = parse(
        'Rs 180 debited from A/c XX1234 on 19-11-26. Avl Bal Rs 1,12,739.00',
      )!;
      expect(Money.rupees(sms.amountPaise), '₹180');
    });

    test('card spend at a merchant', () {
      final sms = parse(
        'Rs 1899 spent on your HDFC Bank Credit Card xx1234 at NIKE STORE '
        'on 07-11-26',
      )!;

      expect(Money.rupees(sms.amountPaise), '₹1,899');
      expect(sms.merchant, 'NIKE STORE');
      expect(sms.isCredit, isFalse);
      expect(sms.date, DateTime(2026, 11, 7));
    });

    test('ATM withdrawal', () {
      final sms = parse(
        'Rs.5000 withdrawn from A/c XX5678 at ATM on 18-Nov-26. -SBI',
      )!;

      expect(Money.rupees(sms.amountPaise), '₹5,000');
      expect(sms.isCredit, isFalse);
      expect(sms.date, DateTime(2026, 11, 18));
      expect(sms.bank, 'SBI');
    });
  });

  group('Credits', () {
    test('UPI credit', () {
      final sms = parse(
        'Your A/c XX5678 is credited with Rs 120.00 on 09-11-26 by '
        'UPI/cashback. -ICICI Bank',
      )!;

      expect(sms.isCredit, isTrue);
      expect(Money.rupees(sms.amountPaise), '₹120');
      expect(sms.date, DateTime(2026, 11, 9));
    });

    test('salary credit', () {
      final sms = parse(
        'INR 1,12,739.00 credited to A/c XX1234 on 01-11-26 towards SALARY. '
        '-Axis Bank',
      )!;

      expect(sms.isCredit, isTrue);
      expect(Money.rupees(sms.amountPaise), '₹1,12,739');
      expect(sms.merchant, 'SALARY');
    });

    test('a transfer naming both sides takes this account\'s verb', () {
      // The account that owns this SMS was debited; the credit clause
      // describes the other side.
      final sms = parse(
        'Rs 500 debited from A/c XX1234 and credited to A/c XX9999 '
        'on 19-11-26',
      )!;
      expect(sms.isCredit, isFalse);
    });
  });

  group('Messages that must be refused', () {
    test('an OTP that quotes an amount', () {
      expect(
        parse(
          '123456 is the OTP for a transaction of Rs.5000 on your HDFC card '
          'XX1234. Do not share.',
        ),
        isNull,
      );
    });

    test('a scheduled future debit', () {
      expect(
        parse(
          'Rs.8108.00 will be debited from A/c XX1234 on 25-11-26 '
          'towards your EMI.',
        ),
        isNull,
      );
    });

    test('a payment request', () {
      expect(
        parse('rahul@okaxis has requested Rs.500. Pay now via UPI.'),
        isNull,
      );
    });

    test('a failed payment', () {
      expect(
        parse('Your payment of Rs.250 to swiggy@ybl has failed. -HDFC Bank'),
        isNull,
      );
    });

    test('a balance enquiry with no transaction', () {
      expect(
        parse('Avl Bal in your A/c XX1234 is Rs 1,12,739.00 as on 19-11-26'),
        isNull,
      );
    });

    test('marketing that mentions money', () {
      expect(
        parse('Get Rs 500 cashback on your first order! Apply now. T&C apply.'),
        isNull,
      );
    });

    test('a bill reminder', () {
      expect(
        parse('Your credit card bill of Rs.12,000 is due on 25-11-26.'),
        isNull,
      );
    });

    test('a message with no amount', () {
      expect(parse('Your A/c XX1234 has been debited. -HDFC Bank'), isNull);
    });

    test('a message with no direction', () {
      expect(parse('Rs.250.00 A/c XX1234 on 10-11-26. -HDFC Bank'), isNull);
    });

    test('an ordinary text message', () {
      expect(parse('hey are we still on for dinner tonight'), isNull);
      expect(parse(''), isNull);
    });

    test('a loose promo with a verb but no account or UPI reference', () {
      expect(
        parse('Rs 200 credited to all users this week. Enjoy!'),
        isNull,
      );
    });
  });

  group('Dates', () {
    test('day-first, never month-first', () {
      // 10-11-26 is 10 November, not 11 October.
      expect(
        parse('Rs 100 debited from A/c XX1234 on 10-11-26')!.date,
        DateTime(2026, 11, 10),
      );
    });

    test('four-digit years', () {
      expect(
        parse('Rs 100 debited from A/c XX1234 on 03/12/2026')!.date,
        DateTime(2026, 12, 3),
      );
    });

    test('falls back to the day the message arrived', () {
      final sms = parse('Rs 100 debited from A/c XX1234 via UPI ref 99')!;
      expect(sms.date, DateTime(2026, 11, 19));
    });

    test('an impossible date falls back rather than rolling over', () {
      final sms = parse('Rs 100 debited from A/c XX1234 on 31-02-26')!;
      expect(sms.date, DateTime(2026, 11, 19));
    });
  });

  group('Confidence', () {
    test('an account tail makes it high', () {
      expect(
        parse('Rs 100 debited from A/c XX1234 on 19-11-26')!.confidence,
        ParseConfidence.high,
      );
    });

    test('a UPI reference with no account tail is only medium', () {
      final sms = parse('Rs 100 debited via UPI to shop@ybl ref 4411')!;
      expect(sms.confidence, ParseConfidence.medium);
      expect(sms.accountTail, isNull);
    });
  });

  group('The suggested note', () {
    test('uses the merchant when there is one', () {
      expect(
        parse('Rs 250 debited from A/c XX1234 to VPA swiggy@ybl')!
            .suggestedNote,
        'swiggy',
      );
    });

    test('says something honest when there is not', () {
      final sms = parse('Rs 250 debited from A/c XX1234 on 19-11-26')!;
      expect(sms.merchant, isNull);
      expect(sms.suggestedNote, 'Money out');
    });
  });
}
