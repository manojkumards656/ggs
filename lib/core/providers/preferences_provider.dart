import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final usernameProvider = NotifierProvider<UsernameNotifier, String>(() {
  return UsernameNotifier();
});

class UsernameNotifier extends Notifier<String> {
  static const _key = 'username';

  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(_key) ?? '';
  }

  Future<void> setUsername(String name) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, name);
    state = name;
  }
}
