import 'package:auto_route/auto_route.dart';
import 'package:diver_flutter_annotation/diver_flutter_annotation.dart';
import 'package:flutter/material.dart';

import 'message_page.dart';
import 'models.dart';

/// The routable pages of this example — ordinary widgets marked `@RoutePage()`.
///
/// Unlike go_router, an auto_route page carries no path of its own: paths live
/// centrally on the `AutoRoute(...)` entries in `app_router.dart`. What a page
/// *does* decide is how its constructor parameters are filled, and that is what
/// `diver_flutter_builder` reads to build each route's `query` list.
///
/// A parameter's role is resolved the way auto_route itself resolves it at
/// runtime: an explicit `@PathParam`/`@QueryParam` annotation wins, and with no
/// annotation the parameter's own name is matched against a `:segment` in the
/// path. Anything left over is a query parameter.

/// Plain page, no parameters.
///   -> { host: "dashboard", path: "", query: [] }
///
/// Also the simplest case of page matching: there is no `@RoutePage(name: ...)`
/// here, so the builder strips the `Page` suffix from `DashboardPage` and the
/// `Route` suffix from `DashboardRoute.page` in the router and compares what is
/// left. (`super.key` is a widget's own parameter, never a URL value, so it is
/// left out of `query`.)
@RoutePage()
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) => const MessagePage('Dashboard');
}

/// Query parameters of every flavour, plus `@DiverRoute` metadata that becomes
/// the `name`/`description` in the output.
///
/// `@QueryParam('q')` renames the parameter on the wire; an unannotated
/// parameter keeps its own name, kebab-cased. Every entry below comes out
/// `required: false`, and always will: auto_route_generator rejects a query
/// parameter that is neither nullable nor defaulted ("QueryParams must be
/// nullable or have default value"), so a query parameter the caller *must*
/// supply cannot exist in a compiling auto_route app.
///   -> query: [
///        { name: "q",          required: false },  // @QueryParam('q'), renamed
///        { name: "page",       required: false },  // @QueryParam(), has a default
///        { name: "category",   required: false },  // unannotated, nullable
///        { name: "sort-order", required: false },  // unannotated, kebab-cased
///      ]
@DiverRoute(
  name: 'Product search',
  description: 'Full-text product search with optional paging and filtering.',
)
@RoutePage()
class SearchPage extends StatelessWidget {
  const SearchPage({
    super.key,
    @QueryParam('q') this.term = '',
    @QueryParam() this.page = 1,
    this.category,
    this.sortOrder,
  });

  final String term;
  final int page;
  final String? category;
  final String? sortOrder;

  @override
  Widget build(BuildContext context) =>
      MessagePage('Search "$term" (page $page)');
}

/// Explicit `@PathParam('id')`, matching the `:id` segment the router gives
/// this page. A path parameter is part of the URL itself and is never emitted
/// as a query parameter.
///   -> { host: "books", path: ":id", query: [ { name: "preview", type: "boolean", required: false } ] }
@RoutePage()
class BookDetailsPage extends StatelessWidget {
  const BookDetailsPage({
    super.key,
    @PathParam('id') required this.id,
    this.preview = false,
  });

  final String id;
  final bool preview;

  @override
  Widget build(BuildContext context) => MessagePage('Book $id');
}

/// The same idea without any annotation: `shelf` is required, but it matches
/// the `:shelf` segment of the route's path by name, so it is claimed as a path
/// parameter rather than blocking the route.
///   -> { host: "library", path: ":shelf", query: [] }
@RoutePage()
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key, required this.shelf});

  final String shelf;

  @override
  Widget build(BuildContext context) => MessagePage('Shelf $shelf');
}

/// An explicit `@RoutePage(name: ...)`. The router refers to this page as
/// `ProfileTab.page`, which the builder matches by that exact name instead of
/// falling back to comparing suffix-stripped class names.
///   -> { host: "profile", path: "", query: [] }
@RoutePage(name: 'ProfileTab')
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => const MessagePage('Profile');
}

/// Parent of a nested route. Only its own path is collected — see the
/// `children:` note in `app_router.dart`.
///   -> { host: "settings", path: "", query: [] }
@RoutePage()
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => const AutoRouter();
}

/// A child route's page. Nested paths are not composed by the builder yet, so
/// this page contributes nothing to `app_urls.json`.
@RoutePage()
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) => const MessagePage('Privacy');
}

/// A required parameter that nothing claims as a URL value: it carries no
/// `@PathParam`/`@QueryParam` annotation, and `/checkout` has no `:cart`
/// segment to match its name against. auto_route is happy to pass the `Cart`
/// when navigating in-app, but a URL cannot carry it and the page cannot be
/// built without it, so the route is NOT deeplink-safe: it is left out of
/// `app_urls.json` and recorded in `diver/app_urls_errors.json` with the
/// reason. Making it nullable, giving it a default, or annotating it would
/// bring the route back.
@RoutePage()
class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key, required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context) =>
      MessagePage('Checkout (${cart.itemCount} items)');
}
