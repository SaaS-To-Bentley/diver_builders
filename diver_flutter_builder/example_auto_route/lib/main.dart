import 'package:flutter/material.dart';

import 'app_router.dart';

void main() => runApp(ExampleApp());

class ExampleApp extends StatelessWidget {
  ExampleApp({super.key});

  // `AppRouter` is generated wiring from the @AutoRouterConfig class in
  // app_router.dart; build it once, outside of build().
  final _appRouter = AppRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'diver_flutter_builder auto_route example',
      routerConfig: _appRouter.config(),
    );
  }
}
