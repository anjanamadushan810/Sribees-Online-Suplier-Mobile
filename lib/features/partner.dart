/// Partner mode (plan fulfilment-partner-2026-11-27): a fulfilment partner (first: Nimali
/// Stores for Matugama) packs the Other Products lines of SRIBEES Online customer orders,
/// keeps its own price to Sribees and stock for our product list, sets those products'
/// customer price, takes back goods that come back, and sees its weekly statement.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/state.dart';

// ======================================================================= helpers
String _name(WidgetRef ref, Map<String, dynamic> m) {
  final si = ref.watch(sessionProvider).lang == 'si';
  final base = (si && (m['name_si'] ?? '').toString().isNotEmpty) ? m['name_si'] : m['name'];
  final variant = (m['variant'] ?? '').toString();
  return variant.isEmpty ? '$base' : '$base · $variant';
}

Widget _chip(BuildContext context, String text, {Color? color}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? Theme.of(context).colorScheme.secondaryContainer).withAlpha(60),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: color)),
    );

Widget _retry(WidgetRef ref, Object e, VoidCallback again) => Center(
      child: TextButton(
        onPressed: again,
        child: Text('${errorText(ref, e)}\n${t(ref, 'retry')}', textAlign: TextAlign.center),
      ),
    );

Widget _row(String a, String b, {bool bold = false, Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(child: Text(a)),
        Text(b, style: TextStyle(fontWeight: bold ? FontWeight.bold : null, color: color)),
      ]),
    );

// ======================================================================= orders to pack
class PartnerRequestsScreen extends ConsumerStatefulWidget {
  const PartnerRequestsScreen({super.key});
  @override
  ConsumerState<PartnerRequestsScreen> createState() => _PartnerRequestsState();
}

class _PartnerRequestsState extends ConsumerState<PartnerRequestsScreen> {
  bool openOnly = true;

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(partnerRequestsProvider(openOnly));
    return Scaffold(
      appBar: AppBar(title: Text(t(ref, 'tab_requests')), actions: [
        TextButton(
          onPressed: () => setState(() => openOnly = !openOnly),
          child: Text(t(ref, openOnly ? 'show_all' : 'show_open')),
        ),
      ]),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _retry(ref, e, () => ref.invalidate(partnerRequestsProvider)),
        data: (rows) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(partnerRequestsProvider),
          child: rows.isEmpty
              ? ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(t(ref, 'requests_empty'), textAlign: TextAlign.center),
                  ),
                ])
              : ListView(children: [
                  for (final r in rows.cast<Map<String, dynamic>>())
                    ListTile(
                      leading: Icon(r['status'] == 'new'
                          ? Icons.fiber_new
                          : r['status'] == 'ready'
                              ? Icons.shopping_bag
                              : Icons.shopping_bag_outlined),
                      title: Text('${r['order_number'] ?? r['request_no']}'),
                      subtitle: Text('${r['customer_name'] ?? ''}'
                          '${r['customer_name'] == null ? '' : ' · '}'
                          '${r['units']} ${t(ref, 'units')}'),
                      trailing: _chip(context, t(ref, 'pst_${r['status']}')),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => PartnerRequestScreen(requestId: r['request_id']))),
                    ),
                ]),
        ),
      ),
    );
  }
}

final _requestProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
    (ref, id) => ref.watch(apiProvider).partnerRequest(id));

class PartnerRequestScreen extends ConsumerStatefulWidget {
  const PartnerRequestScreen({super.key, required this.requestId});
  final String requestId;
  @override
  ConsumerState<PartnerRequestScreen> createState() => _PartnerRequestState();
}

class _PartnerRequestState extends ConsumerState<PartnerRequestScreen> {
  bool busy = false;

  Future<void> _ready() async {
    setState(() => busy = true);
    try {
      await ref.read(apiProvider).partnerReady(widget.requestId);
      ref.invalidate(_requestProvider(widget.requestId));
      ref.invalidate(partnerRequestsProvider);
      if (mounted) toast(context, t(ref, 'ready_done'));
    } catch (e) {
      if (mounted) toast(context, errorText(ref, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = ref.watch(_requestProvider(widget.requestId));
    return Scaffold(
      appBar: AppBar(title: Text(t(ref, 'request'))),
      body: req.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _retry(ref, e, () => ref.invalidate(_requestProvider(widget.requestId))),
        data: (r) {
          final lines = (r['lines'] as List).cast<Map<String, dynamic>>();
          final canReady = r['status'] == 'new' || r['status'] == 'seen';
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('${r['order_number'] ?? ''}', style: Theme.of(context).textTheme.headlineSmall),
            Text('${r['request_no']} · ${t(ref, 'pst_${r['status']}')}'),
            const Divider(),
            Text(t(ref, 'customer'), style: Theme.of(context).textTheme.labelLarge),
            SelectableText('${r['customer_name'] ?? '-'}',
                style: Theme.of(context).textTheme.titleMedium),
            if (r['customer_phone'] != null)
              SelectableText('${t(ref, 'phone_label')}: ${r['customer_phone']}'
                  '${r['alternate_phone'] != null ? ' / ${r['alternate_phone']}' : ''}'),
            if (r['delivery_address'] != null)
              SelectableText('${t(ref, 'address')}: ${r['delivery_address']}'),
            if ((r['order_notes'] ?? '').toString().isNotEmpty)
              Text('${t(ref, 'notes')}: ${r['order_notes']}'),
            const Divider(),
            Text(t(ref, 'items_to_pack'), style: Theme.of(context).textTheme.labelLarge),
            for (final l in lines)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text('${l['qty']}')),
                title: Text(_name(ref, l)),
                subtitle: l['price_to_us'] == null
                    ? Text(t(ref, 'price_needed'), style: const TextStyle(color: Colors.orange))
                    : Text('රු. ${money(l['price_to_us'])}'),
              ),
            if (canReady) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: busy ? null : _ready,
                icon: const Icon(Icons.check),
                label: Text(t(ref, 'mark_ready')),
              ),
            ],
          ]);
        },
      ),
    );
  }
}

// ======================================================================= my items
class PartnerItemsScreen extends ConsumerStatefulWidget {
  const PartnerItemsScreen({super.key});
  @override
  ConsumerState<PartnerItemsScreen> createState() => _PartnerItemsState();
}

class _PartnerItemsState extends ConsumerState<PartnerItemsScreen> {
  final search = TextEditingController();
  final List<Map<String, dynamic>> items = [];
  int total = 0;
  bool loading = false;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final page = await ref
          .read(apiProvider)
          .partnerItems(q: search.text, offset: reset ? 0 : items.length);
      setState(() {
        if (reset) items.clear();
        items.addAll((page['items'] as List).cast<Map<String, dynamic>>());
        total = page['total'] as int;
      });
    } catch (e) {
      setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const BarcodeScanPage()));
    if (code != null && code.isNotEmpty) {
      search.text = code;
      _load(reset: true);
    }
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ItemEditor(item: item),
    );
    if (changed == true) _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t(ref, 'tab_items'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                    labelText: t(ref, 'search_items'), prefixIcon: const Icon(Icons.search)),
                onSubmitted: (_) => _load(reset: true),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(t(ref, 'scan_barcode')),
              ),
            ),
          ]),
        ),
        if (error != null)
          Expanded(child: _retry(ref, error!, () => _load(reset: true)))
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: items.isEmpty && !loading
                  ? ListView(children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(t(ref, 'items_empty'), textAlign: TextAlign.center),
                      ),
                    ])
                  : ListView.builder(
                      itemCount: items.length + 1,
                      itemBuilder: (_, i) {
                        if (i == items.length) {
                          if (loading) {
                            return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()));
                          }
                          return items.length < total
                              ? TextButton(
                                  onPressed: () => _load(), child: Text(t(ref, 'load_more')))
                              : const SizedBox(height: 24);
                        }
                        return _ItemTile(item: items[i], onTap: () => _edit(items[i]));
                      },
                    ),
            ),
          ),
      ]),
    );
  }
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({required this.item, required this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missing = item['price_missing'] == true;
    final loss = item['loss'] == true;
    return ListTile(
      onTap: onTap,
      leading: item['image_url'] != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network('${item['image_url']}',
                  width: 48, height: 48, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported_outlined)))
          : const Icon(Icons.inventory_2_outlined),
      title: Text(_name(ref, item)),
      subtitle: Wrap(spacing: 6, runSpacing: 2, children: [
        Text(missing
            ? t(ref, 'price_needed')
            : '${t(ref, 'price_to_us')}: ${money(item['price_to_us'])}',
            style: TextStyle(color: missing ? Colors.orange.shade800 : null)),
        Text('${t(ref, 'stock')}: ${item['stock_qty']}'),
        if (item['customer_price'] != null)
          Text('${t(ref, 'customer_price')}: ${money(item['customer_price'])}',
              style: TextStyle(color: loss ? Colors.red : null)),
        if (loss) _chip(context, t(ref, 'loss_warning'), color: Colors.red),
        if (item['backup_only'] == true) _chip(context, t(ref, 'backup_only')),
      ]),
      trailing: const Icon(Icons.edit_outlined),
    );
  }
}

class _ItemEditor extends ConsumerStatefulWidget {
  const _ItemEditor({required this.item});
  final Map<String, dynamic> item;
  @override
  ConsumerState<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends ConsumerState<_ItemEditor> {
  final _form = GlobalKey<FormState>();
  late final price = TextEditingController(text: '${widget.item['price_to_us'] ?? ''}');
  late final stock = TextEditingController(text: '${widget.item['stock_qty'] ?? 0}');
  late final customer = TextEditingController(text: '${widget.item['customer_price'] ?? ''}');
  bool busy = false;

  @override
  void dispose() {
    price.dispose();
    stock.dispose();
    customer.dispose();
    super.dispose();
  }

  String? _stockField(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return t(ref, 'required');
    final n = int.tryParse(s);
    return (n == null || n < 0) ? t(ref, 'must_be_positive') : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final api = ref.read(apiProvider);
    final item = widget.item;
    final newPrice = price.text.trim();
    final newStock = int.parse(stock.text.trim());
    final priceChanged = newPrice != '${item['price_to_us'] ?? ''}';
    final stockChanged = newStock != item['stock_qty'];
    final newCustomer = customer.text.trim();
    final customerChanged = item['backup_only'] != true &&
        newCustomer.isNotEmpty && newCustomer != '${item['customer_price'] ?? ''}';
    setState(() => busy = true);
    try {
      if (priceChanged || stockChanged) {
        await api.partnerSetItem(item['branch_id'], item['online_variant_id'],
            priceToUs: priceChanged ? newPrice : null, stock: stockChanged ? newStock : null);
      }
      if (customerChanged) {
        final r = await api.partnerSetCustomerPrice(
            item['branch_id'], item['online_variant_id'], newCustomer);
        if (mounted) {
          toast(context, r['below_price_to_us'] == true
              ? t(ref, 'loss_warning')
              : t(ref, 'customer_price_saved'));
        }
      } else if (mounted) {
        toast(context, t(ref, 'saved'));
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) toast(context, errorText(ref, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backup = widget.item['backup_only'] == true;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          Text(_name(ref, widget.item), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextFormField(
            controller: price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: t(ref, 'price_to_us')),
            validator: (v) => moneyField(v, ref: ref),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: stock,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: t(ref, 'stock')),
            validator: _stockField,
          ),
          if (!backup) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: customer,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: t(ref, 'customer_price')),
              validator: (v) => moneyField(v, ref: ref, optional: true),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: busy ? null : _save, child: Text(t(ref, 'update'))),
        ]),
      ),
    );
  }
}

/// Reads one product barcode (EAN / UPC) and returns it.
class BarcodeScanPage extends ConsumerStatefulWidget {
  const BarcodeScanPage({super.key});
  @override
  ConsumerState<BarcodeScanPage> createState() => _BarcodeScanPageState();
}

class _BarcodeScanPageState extends ConsumerState<BarcodeScanPage> {
  final _controller = MobileScannerController(formats: const [
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
    BarcodeFormat.code128,
  ]);
  bool done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t(ref, 'scan_barcode'))),
        body: MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
            if (done || raw == null || raw.isEmpty) return;
            done = true;
            Navigator.of(context).pop(raw);
          },
        ),
      );
}

// ======================================================================= returns
class PartnerReturnsScreen extends ConsumerStatefulWidget {
  const PartnerReturnsScreen({super.key});
  @override
  ConsumerState<PartnerReturnsScreen> createState() => _PartnerReturnsState();
}

class _PartnerReturnsState extends ConsumerState<PartnerReturnsScreen> {
  bool openOnly = true;
  String? busyId;

  Future<void> _accept(String id) async {
    setState(() => busyId = id);
    try {
      await ref.read(apiProvider).partnerAcceptReturn(id);
      ref.invalidate(partnerReturnsProvider);
    } catch (e) {
      if (mounted) toast(context, errorText(ref, e));
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(partnerReturnsProvider(openOnly));
    return Scaffold(
      appBar: AppBar(title: Text(t(ref, 'tab_returns')), actions: [
        TextButton(
          onPressed: () => setState(() => openOnly = !openOnly),
          child: Text(t(ref, openOnly ? 'show_all' : 'show_open')),
        ),
      ]),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _retry(ref, e, () => ref.invalidate(partnerReturnsProvider)),
        data: (rows) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(partnerReturnsProvider),
          child: rows.isEmpty
              ? ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(t(ref, 'returns_empty'), textAlign: TextAlign.center),
                  ),
                ])
              : ListView(padding: const EdgeInsets.all(8), children: [
                  for (final r in rows.cast<Map<String, dynamic>>())
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(
                              child: Text('${r['order_number'] ?? r['request_no']}',
                                  style: Theme.of(context).textTheme.titleMedium),
                            ),
                            _chip(context, t(ref, 'rst_${r['status']}')),
                          ]),
                          Text('${r['return_no']} · ${t(ref, 'why_${r['reason']}')}'),
                          if (r['customer_name'] != null) Text('${r['customer_name']}'),
                          const SizedBox(height: 4),
                          for (final l in (r['lines'] as List).cast<Map<String, dynamic>>())
                            Text('• ${l['qty']} × ${_name(ref, {...l, 'name': l['name'] ?? ''})}'),
                          if (r['credit_total'] != null)
                            _row(t(ref, 'credit'), 'රු. ${money(r['credit_total'])}'),
                          if (r['status'] == 'sent') ...[
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: busyId == null ? () => _accept(r['return_id']) : null,
                              icon: const Icon(Icons.assignment_turned_in_outlined),
                              label: Text(t(ref, 'accept_return')),
                            ),
                          ],
                        ]),
                      ),
                    ),
                ]),
        ),
      ),
    );
  }
}

// ======================================================================= weekly statement
class PartnerStatementScreen extends ConsumerWidget {
  const PartnerStatementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeks = ref.watch(partnerWeeksProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t(ref, 'tab_statement'))),
      body: weeks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _retry(ref, e, () => ref.invalidate(partnerWeeksProvider)),
        data: (data) {
          final rows = ((data['weeks'] ?? []) as List).cast<Map<String, dynamic>>();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(partnerWeeksProvider),
            child: ListView(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(t(ref, 'paid_by_owner')),
              ),
              for (final w in rows)
                ListTile(
                  title: Text('${w['week_start']} – ${w['week_end']}'),
                  subtitle: Text(w['closed'] == true
                      ? (w['changed_since_confirmed'] == true
                          ? t(ref, 'changed_since')
                          : w['confirmed_at'] != null
                              ? t(ref, 'confirmed')
                              : '')
                      : t(ref, 'week_open')),
                  trailing: Text('රු. ${money(w['to_pay'])}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PartnerWeekScreen(week: '${w['week_start']}'))),
                ),
            ]),
          );
        },
      ),
    );
  }
}

final _weekProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
    (ref, week) => ref.watch(apiProvider).partnerStatements(week: week));

class PartnerWeekScreen extends ConsumerStatefulWidget {
  const PartnerWeekScreen({super.key, required this.week});
  final String week;
  @override
  ConsumerState<PartnerWeekScreen> createState() => _PartnerWeekState();
}

class _PartnerWeekState extends ConsumerState<PartnerWeekScreen> {
  bool busy = false;

  Future<void> _confirm() async {
    setState(() => busy = true);
    try {
      await ref.read(apiProvider).partnerConfirmWeek(widget.week);
      ref.invalidate(_weekProvider(widget.week));
      ref.invalidate(partnerWeeksProvider);
      if (mounted) toast(context, t(ref, 'confirmed'));
    } catch (e) {
      if (mounted) toast(context, errorText(ref, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final week = ref.watch(_weekProvider(widget.week));
    return Scaffold(
      appBar: AppBar(title: Text('${t(ref, 'week')} ${widget.week}')),
      body: week.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _retry(ref, e, () => ref.invalidate(_weekProvider(widget.week))),
        data: (s) {
          final days = (s['days'] as List).cast<Map<String, dynamic>>();
          final rets = (s['returns'] as List).cast<Map<String, dynamic>>();
          final canConfirm = s['closed'] == true &&
              (s['confirmed_at'] == null || s['changed_since_confirmed'] == true);
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('${s['week_start']} – ${s['week_end']}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(t(ref, 'day_orders'), style: Theme.of(context).textTheme.labelLarge),
            for (final d in days)
              _row('${d['date']} · ${d['order_no']}', 'රු. ${money(d['total'])}'),
            if (rets.isNotEmpty) ...[
              const Divider(),
              Text(t(ref, 'returns_total'), style: Theme.of(context).textTheme.labelLarge),
              for (final r in rets)
                _row('${r['date']} · ${r['return_no']}', '- රු. ${money(r['total'])}'),
            ],
            const Divider(),
            _row(t(ref, 'purchases'), 'රු. ${money(s['purchases'])}'),
            _row(t(ref, 'returns_total'), '- රු. ${money(s['returns_total'])}'),
            _row(t(ref, 'to_pay'), 'රු. ${money(s['to_pay'])}', bold: true),
            const SizedBox(height: 8),
            if (s['changed_since_confirmed'] == true)
              Text(t(ref, 'changed_since'), style: const TextStyle(color: Colors.orange)),
            if (s['closed'] != true) Text(t(ref, 'week_open')),
            if (canConfirm) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy ? null : _confirm,
                icon: const Icon(Icons.verified_outlined),
                label: Text(t(ref, 'confirm_week')),
              ),
            ] else if (s['confirmed_at'] != null)
              Text('${t(ref, 'confirmed')} ✓'),
            const SizedBox(height: 8),
            Text(t(ref, 'paid_by_owner'), style: Theme.of(context).textTheme.bodySmall),
          ]);
        },
      ),
    );
  }
}
