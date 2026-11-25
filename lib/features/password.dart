import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/state.dart';

/// Change the password: forced after a temporary password, or from Settings.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key, this.forced = false});
  final bool forced;
  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final current = TextEditingController();
  final next = TextEditingController();
  final again = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (next.text.length < 8) {
      setState(() => error = t(ref, 'password_short'));
      return;
    }
    if (next.text != again.text) {
      setState(() => error = t(ref, 'passwords_differ'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(apiProvider).changePassword(current.text, next.text);
      ref.read(sessionProvider.notifier).passwordChanged();
      if (mounted) {
        toast(context, t(ref, 'password_changed'));
        if (!widget.forced) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => error = errorText(ref, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forced,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t(ref, 'change_password')),
          automaticallyImplyLeading: !widget.forced,
          actions: [
            if (widget.forced)
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        await ref.read(apiProvider).logout();
                        ref.read(sessionProvider.notifier).signedOut();
                      },
                child: Text(t(ref, 'logout')),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (widget.forced) ...[
              Text(t(ref, 'set_new_password_first')),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: current,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                  labelText: t(ref, widget.forced ? 'temporary_password' : 'current_password')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: next,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                  labelText: t(ref, 'new_password'), helperText: t(ref, 'password_rule')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: again,
              obscureText: true,
              decoration: InputDecoration(labelText: t(ref, 'repeat_password')),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : _save,
              child: Text(t(ref, 'save')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Forgot password: an SMS code goes to the phone registered for the email.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.email = ''});
  final String email;
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final TextEditingController email = TextEditingController(text: widget.email);
  final code = TextEditingController();
  final next = TextEditingController();
  bool sent = false, busy = false;
  int wait = 0;
  Timer? timer;
  String? error;

  @override
  void dispose() {
    timer?.cancel();
    email.dispose();
    code.dispose();
    next.dispose();
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
      await ref.read(apiProvider).forgotPassword(email.text.trim());
      setState(() => sent = true);
      _countdown();
    } catch (e) {
      setState(() => error = errorText(ref, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _reset() async {
    if (next.text.length < 8) {
      setState(() => error = t(ref, 'password_short'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(apiProvider).resetPassword(email.text.trim(), code.text.trim(), next.text);
      if (mounted) {
        toast(context, t(ref, 'password_reset_done'));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => error = errorText(ref, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t(ref, 'forgot_password'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: email,
            enabled: !sent,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: t(ref, 'email')),
          ),
          if (sent) ...[
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
            TextField(
              controller: next,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: t(ref, 'new_password'), helperText: t(ref, 'password_rule')),
            ),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : (sent ? _reset : _send),
            child: Text(t(ref, sent ? 'save' : 'send_code')),
          ),
          if (sent)
            TextButton(
              onPressed: busy || wait > 0 ? null : _send,
              child: Text(wait > 0 ? '${t(ref, 'resend')} ($wait)' : t(ref, 'resend')),
            ),
        ],
      ),
    );
  }
}
