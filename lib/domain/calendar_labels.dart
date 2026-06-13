const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// 3-letter month abbreviation for [month] (1 = Jan .. 12 = Dec).
String monthAbbr3(int month) => _months[month - 1];

/// 3-letter weekday abbreviation for [weekday] (1 = Mon .. 7 = Sun, matching
/// `DateTime.weekday`).
String weekdayAbbr3(int weekday) => _weekdays[weekday - 1];
