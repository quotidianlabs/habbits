import 'package:flutter_test/flutter_test.dart';
import 'package:habbits/domain/calendar_labels.dart';

void main() {
  test('monthAbbr3 maps 1..12 to Jan..Dec', () {
    expect(monthAbbr3(1), 'Jan');
    expect(monthAbbr3(6), 'Jun');
    expect(monthAbbr3(12), 'Dec');
  });

  test('weekdayAbbr3 maps 1..7 to Mon..Sun (DateTime.weekday)', () {
    expect(weekdayAbbr3(1), 'Mon');
    expect(weekdayAbbr3(6), 'Sat');
    expect(weekdayAbbr3(7), 'Sun');
  });
}
