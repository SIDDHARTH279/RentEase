import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentease_app/core/router.dart';

void main() {
  runApp(
    ProviderScope(
        child: RentLedgerApp()
    )
  );
}

class RentLedgerApp extends StatelessWidget {
  const RentLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RentEase',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A3C6E),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
    );
  }
}

