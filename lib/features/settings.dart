import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/state.dart';

const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0+1');

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(sessionProvider).lang;
    final me = ref.watch(meProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t(ref, 'tab_settings'))),
      body: ListView(children: [
        me.maybeWhen(
          data: (m) => ListTile(
            leading: const Icon(Icons.storefront),
            title: Text('${m['supplier_name']}'),
            subtitle: Text('${m['full_name']} · ${m['phone']}'),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(t(ref, 'language')),
          trailing: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'si', label: Text('සිංහල')),
              ButtonSegment(value: 'en', label: Text('English')),
            ],
            selected: {lang},
            onSelectionChanged: (s) => ref.read(sessionProvider.notifier).setLanguage(s.first),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.edit_note),
          title: Text('${t(ref, 'message_header')} / ${t(ref, 'message_footer')}'),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const TemplateScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(t(ref, 'logout')),
          onTap: () async {
            await ref.read(apiProvider).logout();
            ref.read(sessionProvider.notifier).signedOut();
          },
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(t(ref, 'version')),
          trailing: const Text(appVersion),
        ),
      ]),
    );
  }
}

class TemplateScreen extends ConsumerStatefulWidget {
  const TemplateScreen({super.key});
  @override
  ConsumerState<TemplateScreen> createState() => _TemplateScreenState();
}

class _TemplateScreenState extends ConsumerState<TemplateScreen> {
  final header = TextEditingController();
  final footer = TextEditingController();
  bool loaded = false, busy = false;

  @override
  Widget build(BuildContext context) {
    final cat = ref.watch(catalogProvider);
    if (!loaded && cat.hasValue) {
      header.text = cat.value!['header'] ?? '';
      footer.text = cat.value!['footer'] ?? '';
      loaded = true;
    }
    return Scaffold(
      appBar: AppBar(title: Text(t(ref, 'message_header'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
            controller: header,
            minLines: 4,
            maxLines: 12,
            decoration: InputDecoration(labelText: t(ref, 'message_header'))),
        const SizedBox(height: 12),
        TextField(
            controller: footer,
            minLines: 4,
            maxLines: 12,
            decoration: InputDecoration(labelText: t(ref, 'message_footer'))),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() => busy = true);
                  try {
                    await ref.read(apiProvider).setTemplate(header.text, footer.text);
                    ref.invalidate(catalogProvider);
                    if (context.mounted) {
                      toast(context, t(ref, 'saved'));
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (context.mounted) toast(context, errorText(ref, e));
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(t(ref, 'save')),
        ),
      ]),
    );
  }
}
