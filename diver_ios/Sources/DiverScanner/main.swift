import DiverKit
import Foundation
import SwiftParser
import SwiftSyntax

// Walks Swift source, collecting types that conform to `DiverRoute` and turning
// each into a `RouteModel`. Syntax-only: it never type-checks, so an unknown
// nominal property type is assumed URL-serializable (mapped to `string`); only
// closures/tuples mark a route as not deeplink-safe.
final class RouteVisitor: SyntaxVisitor {
    var routes: [RouteModel] = []
    var skipped: [String] = []

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
            if let param = paramInfo(varDecl) {
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

private func paramInfo(_ varDecl: VariableDeclSyntax) -> ParamInfo? {
    guard let binding = varDecl.bindings.first else { return nil }
    if binding.accessorBlock != nil { return nil } // computed property
    guard let id = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { return nil }

    let hasInitializer = binding.initializer != nil
    if let type = binding.typeAnnotation?.type {
        let (kind, optional) = typeKind(type)
        return ParamInfo(name: id, type: RouteBuilder.diverType(kind), optional: optional || hasInitializer)
    }
    if hasInitializer, let kind = literalKind(binding.initializer!.value) {
        return ParamInfo(name: id, type: RouteBuilder.diverType(kind), optional: true)
    }
    return nil
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

let visitor = RouteVisitor(viewMode: .sourceAccurate)
for input in inputPaths {
    for file in swiftFiles(in: input) {
        guard let source = try? String(contentsOf: URL(fileURLWithPath: file), encoding: .utf8) else { continue }
        visitor.walk(Parser.parse(source: source))
    }
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
