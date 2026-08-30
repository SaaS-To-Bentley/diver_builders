import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';

/// Builder that scans every Dart library in the consuming package for
/// deeplink-safe routes — [go_router](https://pub.dev/packages/go_router)
/// classes carrying a `@TypedGoRoute(...)` annotation, and
/// [auto_route](https://pub.dev/packages/auto_route) routes declared on an
/// `@AutoRouterConfig()` router's `routes` list — and writes a JSON
/// description of each to `diver/app_urls.json`, sorted alphabetically by path.
/// A package is expected to use one framework or the other, but both are
/// scanned unconditionally: whichever is present is picked up, and a package
/// using neither simply produces an empty route list.
///
/// Routes that need a runtime object a URL cannot carry are excluded from
/// `app_urls.json`, and instead written to `diver/app_urls_errors.json`
/// together with a description of why:
///
/// * **go_router** — a route whose class has a *required* `$extra`
///   constructor parameter. `$extra` is go_router's one deliberate escape
///   hatch for passing an object that isn't representable as a URL; every
///   other constructor parameter is assumed routable.
/// * **auto_route** — a route whose page has a *required* constructor
///   parameter that is neither matched by name to a `:segment` in its path
///   nor claimed by an explicit `@PathParam`/`@QueryParam` annotation.
///   auto_route has no single named escape hatch like `$extra`: any
///   constructor parameter can be used to pass a runtime object when
///   navigating in-app, so the signal that a parameter is *not* meant to
///   come from a URL is the absence of anything claiming it as one.
///
/// A parameter that is optional — nullable, or carrying a default value —
/// does not exclude its route in either case: the route can still be opened
/// from a URL, where that parameter simply arrives as `null` or its default.
class UrlAggregatorBuilder implements Builder {
  UrlAggregatorBuilder({this.keepGenerated = false});

  /// When false (the default), the generated `diver/app_urls.json` is deleted
  /// from the source tree after the build. Set to true via the
  /// `keep_generated` option in `build.yaml` to retain the file (e.g. for
  /// inspection or for the `upload_urls` executable to consume).
  final bool keepGenerated;

  static const _outputAsset = 'diver/app_urls.json';
  static const _outputExtension = 'diver/app_urls.json';
  static const _errorAsset = 'diver/app_urls_errors.json';
  static const _errorExtension = 'diver/app_urls_errors.json';
  static const _typedGoRouteName = 'TypedGoRoute';
  static const _diverRouteName = 'DiverRoute';
  static const _extraParamName = r'$extra';

  // auto_route.
  static const _autoRouterConfigName = 'AutoRouterConfig';
  static const _routePageName = 'RoutePage';
  static const _pathParamAnnotationName = 'PathParam';
  static const _queryParamAnnotationName = 'QueryParam';
  static const _routesGetterName = 'routes';
  // Every `@RoutePage()` page is a widget, so its constructor almost always
  // carries a `Key? key` (usually as `super.key`). It belongs to the Flutter
  // element tree, never to a URL.
  static const _widgetKeyParamName = 'key';
  static const _widgetKeyTypeName = 'Key';
  // AutoRoute itself, plus the transport-specific variants that carry the
  // same `path`/`page` shape (each just picks a different page transition).
  static const _autoRouteClassNames = {
    'AutoRoute',
    'CustomRoute',
    'AdaptiveRoute',
    'CupertinoRoute',
    'MaterialRoute',
  };
  // Stripped (case-insensitively) from both a `@RoutePage()` class's own name
  // and the identifier in `page: XRoute.page` before comparing the two, so a
  // route entry can be matched back to its page without having to replicate
  // auto_route_generator's own (configurable) `replaceInRouteName` pattern.
  static const _routeIdentifierSuffixes = ['Route', 'Page', 'Screen', 'View'];

  static final _pathParamPattern = RegExp(r':([a-zA-Z_]\w*)');
  static final _camelBoundary1 = RegExp(r'([a-z0-9])([A-Z])');
  static final _camelBoundary2 = RegExp(r'([A-Z]+)([A-Z][a-z])');
  static const _jsonEncoder = JsonEncoder.withIndent('  ');

  @override
  Map<String, List<String>> get buildExtensions => const {
        r'$package$': [_outputExtension, _errorExtension],
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    final routes = <_Route>[];
    final excluded = <_ExcludedRoute>[];
    final seenPaths = <String>{};

    // auto_route routes are collected in two passes: a router's `routes`
    // getter can reference a `@RoutePage()` page declared in a file this
    // builder hasn't scanned yet, so entries are parsed into an unresolved
    // form during the main scan and only matched up to their page class once
    // every library has been visited.
    final routePageClasses = <_RoutePageClass>[];
    final autoRouteEntries = <_AutoRouteEntry>[];

    await for (final input in buildStep.findAssets(Glob('lib/**.dart'))) {
      if (!await buildStep.resolver.isLibrary(input)) continue;
      final library = await buildStep.resolver.libraryFor(input);
      final reader = LibraryReader(library);

      for (final classElement in reader.classes) {
        _collectGoRoute(classElement, routes, excluded, seenPaths);

        final routePageName = _readRoutePageName(classElement);
        if (routePageName != null) {
          routePageClasses.add(_RoutePageClass(
            classElement: classElement,
            explicitName: routePageName.isNotEmpty ? routePageName : null,
          ));
        }

        if (_hasAnnotation(classElement, _autoRouterConfigName)) {
          autoRouteEntries.addAll(
            await _collectAutoRouteEntries(classElement, buildStep),
          );
        }
      }
    }

    for (final entry in autoRouteEntries) {
      _resolveAutoRoute(entry, routePageClasses, routes, excluded, seenPaths);
    }

    routes.sort((a, b) {
      final byHost = a.host.compareTo(b.host);
      return byHost != 0 ? byHost : a.path.compareTo(b.path);
    });
    final body = _jsonEncoder.convert({
      'routes': routes.map((r) => r.toJson()).toList(),
    });

    await buildStep.writeAsString(
      AssetId(buildStep.inputId.package, _outputAsset),
      '$body\n',
    );

    // Routes that depend on a runtime object are not deeplink-safe. Surface
    // them in a dedicated error file so they are not lost. The file is
    // written only when there is something to report; build_runner removes a
    // previously generated one automatically once every route is
    // deeplink-safe again.
    if (excluded.isNotEmpty) {
      excluded.sort((a, b) => a.route.compareTo(b.route));
      final errorBody = _jsonEncoder.convert({
        'errors': excluded.map((e) => e.toJson()).toList(),
      });
      await buildStep.writeAsString(
        AssetId(buildStep.inputId.package, _errorAsset),
        '$errorBody\n',
      );
    }

    if (!keepGenerated) {
      final file = File(_outputAsset);
      if (await file.exists()) {
        await file.delete();
        log.info('Deleted $_outputAsset (keep_generated=false).');
      }
    }
  }

  // ---------------------------------------------------------------------
  // go_router
  // ---------------------------------------------------------------------

  void _collectGoRoute(
    ClassElement classElement,
    List<_Route> routes,
    List<_ExcludedRoute> excluded,
    Set<String> seenPaths,
  ) {
    final path = _readTypedGoRoutePath(classElement);
    if (path == null) return;
    if (!path.startsWith('/')) {
      log.fine('${classElement.name} skipped: relative route ("$path").');
      return;
    }
    final extra = _extraParameter(classElement);
    if (extra != null && !_isOptionalParameter(extra)) {
      final routeName = classElement.name ?? '<unknown>';
      final extraType = extra.type.getDisplayString();
      excluded.add(_ExcludedRoute(
        route: routeName,
        path: path,
        payload: extraType,
        reason: _goRouterErrorReason(extraType),
      ));
      log.warning(
        '$routeName excluded from deeplinks: requires a non-nullable '
        '\$extra parameter ($extraType) with no default value. '
        'See $_errorAsset.',
      );
      return;
    }
    if (!seenPaths.add(path)) return;
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      log.fine('${classElement.name} skipped: empty host ("$path").');
      return;
    }
    final host = segments.first;
    final remainder = segments.skip(1).join('/');
    final diverRoute = _readDiverRoute(classElement);
    final fallbackName = remainder.isEmpty ? host : '$host/$remainder';
    final name =
        (diverRoute?.name.isNotEmpty ?? false) ? diverRoute!.name : fallbackName;
    routes.add(_Route(
      host: host,
      path: remainder,
      query: _goRouterQueryParams(classElement, path),
      name: name,
      description: diverRoute?.description ?? '',
    ));
  }

  String _goRouterErrorReason(String extraType) =>
      'Route requires a non-nullable \$extra constructor parameter ($extraType) '
      'with no default value. \$extra carries a runtime Dart object that cannot '
      'be encoded in a URL, and the route cannot be constructed without it, so '
      'it cannot be reached by a deeplink. Make \$extra nullable or give it a '
      'default value to allow URL navigation without the payload.';

  String? _readTypedGoRoutePath(Element element) {
    for (final annotation in element.metadata.annotations) {
      final annotationElement = annotation.element;
      final enclosingName =
          annotationElement?.enclosingElement?.name ?? annotationElement?.name;
      if (enclosingName != _typedGoRouteName) continue;

      final value = annotation.computeConstantValue();
      final path = value?.getField('path')?.toStringValue();
      if (path != null) return path;
    }
    return null;
  }

  ({String name, String description})? _readDiverRoute(Element element) {
    for (final annotation in element.metadata.annotations) {
      final annotationElement = annotation.element;
      final enclosingName =
          annotationElement?.enclosingElement?.name ?? annotationElement?.name;
      if (enclosingName != _diverRouteName) continue;

      final value = annotation.computeConstantValue();
      final name = value?.getField('name')?.toStringValue();
      final description = value?.getField('description')?.toStringValue();
      if (name == null || description == null) continue;
      return (name: name, description: description);
    }
    return null;
  }

  /// Returns the `$extra` constructor parameter if any constructor of
  /// [element] declares one, or `null` when none does.
  FormalParameterElement? _extraParameter(ClassElement element) {
    for (final constructor in element.constructors) {
      for (final parameter in constructor.formalParameters) {
        if (parameter.name == _extraParamName) return parameter;
      }
    }
    return null;
  }

  List<_Param> _goRouterQueryParams(ClassElement element, String path) {
    final constructor = element.unnamedConstructor ?? element.constructors.firstOrNull;
    if (constructor == null) return const [];

    final pathParamNames =
        _pathParamPattern.allMatches(path).map((m) => m.group(1)!).toSet();

    final params = <_Param>[];
    for (final parameter in constructor.formalParameters) {
      final name = parameter.name;
      if (name == null || name.isEmpty) continue;
      if (name == _extraParamName) continue;
      if (pathParamNames.contains(name)) continue;
      params.add(_Param(
        name: _toKebabCase(name),
        type: _jsonType(parameter.type),
        isRequired: !_isOptionalParameter(parameter),
      ));
    }
    return params;
  }

  // ---------------------------------------------------------------------
  // auto_route
  // ---------------------------------------------------------------------

  /// The name given to `@RoutePage(name: ...)`, an empty string when the
  /// annotation is present without one, or `null` when [classElement] isn't a
  /// route page at all.
  String? _readRoutePageName(ClassElement classElement) {
    for (final annotation in classElement.metadata.annotations) {
      final annotationElement = annotation.element;
      final enclosingName =
          annotationElement?.enclosingElement?.name ?? annotationElement?.name;
      if (enclosingName != _routePageName) continue;

      final value = annotation.computeConstantValue();
      return value?.getField('name')?.toStringValue() ?? '';
    }
    return null;
  }

  bool _hasAnnotation(Element element, String name) {
    for (final annotation in element.metadata.annotations) {
      final annotationElement = annotation.element;
      final enclosingName =
          annotationElement?.enclosingElement?.name ?? annotationElement?.name;
      if (enclosingName == name) return true;
    }
    return false;
  }

  /// Parses the `routes` getter of an `@AutoRouterConfig()` router into
  /// unresolved entries — [path] and the bare text of the `page:` argument —
  /// without yet matching them to a `@RoutePage()` class.
  ///
  /// The getter's `List<AutoRoute>` is not a compile-time constant (`AutoRoute`
  /// has no `const` constructor), so it can't be read with
  /// `computeConstantValue()` the way `@TypedGoRoute`'s `path` is; this walks
  /// the resolved AST of the getter body instead.
  Future<List<_AutoRouteEntry>> _collectAutoRouteEntries(
    ClassElement routerElement,
    BuildStep buildStep,
  ) async {
    final routesGetter = routerElement.getGetter(_routesGetterName);
    if (routesGetter == null) {
      log.fine(
        '${routerElement.name} is @AutoRouterConfig but declares no '
        '`routes` getter — skipped.',
      );
      return const [];
    }

    final node = await buildStep.resolver
        .astNodeFor(routesGetter.firstFragment, resolve: true);
    final declaration = node is MethodDeclaration ? node : null;
    final body = declaration?.body;

    Expression? listExpression;
    if (body is ExpressionFunctionBody) {
      listExpression = body.expression;
    } else if (body is BlockFunctionBody) {
      for (final statement in body.block.statements) {
        if (statement is ReturnStatement) {
          listExpression = statement.expression;
          break;
        }
      }
    }

    if (listExpression is! ListLiteral) {
      log.warning(
        '${routerElement.name}.routes is not a plain `=> [...]` or '
        '`{ return [...]; }` list literal — auto_route routes could not be '
        'read from it.',
      );
      return const [];
    }

    final entries = <_AutoRouteEntry>[];
    for (final element in listExpression.elements) {
      if (element is! InstanceCreationExpression) {
        log.fine(
          '${routerElement.name}.routes: skipped a non-literal list entry '
          '(e.g. a spread or conditional) — not statically readable.',
        );
        continue;
      }
      final typeName = element.constructorName.type.element?.name;
      if (typeName == null || !_autoRouteClassNames.contains(typeName)) continue;

      String? path;
      String? pageIdentifier;
      var hasChildren = false;
      for (final argument in element.argumentList.arguments) {
        if (argument is! NamedExpression) continue;
        switch (argument.name.label.name) {
          case 'path':
            final expression = argument.expression;
            if (expression is SimpleStringLiteral) path = expression.value;
            break;
          case 'page':
            pageIdentifier = _identifierText(argument.expression);
            break;
          case 'children':
            hasChildren = true;
            break;
        }
      }

      if (path == null || pageIdentifier == null) continue;
      if (hasChildren) {
        log.info(
          '$pageIdentifier has nested `children:` routes — only its own path '
          'was collected. Nested auto_route paths are not yet supported by '
          'this builder.',
        );
      }
      entries.add(_AutoRouteEntry(path: path, pageIdentifier: pageIdentifier));
    }
    return entries;
  }

  /// The bare identifier text out of a `page:` argument, e.g. `'BookRoute'`
  /// from either `BookRoute.page` (no import prefix) or `pkg.BookRoute.page`
  /// (a prefixed import) — or `null` if [expression] isn't one of those
  /// shapes.
  String? _identifierText(Expression expression) {
    if (expression is PrefixedIdentifier) return expression.prefix.name;
    if (expression is PropertyAccess) {
      final target = expression.target;
      if (target is PrefixedIdentifier) return target.identifier.name;
      if (target is SimpleIdentifier) return target.name;
    }
    return null;
  }

  void _resolveAutoRoute(
    _AutoRouteEntry entry,
    List<_RoutePageClass> routePageClasses,
    List<_Route> routes,
    List<_ExcludedRoute> excluded,
    Set<String> seenPaths,
  ) {
    if (!entry.path.startsWith('/')) {
      log.fine('${entry.pageIdentifier} skipped: relative route ("${entry.path}").');
      return;
    }

    final page = _matchRoutePage(entry.pageIdentifier, routePageClasses);
    if (page == null) {
      log.warning(
        'Could not match auto_route entry `page: ${entry.pageIdentifier}.page` '
        '(path "${entry.path}") to any @RoutePage() class — skipped.',
      );
      return;
    }

    final classElement = page.classElement;
    final segments = entry.path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      log.fine('${classElement.name} skipped: empty host ("${entry.path}").');
      return;
    }

    final resolved = _autoRouteParams(classElement, entry.path);
    if (resolved.blocking != null) {
      final blocking = resolved.blocking!;
      final blockingType = blocking.type.getDisplayString();
      excluded.add(_ExcludedRoute(
        route: classElement.name ?? '<unknown>',
        path: entry.path,
        payload: blockingType,
        reason: _autoRouteErrorReason(blocking.name ?? '<unnamed>', blockingType),
      ));
      log.warning(
        '${classElement.name} excluded from deeplinks: required parameter '
        '`${blocking.name}` ($blockingType) is not claimed by a `:segment`, '
        '@PathParam, or @QueryParam. See $_errorAsset.',
      );
      return;
    }

    if (!seenPaths.add(entry.path)) return;

    final host = segments.first;
    final remainder = segments.skip(1).join('/');
    final diverRoute = _readDiverRoute(classElement);
    final fallbackName = remainder.isEmpty ? host : '$host/$remainder';
    final name =
        (diverRoute?.name.isNotEmpty ?? false) ? diverRoute!.name : fallbackName;

    routes.add(_Route(
      host: host,
      path: remainder,
      query: resolved.query,
      name: name,
      description: diverRoute?.description ?? '',
    ));
  }

  String _autoRouteErrorReason(String paramName, String paramType) =>
      'Required constructor parameter `$paramName` ($paramType) is not matched '
      'by name to a `:segment` in the route\'s path, and carries no explicit '
      '@PathParam or @QueryParam annotation claiming it as a URL value. '
      'auto_route allows passing a runtime object like this when navigating '
      'in-app, but a URL cannot carry it, so the route cannot be reached by a '
      'deeplink. Give it a default value, make it nullable, or add an '
      '@PathParam/@QueryParam annotation to allow URL navigation.';

  /// Matches the `page: <identifier>.page` text from an `AutoRoute(...)`
  /// entry back to the `@RoutePage()` class it refers to.
  ///
  /// An exact match against `@RoutePage(name: ...)` (when given) is tried
  /// first, since that is an unambiguous, author-chosen name. Otherwise both
  /// names are normalised — common suffixes (`Route`, `Page`, `Screen`,
  /// `View`) stripped, case folded — and compared: this stands in for
  /// replicating auto_route_generator's own `replaceInRouteName` pattern,
  /// which is per-project configurable and not worth reading back exactly.
  _RoutePageClass? _matchRoutePage(
    String pageIdentifier,
    List<_RoutePageClass> routePageClasses,
  ) {
    for (final candidate in routePageClasses) {
      if (candidate.explicitName == pageIdentifier) return candidate;
    }

    final normalizedTarget = _normalizeRouteIdentifier(pageIdentifier);
    for (final candidate in routePageClasses) {
      if (candidate.explicitName != null) continue;
      final className = candidate.classElement.name;
      if (className == null) continue;
      if (_normalizeRouteIdentifier(className) == normalizedTarget) {
        return candidate;
      }
    }
    return null;
  }

  String _normalizeRouteIdentifier(String name) {
    var result = name;
    for (final suffix in _routeIdentifierSuffixes) {
      if (result.toLowerCase().endsWith(suffix.toLowerCase())) {
        result = result.substring(0, result.length - suffix.length);
      }
    }
    return result.toLowerCase();
  }

  ({List<_Param> query, FormalParameterElement? blocking}) _autoRouteParams(
    ClassElement element,
    String path,
  ) {
    final constructor = element.unnamedConstructor ?? element.constructors.firstOrNull;
    if (constructor == null) return (query: const [], blocking: null);

    final pathParamNames =
        _pathParamPattern.allMatches(path).map((m) => m.group(1)!).toSet();

    final params = <_Param>[];
    for (final parameter in constructor.formalParameters) {
      final dartName = parameter.name;
      if (dartName == null || dartName.isEmpty) continue;
      if (_isWidgetKeyParameter(parameter)) continue;

      final annotation = _readParamAnnotation(parameter);
      final isPathParam = annotation?.kind == _ParamKind.path ||
          (annotation == null && pathParamNames.contains(dartName));
      if (isPathParam) continue;

      final isQueryParam = annotation?.kind == _ParamKind.query ||
          (annotation == null && !pathParamNames.contains(dartName));

      final required = !_isOptionalParameter(parameter);
      if (required && annotation == null && !pathParamNames.contains(dartName)) {
        // Required, and nothing — neither a `:segment` name match nor an
        // explicit annotation — claims it as coming from the URL.
        return (query: const [], blocking: parameter);
      }

      if (!isQueryParam) continue;
      final wireName = annotation?.name ?? _toKebabCase(dartName);
      params.add(_Param(
        name: wireName,
        type: _jsonType(parameter.type),
        isRequired: required,
      ));
    }
    return (query: params, blocking: null);
  }

  /// Whether [parameter] is a widget's own `Key? key`, which a page inherits
  /// from `Widget` rather than declaring as a URL value.
  bool _isWidgetKeyParameter(FormalParameterElement parameter) =>
      parameter.name == _widgetKeyParamName &&
      parameter.type.element?.name == _widgetKeyTypeName;

  ({_ParamKind kind, String? name})? _readParamAnnotation(
    FormalParameterElement parameter,
  ) {
    for (final annotation in parameter.metadata.annotations) {
      final annotationElement = annotation.element;
      final enclosingName =
          annotationElement?.enclosingElement?.name ?? annotationElement?.name;
      final kind = switch (enclosingName) {
        _pathParamAnnotationName => _ParamKind.path,
        _queryParamAnnotationName => _ParamKind.query,
        _ => null,
      };
      if (kind == null) continue;

      final value = annotation.computeConstantValue();
      final name = value?.getField('name')?.toStringValue();
      return (kind: kind, name: name);
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Shared
  // ---------------------------------------------------------------------

  /// Whether [parameter] can be omitted by the caller. That is true when it
  /// has a default value, or when its type accepts `null` (nullable or
  /// `dynamic`). A parameter that is neither must always be supplied, so it
  /// is required.
  ///
  /// This drives two things: a parameter that can't come from a URL only
  /// blocks its route when it is *not* optional (a URL can never carry it, so
  /// the route must cope with its absence), and an ordinary parameter is
  /// marked `required` in the JSON output when it is *not* optional.
  bool _isOptionalParameter(FormalParameterElement parameter) {
    if (parameter.hasDefaultValue) return true;
    final type = parameter.type;
    if (type is DynamicType) return true;
    return type.nullabilitySuffix == NullabilitySuffix.question;
  }

  String _toKebabCase(String input) {
    return input
        .replaceAllMapped(_camelBoundary2, (m) => '${m[1]}-${m[2]}')
        .replaceAllMapped(_camelBoundary1, (m) => '${m[1]}-${m[2]}')
        .toLowerCase();
  }

  String _jsonType(DartType type) {
    if (type.isDartCoreString) return 'string';
    if (type.isDartCoreBool) return 'boolean';
    if (type.isDartCoreInt) return 'string';
    if (type.isDartCoreDouble) return 'string';
    if (type.isDartCoreNum) return 'string';
    if (type.isDartCoreList) return 'list';
    if (type.element is EnumElement) return 'string';
    return type.getDisplayString().toLowerCase();
  }
}

enum _ParamKind { path, query }

/// A `@RoutePage()` class discovered somewhere in the package, keyed by its
/// explicit `@RoutePage(name: ...)` when given.
class _RoutePageClass {
  _RoutePageClass({required this.classElement, required this.explicitName});

  final ClassElement classElement;
  final String? explicitName;
}

/// An `AutoRoute(...)` list entry, parsed from the router's `routes` getter
/// but not yet matched to the `@RoutePage()` class `pageIdentifier` refers to.
class _AutoRouteEntry {
  _AutoRouteEntry({required this.path, required this.pageIdentifier});

  final String path;

  /// The bare identifier from `page: <pageIdentifier>.page`, e.g.
  /// `"BookDetailsRoute"`.
  final String pageIdentifier;
}

class _Route {
  _Route({
    required this.host,
    required this.path,
    required this.query,
    this.name = '',
    this.description = '',
  });

  final String host;
  final String path;
  final List<_Param> query;
  final String name;
  final String description;

  Map<String, Object?> toJson() => {
        'name': name,
        'description': description,
        'host': host,
        'path': path,
        'query': query.map((p) => p.toJson()).toList(),
      };
}

class _Param {
  _Param({required this.name, required this.type, required this.isRequired});

  final String name;
  final String type;

  /// Whether the caller must supply this query parameter, i.e. it has no
  /// default value and its type is non-nullable.
  final bool isRequired;

  Map<String, Object?> toJson() => {
        'name': name,
        'type': type,
        'required': isRequired,
      };
}

/// A route that was kept out of `app_urls.json` because it is not
/// deeplink-safe, recorded in `app_urls_errors.json` with [reason].
class _ExcludedRoute {
  _ExcludedRoute({
    required this.route,
    required this.path,
    required this.payload,
    required this.reason,
  });

  /// Name of the annotated route class, e.g. `DetailRoute`.
  final String route;

  /// The route's path, e.g. `/detail`.
  final String path;

  /// Display type of the parameter that made the route unroutable, e.g.
  /// `Item`.
  final String payload;

  /// Human-readable explanation of why the route is not deeplink-safe.
  final String reason;

  Map<String, Object?> toJson() => {
        'route': route,
        'path': path,
        'extra': payload,
        'reason': reason,
      };
}
