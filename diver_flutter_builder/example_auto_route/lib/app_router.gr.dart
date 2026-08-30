// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [BookDetailsPage]
class BookDetailsRoute extends PageRouteInfo<BookDetailsRouteArgs> {
  BookDetailsRoute({
    Key? key,
    required String id,
    bool preview = false,
    List<PageRouteInfo>? children,
  }) : super(
         BookDetailsRoute.name,
         args: BookDetailsRouteArgs(key: key, id: id, preview: preview),
         rawPathParams: {'id': id},
         initialChildren: children,
       );

  static const String name = 'BookDetailsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<BookDetailsRouteArgs>(
        orElse: () => BookDetailsRouteArgs(id: pathParams.getString('id')),
      );
      return BookDetailsPage(key: args.key, id: args.id, preview: args.preview);
    },
  );
}

class BookDetailsRouteArgs {
  const BookDetailsRouteArgs({
    this.key,
    required this.id,
    this.preview = false,
  });

  final Key? key;

  final String id;

  final bool preview;

  @override
  String toString() {
    return 'BookDetailsRouteArgs{key: $key, id: $id, preview: $preview}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BookDetailsRouteArgs) return false;
    return key == other.key && id == other.id && preview == other.preview;
  }

  @override
  int get hashCode => key.hashCode ^ id.hashCode ^ preview.hashCode;
}

/// generated route for
/// [CheckoutPage]
class CheckoutRoute extends PageRouteInfo<CheckoutRouteArgs> {
  CheckoutRoute({Key? key, required Cart cart, List<PageRouteInfo>? children})
    : super(
        CheckoutRoute.name,
        args: CheckoutRouteArgs(key: key, cart: cart),
        initialChildren: children,
      );

  static const String name = 'CheckoutRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<CheckoutRouteArgs>();
      return CheckoutPage(key: args.key, cart: args.cart);
    },
  );
}

class CheckoutRouteArgs {
  const CheckoutRouteArgs({this.key, required this.cart});

  final Key? key;

  final Cart cart;

  @override
  String toString() {
    return 'CheckoutRouteArgs{key: $key, cart: $cart}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CheckoutRouteArgs) return false;
    return key == other.key && cart == other.cart;
  }

  @override
  int get hashCode => key.hashCode ^ cart.hashCode;
}

/// generated route for
/// [DashboardPage]
class DashboardRoute extends PageRouteInfo<void> {
  const DashboardRoute({List<PageRouteInfo>? children})
    : super(DashboardRoute.name, initialChildren: children);

  static const String name = 'DashboardRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const DashboardPage();
    },
  );
}

/// generated route for
/// [LibraryPage]
class LibraryRoute extends PageRouteInfo<LibraryRouteArgs> {
  LibraryRoute({Key? key, required String shelf, List<PageRouteInfo>? children})
    : super(
        LibraryRoute.name,
        args: LibraryRouteArgs(key: key, shelf: shelf),
        initialChildren: children,
      );

  static const String name = 'LibraryRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LibraryRouteArgs>();
      return LibraryPage(key: args.key, shelf: args.shelf);
    },
  );
}

class LibraryRouteArgs {
  const LibraryRouteArgs({this.key, required this.shelf});

  final Key? key;

  final String shelf;

  @override
  String toString() {
    return 'LibraryRouteArgs{key: $key, shelf: $shelf}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LibraryRouteArgs) return false;
    return key == other.key && shelf == other.shelf;
  }

  @override
  int get hashCode => key.hashCode ^ shelf.hashCode;
}

/// generated route for
/// [PrivacyPage]
class PrivacyRoute extends PageRouteInfo<void> {
  const PrivacyRoute({List<PageRouteInfo>? children})
    : super(PrivacyRoute.name, initialChildren: children);

  static const String name = 'PrivacyRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const PrivacyPage();
    },
  );
}

/// generated route for
/// [ProfilePage]
class ProfileTab extends PageRouteInfo<void> {
  const ProfileTab({List<PageRouteInfo>? children})
    : super(ProfileTab.name, initialChildren: children);

  static const String name = 'ProfileTab';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ProfilePage();
    },
  );
}

/// generated route for
/// [SearchPage]
class SearchRoute extends PageRouteInfo<SearchRouteArgs> {
  SearchRoute({
    Key? key,
    String term = '',
    int page = 1,
    String? category,
    String? sortOrder,
    List<PageRouteInfo>? children,
  }) : super(
         SearchRoute.name,
         args: SearchRouteArgs(
           key: key,
           term: term,
           page: page,
           category: category,
           sortOrder: sortOrder,
         ),
         rawQueryParams: {'q': term, 'page': page},
         initialChildren: children,
       );

  static const String name = 'SearchRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final queryParams = data.queryParams;
      final args = data.argsAs<SearchRouteArgs>(
        orElse: () => SearchRouteArgs(
          term: queryParams.getString('q', ''),
          page: queryParams.getInt('page', 1),
        ),
      );
      return SearchPage(
        key: args.key,
        term: args.term,
        page: args.page,
        category: args.category,
        sortOrder: args.sortOrder,
      );
    },
  );
}

class SearchRouteArgs {
  const SearchRouteArgs({
    this.key,
    this.term = '',
    this.page = 1,
    this.category,
    this.sortOrder,
  });

  final Key? key;

  final String term;

  final int page;

  final String? category;

  final String? sortOrder;

  @override
  String toString() {
    return 'SearchRouteArgs{key: $key, term: $term, page: $page, category: $category, sortOrder: $sortOrder}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SearchRouteArgs) return false;
    return key == other.key &&
        term == other.term &&
        page == other.page &&
        category == other.category &&
        sortOrder == other.sortOrder;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      term.hashCode ^
      page.hashCode ^
      category.hashCode ^
      sortOrder.hashCode;
}

/// generated route for
/// [SettingsPage]
class SettingsRoute extends PageRouteInfo<void> {
  const SettingsRoute({List<PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SettingsPage();
    },
  );
}
