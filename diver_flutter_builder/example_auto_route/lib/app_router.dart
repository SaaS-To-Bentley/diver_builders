import 'package:auto_route/auto_route.dart';
// `app_router.gr.dart` is a part of this library, so the types it mentions —
// widget `Key`s and the `Cart` handed to CheckoutPage — must be imported here.
import 'package:flutter/material.dart';

import 'models.dart';
import 'pages.dart';

part 'app_router.gr.dart';

/// The single place every path in this app is declared.
///
/// This is what `diver_flutter_builder` looks for: a class annotated
/// `@AutoRouterConfig()`. It reads the `routes` getter below — the list literal
/// itself, since `AutoRoute` has no const constructor to evaluate — takes the
/// `path:` off each entry, and matches `page: XRoute.page` back to the
/// `@RoutePage()` widget in `pages.dart` that it was generated from.
///
/// `AutoRoute` and its transport-specific variants (`CustomRoute`,
/// `MaterialRoute`, `CupertinoRoute`, `AdaptiveRoute`) all count: they carry the
/// same `path`/`page` pair and differ only in how the page is presented.
@AutoRouterConfig(replaceInRouteName: 'Page|Screen,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        // Not an `AutoRoute`, so the builder ignores it: a redirect maps to
        // another entry rather than to a page of its own.
        RedirectRoute(path: '/', redirectTo: '/dashboard'),

        // Plain route.
        AutoRoute(path: '/dashboard', page: DashboardRoute.page),

        // Query parameters only; `SearchPage` decides what they are called.
        AutoRoute(path: '/search', page: SearchRoute.page),

        // `:id` is claimed by `BookDetailsPage`'s `@PathParam('id')`.
        AutoRoute(path: '/books/:id', page: BookDetailsRoute.page),

        // `:shelf` is claimed by name alone — `LibraryPage` has a `shelf`
        // parameter and no annotation.
        AutoRoute(path: '/library/:shelf', page: LibraryRoute.page),

        // A `CustomRoute` is collected exactly like an `AutoRoute`. The page
        // is matched by its explicit `@RoutePage(name: 'ProfileTab')`.
        CustomRoute<void>(
          path: '/profile',
          page: ProfileTab.page,
          transitionsBuilder: TransitionsBuilders.fadeIn,
        ),

        // Nested routes: `/settings` is collected, but the builder does not
        // descend into `children:` yet, so `/settings/privacy` is not composed
        // into a URL. Each skipped child is logged during the build.
        AutoRoute(
          path: '/settings',
          page: SettingsRoute.page,
          children: [
            AutoRoute(path: 'privacy', page: PrivacyRoute.page),
          ],
        ),

        // Not deeplink-safe — see the comment on `CheckoutPage`.
        AutoRoute(path: '/checkout', page: CheckoutRoute.page),
      ];
}
