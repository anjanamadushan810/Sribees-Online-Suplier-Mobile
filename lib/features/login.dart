import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final phone = TextEditingController();
  final code = TextEditingController();
  bool codeStep = false, busy = false;
  int wait = 0;
  Timer? timer;
  String? error;

  @override
  void dispose() {
    timer?.cancel();
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  void _countdown() {
    wait = 60;
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (tm) {
      if (!mounted) return tm.cancel();
      setState(() => wait = wait > 0 ? wait - 1 : 0);
      if (wait == 0) tm.cancel();
    });
  }

  Future<void> _send() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(apiProvider).requestCode(phone.text.trim());
      setState(() => codeStep = true);
      _countdown();
    } catch (e) {
      setState(() => error = errorText(ref, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(apiProvider).verify(phone.text.trim(), code.text.trim());
      ref.read(sessionProvider.notifier).signedIn();
    } catch (e) {
      if (mounted) setState(() => error = errorText(ref, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(sessionProvider).lang;
    return Scaffold(
      appBar: AppBar(
        title: Text(t(ref, 'app_title')),
        actions: [
          TextButton(
            onPressed: () => ref
                .read(sessionProvider.notifier)
                .setLanguage(lang == 'si' ? 'en' : 'si'),
            child: Text(lang == 'si' ? 'English' : 'සිංහල'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.storefront, size: 72),
          const SizedBox(height: 24),
          TextField(
            controller: phone,
            enabled: !codeStep,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
            decoration: InputDecoration(
                labelText: t(ref, 'phone'), hintText: t(ref, 'phone_hint')),
          ),
          if (codeStep) ...[
            const SizedBox(height: 12),
            Text(t(ref, 'code_sent')),
            const SizedBox(height: 12),
            TextField(
              controller: code,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration:
                  InputDecoration(labelText: t(ref, 'code'), hintText: t(ref, 'code_hint')),
            ),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : (codeStep ? _verify : _send),
            child: Text(t(ref, codeStep ? 'sign_in' : 'send_code')),
          ),
          if (codeStep)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                            codeStep = false;
                            code.clear();
                          }),
                  child: Text(t(ref, 'change_number')),
                ),
                TextButton(
                  onPressed: busy || wait > 0 ? null : _send,
                  child: Text(wait > 0 ? '${t(ref, 'resend')} ($wait)' : t(ref, 'resend')),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
