import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/state.dart';
import 'features/catalog.dart';
import 'features/login.dart';
import 'features/orders.dart';
import 'features/settings.dart';

void main() => runApp(const ProviderScope(child: SupplierApp()));

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
              ? const HomeScreen()
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
  Widget build(BuildContext context) {
    const pages = [CatalogScreen(), OrdersScreen(), SettingsScreen()];
    return Scaffold(
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.sell_outlined), label: t(ref, 'tab_prices')),
          NavigationDestination(
              icon: const Icon(Icons.local_shipping_outlined), label: t(ref, 'tab_orders')),
          NavigationDestination(
              icon: const Icon(Icons.settings_outlined), label: t(ref, 'tab_settings')),
        ],
      ),
    );
  }
}
