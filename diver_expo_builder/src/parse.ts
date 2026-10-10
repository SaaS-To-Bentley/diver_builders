import ts from 'typescript';

export interface DiverRouteMeta {
  name: string;
  description: string;
}

export interface QueryParam {
  name: string;
  type: 'string' | 'boolean' | 'list' | 'enum';
  /** The values an `enum` parameter can take; absent for every other type. */
  values?: string[];
}

type ParamType = Omit<QueryParam, 'name'>;

/// What the file declares that a parameter's type can refer to by name: type
/// aliases (`type Sort = 'new' | 'old'`) and TypeScript enums. Only the route
/// file's own declarations — a type imported from elsewhere is not followed,
/// and reads as a plain string.
interface LocalTypes {
  aliases: Map<string, ts.TypeNode>;
  enums: Map<string, string[]>;
}

export interface ParsedRouteFile {
  meta: DiverRouteMeta | null;
  query: QueryParam[];
}

const SEARCH_PARAM_HOOKS = new Set([
  'useLocalSearchParams',
  'useGlobalSearchParams',
  'useSearchParams',
]);

/// Statically extracts Diver metadata from a single Expo Router route file:
/// an optional `export const diverRoute = { name, description }` object, and
/// query parameters read from the type argument of
/// `useLocalSearchParams<{ ... }>()` (or its global/deprecated variants).
export function parseRouteFile(filePath: string, text: string): ParsedRouteFile {
  const scriptKind =
    filePath.endsWith('.tsx') || filePath.endsWith('.jsx')
      ? ts.ScriptKind.TSX
      : ts.ScriptKind.TS;
  const sourceFile = ts.createSourceFile(
    filePath,
    text,
    ts.ScriptTarget.Latest,
    true,
    scriptKind,
  );

  return {
    meta: readDiverRoute(sourceFile),
    query: readSearchParams(sourceFile),
  };
}

function readDiverRoute(sourceFile: ts.SourceFile): DiverRouteMeta | null {
  for (const statement of sourceFile.statements) {
    if (!ts.isVariableStatement(statement)) continue;
    const isExported = statement.modifiers?.some(
      (m) => m.kind === ts.SyntaxKind.ExportKeyword,
    );
    if (!isExported) continue;

    for (const declaration of statement.declarationList.declarations) {
      if (!ts.isIdentifier(declaration.name)) continue;
      if (declaration.name.text !== 'diverRoute') continue;
      const object = objectLiteralFrom(declaration.initializer);
      if (!object) continue;
      return {
        name: stringProperty(object, 'name') ?? '',
        description: stringProperty(object, 'description') ?? '',
      };
    }
  }
  return null;
}

/// Resolves the object literal carrying the route metadata, accepting either a
/// bare object (`export const diverRoute = { ... }`) or the
/// `defineDiverRoute({ ... })` helper from diver-expo-builder/route.
function objectLiteralFrom(
  initializer: ts.Expression | undefined,
): ts.ObjectLiteralExpression | null {
  if (!initializer) return null;
  if (ts.isObjectLiteralExpression(initializer)) return initializer;
  if (
    ts.isCallExpression(initializer) &&
    initializer.arguments.length > 0 &&
    ts.isObjectLiteralExpression(initializer.arguments[0])
  ) {
    return initializer.arguments[0];
  }
  return null;
}

function stringProperty(object: ts.ObjectLiteralExpression, name: string): string | null {
  for (const property of object.properties) {
    if (!ts.isPropertyAssignment(property)) continue;
    const propertyName = ts.isIdentifier(property.name) || ts.isStringLiteral(property.name)
      ? property.name.text
      : null;
    if (propertyName !== name) continue;
    if (
      ts.isStringLiteral(property.initializer) ||
      ts.isNoSubstitutionTemplateLiteral(property.initializer)
    ) {
      return property.initializer.text;
    }
  }
  return null;
}

function readSearchParams(sourceFile: ts.SourceFile): QueryParam[] {
  const params: QueryParam[] = [];
  const seen = new Set<string>();
  const locals = readLocalTypes(sourceFile);

  const visit = (node: ts.Node): void => {
    if (
      ts.isCallExpression(node) &&
      ts.isIdentifier(node.expression) &&
      SEARCH_PARAM_HOOKS.has(node.expression.text) &&
      node.typeArguments?.length === 1
    ) {
      const typeArgument = node.typeArguments[0];
      if (ts.isTypeLiteralNode(typeArgument)) {
        for (const member of typeArgument.members) {
          if (!ts.isPropertySignature(member) || !member.name) continue;
          const name = ts.isIdentifier(member.name) || ts.isStringLiteral(member.name)
            ? member.name.text
            : null;
          if (name === null || seen.has(name)) continue;
          seen.add(name);
          params.push({ name, ...jsonType(member.type, locals) });
        }
      }
    }
    ts.forEachChild(node, visit);
  };
  visit(sourceFile);

  return params;
}

function readLocalTypes(sourceFile: ts.SourceFile): LocalTypes {
  const aliases = new Map<string, ts.TypeNode>();
  const enums = new Map<string, string[]>();

  for (const statement of sourceFile.statements) {
    if (ts.isTypeAliasDeclaration(statement)) {
      aliases.set(statement.name.text, statement.type);
    } else if (ts.isEnumDeclaration(statement)) {
      // A string enum's values are what goes into the URL; a member without a
      // string initializer goes by its name.
      enums.set(
        statement.name.text,
        statement.members.map((member) =>
          member.initializer && ts.isStringLiteral(member.initializer)
            ? member.initializer.text
            : member.name.getText(sourceFile),
        ),
      );
    }
  }
  return { aliases, enums };
}

function jsonType(
  node: ts.TypeNode | undefined,
  locals: LocalTypes,
  resolving: Set<string> = new Set(),
): ParamType {
  if (!node) return { type: 'string' };
  if (node.kind === ts.SyntaxKind.BooleanKeyword) return { type: 'boolean' };
  if (ts.isArrayTypeNode(node)) return { type: 'list' };
  if (ts.isParenthesizedTypeNode(node)) return jsonType(node.type, locals, resolving);
  if (ts.isTypeReferenceNode(node) && ts.isIdentifier(node.typeName)) {
    const name = node.typeName.text;
    if (name === 'Array') return { type: 'list' };

    const values = locals.enums.get(name);
    if (values && values.length > 0) return { type: 'enum', values };

    // `resolving` guards a self-referencing alias, which TypeScript itself
    // rejects but a file mid-edit can still contain.
    const alias = locals.aliases.get(name);
    if (alias && !resolving.has(name)) {
      return jsonType(alias, locals, new Set(resolving).add(name));
    }
    return { type: 'string' };
  }
  if (ts.isUnionTypeNode(node)) {
    const members = node.types.filter(
      (member) => member.kind !== ts.SyntaxKind.UndefinedKeyword,
    );
    // expo-router constrains param values to string | string[], so booleans
    // are conventionally typed as a 'true' | 'false' literal union.
    if (members.length > 0 && members.every(isBooleanLiteralString)) {
      return { type: 'boolean' };
    }
    // Any other union made only of string literals is a fixed set of values.
    const literals = members.map(stringLiteralText);
    if (members.length > 0 && literals.every((literal) => literal !== null)) {
      return { type: 'enum', values: [...new Set(literals as string[])] };
    }
    const types = members.map((member) => jsonType(member, locals, resolving));
    if (types.some((member) => member.type === 'list')) return { type: 'list' };
    if (types.some((member) => member.type === 'boolean')) return { type: 'boolean' };
    return { type: 'string' };
  }
  if (ts.isLiteralTypeNode(node)) {
    const literal = node.literal;
    if (
      literal.kind === ts.SyntaxKind.TrueKeyword ||
      literal.kind === ts.SyntaxKind.FalseKeyword
    ) {
      return { type: 'boolean' };
    }
  }
  return { type: 'string' };
}

function stringLiteralText(node: ts.TypeNode): string | null {
  return ts.isLiteralTypeNode(node) && ts.isStringLiteral(node.literal)
    ? node.literal.text
    : null;
}

function isBooleanLiteralString(node: ts.TypeNode): boolean {
  if (!ts.isLiteralTypeNode(node)) return false;
  const literal = node.literal;
  if (
    literal.kind === ts.SyntaxKind.TrueKeyword ||
    literal.kind === ts.SyntaxKind.FalseKeyword
  ) {
    return true;
  }
  return ts.isStringLiteral(literal) && (literal.text === 'true' || literal.text === 'false');
}
