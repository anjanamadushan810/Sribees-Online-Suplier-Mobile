import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push.dart';
import 'core/state.dart';
import 'features/catalog.dart';
import 'features/login.dart';
import 'features/orders.dart';
import 'features/partner.dart';
import 'features/password.dart';
import 'features/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Push.start();
  runApp(const ProviderScope(child: SupplierApp()));
}

class SupplierApp extends ConsumerWidget {
  const SupplierApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    return MaterialApp(
      title: t(ref, 'app_title'),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFF5A300),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: !s.ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : s.signedIn
              ? (s.mustChange ? const ChangePasswordScreen(forced: true) : const HomeScreen())
              : const LoginScreen(),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    // Signed in: make sure this phone gets new-order alerts (asks permission once).
    Push.register(ref.read(apiProvider));
    // A temporary password from an earlier sign-in still has to be replaced.
    ref.read(apiProvider).me().then((m) {
      if (m['must_change_password'] == true && mounted) {
        ref.read(sessionProvider.notifier).requireChange();
      }
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    // A fulfilment partner packs customer orders (plan fulfilment-partner-2026-11-27);
    // every other supplier keeps its price list and our orders.
    final partner = ref.watch(isPartnerProvider).valueOrNull;
    if (partner == null && ref.watch(isPartnerProvider).isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final List<Widget> pages;
    final List<NavigationDestination> destinations;
    if (partner == true) {
      pages = const [PartnerRequestsScreen(), PartnerItemsScreen(), PartnerReturnsScreen(),
                     PartnerStatementScreen(), SettingsScreen()];
      destinations = [
        NavigationDestination(
            icon: const Icon(Icons.shopping_bag_outlined), label: t(ref, 'tab_requests')),
        NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined), label: t(ref, 'tab_items')),
        NavigationDestination(
            icon: const Icon(Icons.assignment_return_outlined), label: t(ref, 'tab_returns')),
        NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined), label: t(ref, 'tab_statement')),
        NavigationDestination(
            icon: const Icon(Icons.settings_outlined), label: t(ref, 'tab_settings')),
      ];
    } else {
      pages = const [CatalogScreen(), OrdersScreen(), SettingsScreen()];
      destinations = [
        NavigationDestination(
            icon: const Icon(Icons.sell_outlined), label: t(ref, 'tab_prices')),
        NavigationDestination(
            icon: const Icon(Icons.local_shipping_outlined), label: t(ref, 'tab_orders')),
        NavigationDestination(
            icon: const Icon(Icons.settings_outlined), label: t(ref, 'tab_settings')),
      ];
    }
    final index = tab < pages.length ? tab : 0;
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: destinations,
      ),
    );
  }
}
