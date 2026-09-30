/// How an account is labelled on screen.
///
/// Pure functions (no Firebase), so they can be unit-tested and shared by the
/// Profile page greeting and the avatar on the task list.
library;

/// The name to greet the user with.
///
/// Normally the display name. If it is missing (for example, saving it failed
/// right after sign-up), fall back to the part of the email before the "@".
String nameToShow({String? displayName, String? email}) {
  final name = displayName?.trim() ?? '';
  if (name.isNotEmpty) return name;

  final address = email ?? '';
  final at = address.indexOf('@');
  if (at > 0) return address.substring(0, at);
  return 'there';
}

/// Up to two initials for the avatar: "Juan Dela Cruz" -> "JD", "jp" -> "J".
String initialsOf(String name) {
  final words =
      name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';

  final first = words.first[0];
  final last = words.length > 1 ? words.last[0] : '';
  return (first + last).toUpperCase();
}
