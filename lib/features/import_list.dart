import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/state.dart';

/// Paste the WhatsApp list -> check (preview) -> answer flagged lines -> import.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});
  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _Answer {
  _Answer(Map<String, dynamic> f)
      : price = TextEditingController(text: '${f['price']}'),
        mrp = TextEditingController(text: f['mrp'] == null ? '' : '${f['mrp']}'),
        units = TextEditingController(text: '${f['units_per_box'] ?? ''}');
  final TextEditingController price, mrp, units;
  bool skip = false;
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final text = TextEditingController();
  Map<String, dynamic>? preview;
  final answers = <int, _Answer>{};
  bool busy = false;

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) setState(() => text.text = data!.text!);
  }

  Future<void> _check() async {
    setState(() => busy = true);
    try {
      final p = await ref.read(apiProvider).preview(text.text);
      answers.clear();
      for (final f in (p['flagged'] as List).cast<Map<String, dynamic>>()) {
        answers[f['line_no'] as int] = _Answer(f);
      }
      setState(() => preview = p);
    } catch (e) {
      if (mounted) toast(context, errorText(ref, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _import() async {
    final body = <Map<String, dynamic>>[];
    for (final e in answers.entries) {
      final a = e.value;
      if (a.skip) {
        body.add({'line_no': e.key, 'skip': true});
        continue;
      }
      if (moneyField(a.price.text, ref: ref) != null ||
          moneyField(a.mrp.text, ref: ref, optional: true) != null ||
          countField(a.units.text, ref: ref) != null) {
        toast(context, '${t(ref, 'line')} ${e.key}: ${t(ref, 'must_be_positive')}');
        return;
      }
      body.add({
        'line_no': e.key,
        'price': a.price.text.trim(),
        if (a.mrp.text.trim().isNotEmpty) 'mrp': a.mrp.text.trim(),
        'units_per_box': int.parse(a.units.text.trim()),
      });
    }
    setState(() => busy = true);
    try {
      await ref.read(apiProvider).import(text.text, body);
      ref.invalidate(catalogProvider);
      if (mounted) {
        toast(context, t(ref, 'imported'));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) toast(context, errorText(ref, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = preview;
    return Scaffold(
      appBar: AppBar(title: Text(t(ref, 'import'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: text,
            minLines: 6,
            maxLines: 12,
            onChanged: (_) => setState(() => preview = null),
            decoration: InputDecoration(
              hintText: t(ref, 'paste_here'),
              suffixIcon: IconButton(icon: const Icon(Icons.content_paste), onPressed: _paste),
            ),
          ),
          const SizedBox(height: 12),
          if (p == null)
            FilledButton(
              onPressed: busy || text.text.trim().isEmpty ? null : _check,
              child: Text(t(ref, 'check')),
            ),
          if (p != null) ...[
            _count(t(ref, 'new_items'), p['new_products']),
            _count(t(ref, 'new_prices'), p['new_offers']),
            _count(t(ref, 'changed_prices'), (p['changed_offers'] as List).length),
            _count(t(ref, 'same_prices'), p['same_offers']),
            for (final c in (p['changed_offers'] as List).cast<Map<String, dynamic>>())
              ListTile(
                dense: true,
                title: Text('${c['heading']} ${c['label']}'),
                trailing: Text('${money(c['old_price'])} → ${money(c['new_price'])}'),
              ),
            if (answers.isNotEmpty) ...[
              const Divider(),
              Text('${t(ref, 'needs_check')}: ${answers.length}',
                  style: Theme.of(context).textTheme.titleMedium),
              for (final f in (p['flagged'] as List).cast<Map<String, dynamic>>())
                _FlagCard(flag: f, answer: answers[f['line_no']]!, onChanged: () => setState(() {})),
            ],
            const SizedBox(height: 12),
            FilledButton(onPressed: busy ? null : _import, child: Text(t(ref, 'import_now'))),
          ],
        ],
      ),
    );
  }

  Widget _count(String label, Object? n) =>
      ListTile(dense: true, title: Text(label), trailing: Text('$n'));
}

class _FlagCard extends ConsumerWidget {
  const _FlagCard({required this.flag, required this.answer, required this.onChanged});
  final Map<String, dynamic> flag;
  final _Answer answer;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget field(TextEditingController c, String key) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextField(
              controller: c,
              enabled: !answer.skip,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: t(ref, key), isDense: true),
            ),
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${t(ref, 'line')} ${flag['line_no']}: ${flag['heading']}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(flag['raw'], style: const TextStyle(fontFamily: 'monospace')),
          const SizedBox(height: 8),
          Row(children: [
            field(answer.price, 'our_price'),
            field(answer.mrp, 'mrp'),
            field(answer.units, 'units_per_box'),
          ]),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: answer.skip,
            onChanged: (v) {
              answer.skip = v ?? false;
              onChanged();
            },
            title: Text(t(ref, 'skip_line')),
          ),
        ]),
      ),
    );
  }
}
