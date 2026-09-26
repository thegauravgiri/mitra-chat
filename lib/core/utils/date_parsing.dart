import 'package:intl/intl.dart';

class DateParsing {
  DateParsing._();

  /// Formats a DateTime to ISO-8601 date string (YYYY-MM-DD) for Notion/APIs.
  static String toIsoDateString(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Parses date text (e.g. '2026-08-30', 'tomorrow', 'tmrw', 'eod', 'eow', 'next week', 'mon')
  /// against a [reference] time (defaulting to DateTime.now()).
  static DateTime? parseFlexible(String input, {DateTime? reference}) {
    final clean = input.trim().toLowerCase();
    if (clean.isEmpty) return null;

    final ref = reference ?? DateTime.now();

    // Direct ISO / common formatted parse
    final parsed = DateTime.tryParse(input);
    if (parsed != null) return parsed;

    if (clean == 'today' || clean == 'tonight') {
      return DateTime(ref.year, ref.month, ref.day);
    }
    if (clean == 'tomorrow' || clean == 'tmrw' || clean == 'tmr') {
      final next = ref.add(const Duration(days: 1));
      return DateTime(next.year, next.month, next.day);
    }
    if (clean == 'yesterday') {
      final prev = ref.subtract(const Duration(days: 1));
      return DateTime(prev.year, prev.month, prev.day);
    }
    if (clean == 'eow' || clean == 'end of week') {
      // Friday of current week (assuming Monday=1 .. Friday=5)
      final daysUntilFriday = (DateTime.friday - ref.weekday) % 7;
      final target = ref.add(Duration(days: daysUntilFriday));
      return DateTime(target.year, target.month, target.day);
    }
    if (clean == 'next week') {
      final next = ref.add(const Duration(days: 7));
      return DateTime(next.year, next.month, next.day);
    }

    // Weekdays
    const weekdays = {
      'monday': DateTime.monday,
      'mon': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'tue': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'wed': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'thu': DateTime.thursday,
      'friday': DateTime.friday,
      'fri': DateTime.friday,
      'saturday': DateTime.saturday,
      'sat': DateTime.saturday,
      'sunday': DateTime.sunday,
      'sun': DateTime.sunday,
    };

    if (weekdays.containsKey(clean)) {
      final targetDay = weekdays[clean]!;
      var daysToAdd = (targetDay - ref.weekday) % 7;
      if (daysToAdd <= 0) daysToAdd += 7;
      final target = ref.add(Duration(days: daysToAdd));
      return DateTime(target.year, target.month, target.day);
    }

    return null;
  }
}
