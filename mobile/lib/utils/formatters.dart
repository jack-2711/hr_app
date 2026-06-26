import 'package:intl/intl.dart';

String formatCurrency(num value, {String currency = 'USD'}) {
  final symbol = switch (currency) {
    'EUR' => 'EUR ',
    'GBP' => 'GBP ',
    'INR' => 'INR ',
    _ => r'$',
  };
  return '$symbol${NumberFormat('#,##0.00').format(value)}';
}

String formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  return DateFormat('EEE, MMM d').format(DateTime.parse(iso).toLocal());
}

String formatTime(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  return DateFormat('hh:mm a').format(DateTime.parse(iso).toLocal());
}

String formatHours(num? decimalHours) {
  if (decimalHours == null || decimalHours == 0) return '0h 0m';
  final hours = decimalHours.floor();
  final minutes = ((decimalHours - hours) * 60).round();
  return '${hours}h ${minutes}m';
}
