import 'package:expenso/data/models/budget_item.dart';
import 'package:expenso/domain/sms/category_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const full = [
    kDailyExpensesName,
    'Rent',
    'Money home',
    'EMI',
    'Shopping',
    'Bills',
    'Gym',
  ];

  group('Keyword matching', () {
    test('food and transport land in Daily expenses', () {
      for (final merchant in ['swiggy', 'ZOMATO', 'Uber India', 'BLINKIT']) {
        expect(CategoryMatcher.match(merchant, full), kDailyExpensesName,
            reason: merchant);
      }
    });

    test('utilities land in Bills', () {
      for (final merchant in ['ELECTRICITY BILL', 'Airtel Recharge']) {
        expect(CategoryMatcher.match(merchant, full), 'Bills',
            reason: merchant);
      }
    });

    test('retailers land in Shopping', () {
      for (final merchant in ['AMAZON.IN', 'NIKE STORE', 'Myntra']) {
        expect(CategoryMatcher.match(merchant, full), 'Shopping',
            reason: merchant);
      }
    });

    test('the long keyword wins over a short one inside it', () {
      // "reliance digital" contains "gas" nowhere, but it does contain
      // "store"-like noise; the longest matching key should decide.
      expect(CategoryMatcher.match('RELIANCE DIGITAL', full), 'Shopping');
    });
  });

  group('The budget comes first', () {
    test("a person's own item name beats the keyword table", () {
      const withPetrol = [kDailyExpensesName, 'Petrol', 'Bills'];
      // "petrol" is a Daily-expenses keyword, but they budget for it by name.
      expect(CategoryMatcher.match('HP PETROL PUMP', withPetrol), 'Petrol');
    });

    test('longer item names win over shorter ones', () {
      const names = [kDailyExpensesName, 'Money', 'Money home'];
      expect(CategoryMatcher.match('money home transfer', names),
          'Money home');
    });
  });

  group('Never inventing a category', () {
    test('a keyword for a category they do not budget for is ignored', () {
      const bare = [kDailyExpensesName, 'Rent'];
      // "nike" means Shopping, which is not in this budget.
      expect(CategoryMatcher.match('NIKE STORE', bare), kDailyExpensesName);
    });

    test('an unknown merchant falls back to Daily expenses', () {
      expect(CategoryMatcher.match('QWERTYUIOP', full), kDailyExpensesName);
    });

    test('no merchant falls back too', () {
      expect(CategoryMatcher.match(null, full), kDailyExpensesName);
    });

    test('a budget with no Daily expenses falls back to its first item', () {
      expect(CategoryMatcher.match('whatever', const ['Rent', 'EMI']), 'Rent');
    });

    test('an empty budget still returns something usable', () {
      expect(CategoryMatcher.match('swiggy', const []), kDailyExpensesName);
    });
  });
}
