import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'api.dart';
import 'strings.dart';

class Session {
  const Session(
      {this.ready = false, this.signedIn = false, this.lang = 'si', this.mustChange = false});
  final bool ready;
  final bool signedIn;
  final String lang;

  /// Signed in with a temporary password: the app asks for a new one before anything else.
  final bool mustChange;
  Session copy({bool? ready, bool? signedIn, String? lang, bool? mustChange}) => Session(
      ready: ready ?? this.ready,
      signedIn: signedIn ?? this.signedIn,
      lang: lang ?? this.lang,
      mustChange: mustChange ?? this.mustChange);
}

class SessionNotifier extends StateNotifier<Session> {
  SessionNotifier(this.tokens) : super(const Session()) {
    _load();
  }
  final TokenStore tokens;

  Future<void> _load() async {
    final lang = await tokens.language();
    final refresh = await tokens.refresh();
    state = Session(ready: true, signedIn: refresh != null, lang: lang);
  }

  void signedIn({bool mustChange = false}) =>
      state = state.copy(signedIn: true, mustChange: mustChange);
  void signedOut() => state = state.copy(signedIn: false, mustChange: false);
  void requireChange() => state = state.copy(mustChange: true);
  void passwordChanged() => state = state.copy(mustChange: false);
  Future<void> setLanguage(String lang) async {
    await tokens.setLanguage(lang);
    state = state.copy(lang: lang);
  }
}

final tokenStoreProvider = Provider((_) => TokenStore());
final sessionProvider = StateNotifierProvider<SessionNotifier, Session>(
    (ref) => SessionNotifier(ref.watch(tokenStoreProvider)));
final apiProvider = Provider((ref) => Api(ref.watch(tokenStoreProvider),
    onSignedOut: () => ref.read(sessionProvider.notifier).signedOut()));

final catalogProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
    (ref) => ref.watch(apiProvider).catalog());
final ordersProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) => ref.watch(apiProvider).orders());
final meProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) => ref.watch(apiProvider).me());

/// Text in the user's language: `t(ref, 'save')`.
String t(WidgetRef ref, String key) => tr(ref.watch(sessionProvider).lang, key);

/// Server messages come in English; our own keys are translated.
String errorText(WidgetRef ref, Object e) {
  final msg = e is ApiError ? e.message : 'error';
  return (si.containsKey(msg)) ? t(ref, msg) : msg;
}

final _money = NumberFormat('#,##0.00', 'en_US');
String money(dynamic v) => v == null ? '-' : _money.format(num.parse('$v'));

void toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// "125", "24.50" -> valid; empty -> null when optional.
String? moneyField(String? v, {required WidgetRef ref, bool optional = false}) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return optional ? null : t(ref, 'required');
  final n = num.tryParse(s);
  if (n == null || n <= 0 || !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(s)) {
    return t(ref, 'must_be_positive');
  }
  return null;
}

String? countField(String? v, {required WidgetRef ref, bool optional = false}) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return optional ? null : t(ref, 'required');
  final n = int.tryParse(s);
  if (n == null || n <= 0) return t(ref, 'must_be_positive');
  return null;
}
