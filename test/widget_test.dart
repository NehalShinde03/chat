import 'package:flutter_test/flutter_test.dart';
import 'package:chat/core/constants/app_strings.dart';
import 'package:chat/core/utils/date_formatter.dart';

void main() {
  test('DateFormatter formats time and headers correctly', () {
    final now = DateTime.now();
    expect(DateFormatter.formatDateGroupHeader(now), equals('Today'));
  });

  test('AppStrings constants are valid', () {
    expect(AppStrings.appName, equals('WhatsApp'));
  });
}
