package com.diver.android.ksp

import com.diver.android.internal.ParamInfo
import com.diver.android.internal.RouteBuilder
import com.diver.android.internal.RouteJson
import com.diver.android.internal.RouteModel
import com.google.devtools.ksp.processing.CodeGenerator
import com.google.devtools.ksp.processing.Dependencies
import com.google.devtools.ksp.processing.KSPLogger
import com.google.devtools.ksp.processing.Resolver
import com.google.devtools.ksp.processing.SymbolProcessor
import com.google.devtools.ksp.symbol.ClassKind
import com.google.devtools.ksp.symbol.KSAnnotated
import com.google.devtools.ksp.symbol.KSAnnotation
import com.google.devtools.ksp.symbol.KSClassDeclaration
import com.google.devtools.ksp.symbol.KSValueParameter
import java.io.File

private const val DIVER_ROUTE_FQN = "com.diver.android.DiverRoute"
private const val SERIAL_NAME_FQN = "kotlinx.serialization.SerialName"

/**
 * KSP processor that scans every class annotated with [com.diver.android.DiverRoute],
 * derives a deeplink-safe route from it, and writes them all to
 * `diver/app_urls.json` once processing finishes.
 *
 * The route derivation and JSON encoding live in [com.diver.android.internal]
 * so they can be unit-tested without KSP; this class only bridges resolved
 * symbols into that pure model.
 */
internal class DiverRouteProcessor(
    private val codeGenerator: CodeGenerator,
    private val logger: KSPLogger,
    private val options: Map<String, String>,
) : SymbolProcessor {
    private val routes = mutableListOf<RouteModel>()

    override fun process(resolver: Resolver): List<KSAnnotated> {
        val symbols = resolver.getSymbolsWithAnnotation(DIVER_ROUTE_FQN)
        for (symbol in symbols.filterIsInstance<KSClassDeclaration>()) {
            val annotation = symbol.annotations.firstOrNull {
                it.annotationType.resolve().declaration.qualifiedName?.asString() == DIVER_ROUTE_FQN
            } ?: continue

            val params = symbol.primaryConstructor?.parameters.orEmpty().map { it.toParamInfo() }
            val route = RouteBuilder.build(
                simpleName = symbol.simpleName.asString(),
                name = annotation.stringArg("name"),
                description = annotation.stringArg("description"),
                params = params,
            )
            if (route == null) {
                logger.warn(
                    "Diver: skipping ${symbol.simpleName.asString()} — a constructor " +
                        "parameter is not deeplink-safe (custom type).",
                    symbol,
                )
                continue
            }
            routes += route
        }
        return emptyList()
    }

    override fun finish() {
        val document = RouteJson.encode(routes)
        val outputDir = options["diver.outputDir"]
        if (outputDir != null) {
            val file = File(outputDir, "app_urls.json")
            file.parentFile?.mkdirs()
            file.writeText(document)
            logger.info("Diver: wrote ${routes.size} route(s) to ${file.path}")
        } else {
            codeGenerator
                .createNewFileByPath(Dependencies(aggregating = true), "diver/app_urls", "json")
                .use { it.write(document.toByteArray()) }
            logger.info(
                "Diver: wrote ${routes.size} route(s) to generated resources " +
                    "(diver/app_urls.json). Set the `diver.outputDir` KSP arg to also " +
                    "write a copy that `uploadUrls` can read.",
            )
        }
    }

    private fun KSAnnotation.stringArg(name: String): String =
        arguments.firstOrNull { it.name?.asString() == name }?.value as? String ?: ""

    private fun KSValueParameter.toParamInfo(): ParamInfo {
        val resolved = type.resolve()
        val declaration = resolved.declaration
        val enumClass = (declaration as? KSClassDeclaration)
            ?.takeIf { it.classKind == ClassKind.ENUM_CLASS }
        return ParamInfo(
            name = name?.asString() ?: "",
            type = RouteBuilder.resolveType(declaration.qualifiedName?.asString(), enumClass != null),
            optional = hasDefault || resolved.isMarkedNullable,
            values = enumClass?.enumValues().orEmpty(),
        )
    }

    /**
     * An enum's entries in declaration order, as Navigation writes them into a
     * URL: kotlinx.serialization's enum encoding, which is the entry's
     * `@SerialName` when it has one and its name otherwise.
     */
    private fun KSClassDeclaration.enumValues(): List<String> =
        declarations
            .filterIsInstance<KSClassDeclaration>()
            .filter { it.classKind == ClassKind.ENUM_ENTRY }
            .map { entry -> entry.annotations.serialName() ?: entry.simpleName.asString() }
            .toList()

    private fun Sequence<KSAnnotation>.serialName(): String? =
        firstOrNull {
            it.annotationType.resolve().declaration.qualifiedName?.asString() == SERIAL_NAME_FQN
        }?.arguments?.firstOrNull()?.value as? String
}
