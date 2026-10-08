package com.diver.android.internal

import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.add
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Pure, KSP-free model and helpers for turning a Jetpack Navigation type-safe
 * route into a Diver route description. Kept free of any `symbol-processing`
 * types so it can be unit-tested directly; the KSP processor feeds it plain
 * [ParamInfo] values extracted from the resolved symbols.
 */

/** A single constructor parameter of a route class. */
internal data class ParamInfo(
    val name: String,
    /** Diver query type (`string` / `boolean` / `list` / `enum`), or null if
     *  the type is not URL-serializable (a custom object) — such routes are
     *  skipped. */
    val type: String?,
    /** Optional args (have a default value or a nullable type) become query
     *  parameters; required args become path segments. */
    val optional: Boolean,
    /** An `enum` param's values, as they appear in the URL. Empty otherwise. */
    val values: List<String> = emptyList(),
)

internal data class QueryParam(
    val name: String,
    val type: String,
    /** The values an `enum` param can take; empty for every other type. */
    val values: List<String> = emptyList(),
)

internal data class RouteModel(
    val name: String,
    val description: String,
    val host: String,
    val path: String,
    val query: List<QueryParam>,
)

internal object RouteBuilder {
    private val boundary1 = Regex("([a-z0-9])([A-Z])")
    private val boundary2 = Regex("([A-Z]+)([A-Z][a-z])")

    private val listTypes = setOf(
        "kotlin.collections.List",
        "kotlin.collections.MutableList",
        "kotlin.Array",
    )
    private val stringTypes = setOf(
        "kotlin.String",
        "kotlin.Int",
        "kotlin.Long",
        "kotlin.Short",
        "kotlin.Byte",
        "kotlin.Float",
        "kotlin.Double",
        "kotlin.Char",
    )

    /**
     * Maps a parameter's resolved type to a Diver query type, or null when the
     * type is not reachable by URL alone (the Android analog of Flutter's
     * `$extra` skip). Numbers are reported as `string`, matching the other
     * Diver builders.
     */
    fun resolveType(qualifiedName: String?, isEnum: Boolean): String? {
        if (qualifiedName == "kotlin.Boolean") return "boolean"
        if (qualifiedName in listTypes) return "list"
        if (qualifiedName in stringTypes) return "string"
        if (isEnum) return "enum"
        return null
    }

    /** CamelCase / camelCase → kebab-case, e.g. `ProductDetails` → `product-details`. */
    fun toKebabCase(input: String): String =
        input
            .replace(boundary2) { "${it.groupValues[1]}-${it.groupValues[2]}" }
            .replace(boundary1) { "${it.groupValues[1]}-${it.groupValues[2]}" }
            .lowercase()

    /**
     * Builds the route description for a class, or null when any parameter is
     * not deeplink-safe (so the route is skipped). [simpleName] is the route
     * class name; [params] are its primary-constructor parameters in order.
     */
    fun build(
        simpleName: String,
        name: String,
        description: String,
        params: List<ParamInfo>,
    ): RouteModel? {
        if (params.any { it.type == null }) return null

        val host = toKebabCase(simpleName)
        val pathParams = params.filter { !it.optional }
        val queryParams = params.filter { it.optional }

        val path = pathParams.joinToString("/") { ":" + toKebabCase(it.name) }
        val query = queryParams.map { QueryParam(toKebabCase(it.name), it.type!!, it.values) }

        val fallbackName = if (path.isEmpty()) host else "$host/$path"
        return RouteModel(
            name = name.ifEmpty { fallbackName },
            description = description,
            host = host,
            path = path,
            query = query,
        )
    }
}

internal object RouteJson {
    @OptIn(ExperimentalSerializationApi::class)
    private val json = Json { prettyPrint = true; prettyPrintIndent = "  " }

    /**
     * Encodes routes into the `{ "routes": [...] }` document the Diver
     * `/import` endpoint consumes. Routes are deduplicated by host+path and
     * sorted by host then path, matching the other Diver builders.
     */
    fun encode(routes: List<RouteModel>): String {
        val seen = HashSet<String>()
        val unique = routes
            .filter { seen.add(it.host + "\u0000" + it.path) }
            .sortedWith(compareBy({ it.host }, { it.path }))

        val document = buildJsonObject {
            put("routes", routesArray(unique))
        }
        return json.encodeToString(JsonObject.serializer(), document) + "\n"
    }

    private fun routesArray(routes: List<RouteModel>): JsonArray = buildJsonArray {
        for (route in routes) {
            add(buildJsonObject {
                put("name", route.name)
                put("description", route.description)
                put("host", route.host)
                put("path", route.path)
                put("query", buildJsonArray {
                    for (param in route.query) {
                        add(buildJsonObject {
                            put("name", param.name)
                            put("type", param.type)
                            if (param.values.isNotEmpty()) {
                                put("values", buildJsonArray { param.values.forEach { add(it) } })
                            }
                        })
                    }
                })
            })
        }
    }
}
