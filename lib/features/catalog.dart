import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../core/state.dart';
import 'import_list.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    try {
      final text = await ref.read(apiProvider).message();
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (e) {
      if (context.mounted) toast(context, errorText(ref, e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(t(ref, 'tab_prices')),
        actions: [
          IconButton(
            tooltip: t(ref, 'import'),
            icon: const Icon(Icons.content_paste_go),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ImportScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _share(context, ref),
        icon: const Icon(Icons.share),
        label: Text(t(ref, 'share_whatsapp')),
      ),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Retry(message: errorText(ref, e), onRetry: () => ref.invalidate(catalogProvider)),
        data: (c) {
          final sections = (c['sections'] as List).cast<Map<String, dynamic>>();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(catalogProvider),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                if (sections.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(t(ref, 'empty_catalog'), textAlign: TextAlign.center),
                  ),
                for (final s in sections) _SectionTile(section: s),
                ListTile(
                  leading: const Icon(Icons.create_new_folder_outlined),
                  title: Text(t(ref, 'add_section')),
                  onTap: () => _addSection(context, ref),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addSection(BuildContext context, WidgetRef ref) async {
    final name = await _askText(context, ref, t(ref, 'add_section'), t(ref, 'section_name'));
    if (name == null) return;
    try {
      await ref.read(apiProvider).addSection(name);
      ref.invalidate(catalogProvider);
    } catch (e) {
      if (context.mounted) toast(context, errorText(ref, e));
    }
  }
}

Future<String?> _askText(BuildContext context, WidgetRef ref, String title, String label) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true, decoration: InputDecoration(labelText: label)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t(ref, 'cancel'))),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, c.text.trim().isEmpty ? null : c.text.trim()),
          child: Text(t(ref, 'save')),
        ),
      ],
    ),
  );
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Icon(Icons.refresh)),
        ]),
      );
}

class _SectionTile extends ConsumerWidget {
  const _SectionTile({required this.section});
  final Map<String, dynamic> section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = (section['products'] as List).cast<Map<String, dynamic>>();
    return ExpansionTile(
      title: Text(section['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${products.length}'),
      children: [
        for (final p in products) _ProductTile(product: p),
        ListTile(
          leading: const Icon(Icons.add),
          title: Text(t(ref, 'add_product')),
          onTap: () async {
            final name =
                await _askText(context, ref, t(ref, 'add_product'), t(ref, 'product_name'));
            if (name == null) return;
            try {
              final p = await ref.read(apiProvider).addProduct(section['section_id'], name);
              if (context.mounted) {
                await showOfferSheet(context, ref, productId: p['product_id']);
              }
              ref.invalidate(catalogProvider);
            } catch (e) {
              if (context.mounted) toast(context, errorText(ref, e));
            }
          },
        ),
      ],
    );
  }
}

class _ProductTile extends ConsumerWidget {
  const _ProductTile({required this.product});
  final Map<String, dynamic> product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = product['is_active'] == true;
    final offers = (product['offers'] as List).cast<Map<String, dynamic>>();
    final faded = active ? null : Theme.of(context).disabledColor;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(product['heading'],
                    style: TextStyle(fontWeight: FontWeight.w600, color: faded)),
              ),
              Switch(
                value: active,
                onChanged: (v) async {
                  try {
                    await ref.read(apiProvider).updateProduct(product['product_id'], {'is_active': v});
                    ref.invalidate(catalogProvider);
                  } catch (e) {
                    if (context.mounted) toast(context, errorText(ref, e));
                  }
                },
              ),
            ]),
            for (final o in offers)
              InkWell(
                onTap: () => showOfferSheet(context, ref,
                    productId: product['product_id'], offer: o),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        '${money(o['price'])} / ${money(o['mrp'])}'
                        '   (${o['units_per_box'] ?? '?'})  ${o['label']}',
                        style: TextStyle(
                          color: o['is_active'] == true && active ? null : Theme.of(context).disabledColor,
                          decoration: o['is_active'] == true ? null : TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                    const Icon(Icons.edit, size: 18),
                    const SizedBox(width: 12),
                  ]),
                ),
              ),
            TextButton.icon(
              onPressed: () => showOfferSheet(context, ref, productId: product['product_id']),
              icon: const Icon(Icons.add, size: 18),
              label: Text(t(ref, 'add_price')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add a price line, or edit one (price, MRP, units per box, note, for sale or not).
Future<void> showOfferSheet(BuildContext context, WidgetRef ref,
    {required String productId, Map<String, dynamic>? offer}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _OfferForm(productId: productId, offer: offer),
    ),
  );
}

class _OfferForm extends ConsumerStatefulWidget {
  const _OfferForm({required this.productId, this.offer});
  final String productId;
  final Map<String, dynamic>? offer;
  @override
  ConsumerState<_OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends ConsumerState<_OfferForm> {
  final form = GlobalKey<FormState>();
  late final price = TextEditingController(text: _plain(widget.offer?['price']));
  late final mrp = TextEditingController(text: _plain(widget.offer?['mrp']));
  late final units = TextEditingController(text: '${widget.offer?['units_per_box'] ?? ''}');
  late final label = TextEditingController(text: widget.offer?['label'] ?? '');
  late bool active = widget.offer?['is_active'] ?? true;
  bool busy = false;

  static String _plain(dynamic v) {
    if (v == null) return '';
    final s = '$v';
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    final body = {
      'price': price.text.trim(),
      'mrp': mrp.text.trim().isEmpty ? null : mrp.text.trim(),
      'units_per_box': units.text.trim().isEmpty ? null : int.parse(units.text.trim()),
      'label': label.text.trim(),
    };
    try {
      final api = ref.read(apiProvider);
      if (widget.offer == null) {
        await api.addOffer(widget.productId, body);
      } else {
        await api.updateOffer(widget.offer!['offer_id'], {...body, 'is_active': active});
      }
      ref.invalidate(catalogProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, errorText(ref, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return SafeArea(
      child: Form(
        key: form,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: t(ref, 'our_price')),
              validator: (v) => moneyField(v, ref: ref),
            ),
            gap,
            TextFormField(
              controller: mrp,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: t(ref, 'mrp')),
              validator: (v) => moneyField(v, ref: ref, optional: true),
            ),
            gap,
            TextFormField(
              controller: units,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: t(ref, 'units_per_box')),
              validator: (v) => countField(v, ref: ref, optional: true),
            ),
            gap,
            TextFormField(controller: label, decoration: InputDecoration(labelText: t(ref, 'label'))),
            if (widget.offer != null)
              SwitchListTile(
                value: active,
                onChanged: (v) => setState(() => active = v),
                title: Text(t(ref, active ? 'active' : 'inactive')),
              ),
            gap,
            FilledButton(onPressed: busy ? null : _save, child: Text(t(ref, 'save'))),
            if (widget.offer != null)
              TextButton.icon(
                icon: const Icon(Icons.history),
                label: Text(t(ref, 'history')),
                onPressed: () => _history(context),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _history(BuildContext context) async {
    try {
      final rows = await ref.read(apiProvider).history(widget.offer!['offer_id']);
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t(ref, 'history')),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(shrinkWrap: true, children: [
              for (final h in rows)
                ListTile(
                  dense: true,
                  title: Text('${money(h['price'])} / ${money(h['mrp'])}  (${h['units_per_box'] ?? '?'})'),
                  subtitle: Text('${h['changed_at']}'.substring(0, 16).replaceFirst('T', ' ')),
                ),
            ]),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) toast(context, errorText(ref, e));
    }
  }
}
