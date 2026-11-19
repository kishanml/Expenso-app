import '../../data/models/budget_item.dart';

/// Guesses which budget item a transaction belongs to, from the merchant text.
///
/// The guess is only ever a starting point — the review screen shows it as a
/// selected chip the person can change before confirming.
///
/// Matching runs in order of how much it can be trusted:
///
///  1. the person's own budget item names, so a custom "Petrol" item wins
///     over anything built in;
///  2. a keyword table, but only for categories that actually exist in their
///     budget — suggesting "Shopping" to someone with no Shopping item would
///     create a category their budget says nothing about;
///  3. Daily expenses, which is what most small spending is.
abstract final class CategoryMatcher {
  /// Merchant keywords mapped to the category they usually mean. Keys are
  /// matched case-insensitively as substrings.
  static const _keywords = <String, String>{
    // Food and everyday spending
    'swiggy': kDailyExpensesName,
    'zomato': kDailyExpensesName,
    'zepto': kDailyExpensesName,
    'blinkit': kDailyExpensesName,
    'bigbasket': kDailyExpensesName,
    'dunzo': kDailyExpensesName,
    'instamart': kDailyExpensesName,
    'cafe': kDailyExpensesName,
    'coffee': kDailyExpensesName,
    'restaurant': kDailyExpensesName,
    'kitchen': kDailyExpensesName,
    'bakery': kDailyExpensesName,
    'hotel': kDailyExpensesName,
    'dmart': kDailyExpensesName,
    'grocer': kDailyExpensesName,
    'supermarket': kDailyExpensesName,
    'uber': kDailyExpensesName,
    'ola': kDailyExpensesName,
    'rapido': kDailyExpensesName,
    'metro': kDailyExpensesName,
    'irctc': kDailyExpensesName,
    'petrol': kDailyExpensesName,
    'fuel': kDailyExpensesName,
    'auto': kDailyExpensesName,
    'atm': kDailyExpensesName,

    // Bills and utilities
    'electricity': 'Bills',
    'bescom': 'Bills',
    'water bill': 'Bills',
    'gas': 'Bills',
    'broadband': 'Bills',
    'airtel': 'Bills',
    'jio': 'Bills',
    'vodafone': 'Bills',
    'recharge': 'Bills',
    'bill': 'Bills',
    'dth': 'Bills',
    'insurance': 'Bills',

    // Shopping
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'myntra': 'Shopping',
    'ajio': 'Shopping',
    'nike': 'Shopping',
    'adidas': 'Shopping',
    'decathlon': 'Shopping',
    'store': 'Shopping',
    'mall': 'Shopping',
    'lifestyle': 'Shopping',
    'croma': 'Shopping',
    'reliance digital': 'Shopping',

    // The rest
    'rent': 'Rent',
    'landlord': 'Rent',
    'emi': 'EMI',
    'loan': 'EMI',
    'gym': 'Gym',
    'fitness': 'Gym',
    'cult': 'Gym',
  };

  /// Returns the best category from [categories], which are the names of the
  /// month's budget items. Never returns a name that is not in that list.
  static String match(String? merchant, List<String> categories) {
    if (categories.isEmpty) return kDailyExpensesName;

    final fallback = categories.firstWhere(
      (name) => name == kDailyExpensesName,
      orElse: () => categories.first,
    );

    if (merchant == null) return fallback;
    final text = merchant.toLowerCase();

    // 1. The person's own item names.
    //
    // Longest first, so "Money home" beats "Money" if both exist.
    final byLength = [...categories]
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final name in byLength) {
      if (name.length >= 3 && text.contains(name.toLowerCase())) return name;
    }

    // 2. The keyword table, restricted to categories they actually budget for.
    //
    // Longest keyword first: "reliance digital" should not lose to "gas"
    // simply because it appears later in the table.
    final keys = _keywords.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final keyword in keys) {
      if (!text.contains(keyword)) continue;
      final target = _keywords[keyword]!;
      if (categories.contains(target)) return target;
    }

    return fallback;
  }
}
