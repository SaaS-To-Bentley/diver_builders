import DiverKit
import Foundation
import SwiftParser
import SwiftSyntax

// Walks Swift source, collecting every `enum` it declares, so a route property
// typed as one can list the values it takes. Runs over all the sources before
// any route is collected: a route may name an enum declared in a later file.
final class EnumVisitor: SyntaxVisitor {
    /// Keyed by the enum's simple name, which is all a property's type
    /// annotation gives the scanner to match on — so two enums with the same
    /// name in different scopes collide, and the last one scanned wins.
    var enums: [String: [String]] = [:]

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        if let values = enumValues(node) {
            enums[node.name.text] = values
        }
        return .visitChildren
    }
}

// Walks Swift source, collecting types that conform to `DiverRoute` and turning
// each into a `RouteModel`. Syntax-only: it never type-checks, so an unknown
// nominal property type is assumed URL-serializable (mapped to `string`); only
// closures/tuples mark a route as not deeplink-safe.
final class RouteVisitor: SyntaxVisitor {
    var routes: [RouteModel] = []
    var skipped: [String] = []

    /// What `EnumVisitor` found, by name.
    private let enums: [String: [String]]

    init(enums: [String: [String]]) {
        self.enums = enums
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        collect(name: node.name.text, inheritance: node.inheritanceClause, members: node.memberBlock.members)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        collect(name: node.name.text, inheritance: node.inheritanceClause, members: node.memberBlock.members)
        return .visitChildren
    }

    private func collect(name: String, inheritance: InheritanceClauseSyntax?, members: MemberBlockItemListSyntax) {
        guard conformsToDiverRoute(inheritance) else { return }

        var params: [ParamInfo] = []
        var diverName = ""
        var diverDescription = ""

        for member in members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
            if varDecl.modifiers.contains(where: { $0.name.text == "static" }) {
                if let (key, value) = stringConstant(varDecl) {
                    if key == "diverName" { diverName = value }
                    else if key == "diverDescription" { diverDescription = value }
                }
                continue
            }
            if let param = paramInfo(varDecl, enums: enums) {
                params.append(param)
            }
        }

        if let route = RouteBuilder.build(
            simpleName: name,
            name: diverName,
            description: diverDescription,
            params: params
        ) {
            routes.append(route)
        } else {
            skipped.append(name)
        }
    }
}

private func conformsToDiverRoute(_ clause: InheritanceClauseSyntax?) -> Bool {
    guard let clause else { return false }
    return clause.inheritedTypes.contains {
        $0.type.as(IdentifierTypeSyntax.self)?.name.text == "DiverRoute"
    }
}

/// Reads `static let diverName = "..."` style metadata as a (name, literal) pair.
private func stringConstant(_ varDecl: VariableDeclSyntax) -> (String, String)? {
    guard let binding = varDecl.bindings.first,
          let id = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
          let value = binding.initializer?.value,
          let literal = value.as(StringLiteralExprSyntax.self),
          literal.segments.count == 1,
          let segment = literal.segments.first?.as(StringSegmentSyntax.self)
    else { return nil }
    return (id, segment.content.text)
}

/// The values an enum takes in a URL: a `String`-backed enum's raw values
/// (explicit, or the case name Swift gives it implicitly), any other enum's
/// case names. Nil for an enum with an associated value anywhere, which is not
/// one value a URL can carry.
private func enumValues(_ node: EnumDeclSyntax) -> [String]? {
    let stringBacked = node.inheritanceClause?.inheritedTypes.contains {
        $0.type.as(IdentifierTypeSyntax.self)?.name.text == "String"
    } ?? false

    var values: [String] = []
    for member in node.memberBlock.members {
        guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { continue }
        for element in caseDecl.elements {
            if element.parameterClause != nil { return nil }
            if stringBacked,
               let literal = element.rawValue?.value.as(StringLiteralExprSyntax.self),
               literal.segments.count == 1,
               let segment = literal.segments.first?.as(StringSegmentSyntax.self) {
                values.append(segment.content.text)
            } else {
                values.append(element.name.text)
            }
        }
    }
    return values.isEmpty ? nil : values
}

private func paramInfo(_ varDecl: VariableDeclSyntax, enums: [String: [String]]) -> ParamInfo? {
    guard let binding = varDecl.bindings.first else { return nil }
    if binding.accessorBlock != nil { return nil } // computed property
    guard let id = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { return nil }

    let hasInitializer = binding.initializer != nil
    if let type = binding.typeAnnotation?.type {
        let (kind, optional) = typeKind(type)
        return paramInfo(id, kind: resolve(kind, enums: enums), optional: optional || hasInitializer)
    }
    if hasInitializer, let kind = literalKind(binding.initializer!.value) {
        return paramInfo(id, kind: resolve(kind, enums: enums), optional: true)
    }
    return nil
}

private func paramInfo(_ name: String, kind: SwiftTypeKind, optional: Bool) -> ParamInfo {
    var values: [String] = []
    if case .enumeration(let cases) = kind { values = cases }
    return ParamInfo(name: name, type: RouteBuilder.diverType(kind), optional: optional, values: values)
}

/// A nominal type the sources declare as an enum, as that enum.
private func resolve(_ kind: SwiftTypeKind, enums: [String: [String]]) -> SwiftTypeKind {
    if case .nominal(let name) = kind, let values = enums[name] {
        return .enumeration(values)
    }
    return kind
}

/// Reduces a type to a `SwiftTypeKind` and whether it is optional (`T?`).
private func typeKind(_ type: TypeSyntax) -> (SwiftTypeKind, Bool) {
    if let optional = type.as(OptionalTypeSyntax.self) {
        return (typeKind(optional.wrappedType).0, true)
    }
    if type.is(ArrayTypeSyntax.self) {
        return (.array, false)
    }
    if let ident = type.as(IdentifierTypeSyntax.self) {
        return ident.name.text == "Array" ? (.array, false) : (.nominal(ident.name.text), false)
    }
    // `Settings.Theme` — a type nested in another; the last name is the one
    // its declaration goes by.
    if let member = type.as(MemberTypeSyntax.self) {
        return (.nominal(member.name.text), false)
    }
    if type.is(FunctionTypeSyntax.self) || type.is(TupleTypeSyntax.self) {
        return (.unsupported, false)
    }
    return (.unsupported, false)
}

/// Infers a kind from a default-value literal when there is no type annotation.
private func literalKind(_ expr: ExprSyntax) -> SwiftTypeKind? {
    if expr.is(StringLiteralExprSyntax.self) { return .nominal("String") }
    if expr.is(IntegerLiteralExprSyntax.self) { return .nominal("Int") }
    if expr.is(FloatLiteralExprSyntax.self) { return .nominal("Double") }
    if expr.is(BooleanLiteralExprSyntax.self) { return .nominal("Bool") }
    if expr.is(ArrayExprSyntax.self) { return .array }
    // `Theme.system` — an enum case, typed by the enum it is named through.
    if let member = expr.as(MemberAccessExprSyntax.self),
       let base = member.base?.as(DeclReferenceExprSyntax.self) {
        return .nominal(base.baseName.text)
    }
    return nil
}

private func swiftFiles(in path: String) -> [String] {
    let manager = FileManager.default
    var isDirectory: ObjCBool = false
    guard manager.fileExists(atPath: path, isDirectory: &isDirectory) else { return [] }
    if !isDirectory.boolValue {
        return path.hasSuffix(".swift") ? [path] : []
    }
    var files: [String] = []
    if let enumerator = manager.enumerator(atPath: path) {
        for case let relative as String in enumerator where relative.hasSuffix(".swift") {
            files.append((path as NSString).appendingPathComponent(relative))
        }
    }
    return files.sorted()
}

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(2)
}

// --- entry point ---

let arguments = Array(CommandLine.arguments.dropFirst())
guard let outputIndex = arguments.firstIndex(of: "--output"), outputIndex + 1 < arguments.count else {
    fail("usage: DiverScanner --output <file> <source-path>...")
}
let outputPath = arguments[outputIndex + 1]
let inputPaths = arguments.enumerated()
    .filter { $0.offset != outputIndex && $0.offset != outputIndex + 1 }
    .map(\.element)

let trees = inputPaths.flatMap(swiftFiles(in:)).compactMap { file -> SourceFileSyntax? in
    guard let source = try? String(contentsOf: URL(fileURLWithPath: file), encoding: .utf8) else { return nil }
    return Parser.parse(source: source)
}

let enumVisitor = EnumVisitor(viewMode: .sourceAccurate)
for tree in trees {
    enumVisitor.walk(tree)
}

let visitor = RouteVisitor(enums: enumVisitor.enums)
for tree in trees {
    visitor.walk(tree)
}

let document = RouteJSON.encode(visitor.routes)
let outputURL = URL(fileURLWithPath: outputPath)
try? FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
do {
    try document.write(to: outputURL, atomically: true, encoding: .utf8)
} catch {
    fail("Diver: failed to write \(outputPath): \(error)")
}

for name in visitor.skipped {
    FileHandle.standardError.write(
        Data("Diver: skipping \(name) — a property is not deeplink-safe (closure/tuple type).\n".utf8)
    )
}
FileHandle.standardError.write(
    Data("Diver: wrote \(visitor.routes.count) route(s) to \(outputPath)\n".utf8)
)
