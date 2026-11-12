import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/state.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t(ref, 'tab_orders'))),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(ordersProvider),
            child: Text('${errorText(ref, e)}\n${t(ref, 'retry')}', textAlign: TextAlign.center),
          ),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(ordersProvider),
          child: list.isEmpty
              ? ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(t(ref, 'orders_empty'), textAlign: TextAlign.center),
                  ),
                ])
              : ListView(children: [
                  for (final o in list.cast<Map<String, dynamic>>())
                    ListTile(
                      leading: Icon(o['status'] == 'approved'
                          ? Icons.fiber_new
                          : Icons.receipt_long_outlined),
                      title: Text('${o['order_no']} · ${o['branch_name']}'),
                      subtitle: Text(t(ref, 'status_${o['status']}')),
                      trailing: Text('රු. ${money(o['total'])}'),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => OrderScreen(orderId: o['order_id']))),
                    ),
                ]),
        ),
      ),
    );
  }
}

final _orderProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
    (ref, id) => ref.watch(apiProvider).order(id));

class OrderScreen extends ConsumerWidget {
  const OrderScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(_orderProvider(orderId));
    return Scaffold(
      appBar: AppBar(title: Text(t(ref, 'order'))),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(errorText(ref, e))),
        data: (o) {
          final lines = (o['lines'] as List).cast<Map<String, dynamic>>();
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('${o['order_no']}', style: Theme.of(context).textTheme.headlineSmall),
            Text('${t(ref, 'branch')}: ${o['branch_name']}'),
            Text(t(ref, 'status_${o['status']}')),
            if (o['cancel_reason'] != null) Text('${o['cancel_reason']}'),
            const Divider(),
            for (final l in lines)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${l['heading']} ${l['label']}'),
                subtitle: Text('${l['boxes']} ${t(ref, 'boxes')} × ${l['units_per_box']}'
                    ' = ${l['units']} ${t(ref, 'units')} × ${money(l['unit_price'])}'),
                trailing: Text(money(l['line_total'])),
              ),
            const Divider(),
            _row(t(ref, 'goods_total'), money(o['goods_total'])),
            if (o['delivery_charge'] != null)
              _row(t(ref, 'delivery_charge'), money(o['delivery_charge'])),
            _row(t(ref, 'total'), money(o['total']), bold: true),
            if (o['status'] == 'approved') ...[
              const SizedBox(height: 16),
              _AnswerButtons(orderId: orderId),
            ],
          ]);
        },
      ),
    );
  }

  Widget _row(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(a)),
          Text(b, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
        ]),
      );
}

class _AnswerButtons extends ConsumerStatefulWidget {
  const _AnswerButtons({required this.orderId});
  final String orderId;
  @override
  ConsumerState<_AnswerButtons> createState() => _AnswerButtonsState();
}

class _AnswerButtonsState extends ConsumerState<_AnswerButtons> {
  final delivery = TextEditingController();
  final note = TextEditingController();
  bool busy = false;

  Future<void> _answer(bool accept) async {
    if (accept && moneyField(delivery.text, ref: ref, optional: true) != null &&
        delivery.text.trim() != '0') {
      toast(context, t(ref, 'must_be_positive'));
      return;
    }
    setState(() => busy = true);
    try {
      await ref.read(apiProvider).answer(widget.orderId,
          accept: accept, delivery: delivery.text.trim(), note: note.text.trim());
      ref.invalidate(_orderProvider(widget.orderId));
      ref.invalidate(ordersProvider);
    } catch (e) {
      if (mounted) toast(context, errorText(ref, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: delivery,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: t(ref, 'delivery_charge')),
          ),
          const SizedBox(height: 8),
          TextField(controller: note, decoration: InputDecoration(labelText: t(ref, 'note'))),
          const SizedBox(height: 12),
          FilledButton(onPressed: busy ? null : () => _answer(true), child: Text(t(ref, 'accept'))),
          OutlinedButton(
              onPressed: busy ? null : () => _answer(false), child: Text(t(ref, 'decline'))),
        ],
      );
}
