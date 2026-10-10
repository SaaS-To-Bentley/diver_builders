package com.diver.android.internal

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class RouteModelTest {
    @Test
    fun kebabCasesClassAndParamNames() {
        assertEquals("home", RouteBuilder.toKebabCase("Home"))
        assertEquals("product-details", RouteBuilder.toKebabCase("ProductDetails"))
        assertEquals("user-id", RouteBuilder.toKebabCase("userId"))
        assertEquals("html-parser", RouteBuilder.toKebabCase("HTMLParser"))
    }

    @Test
    fun mapsTypesLikeTheOtherBuilders() {
        assertEquals("string", RouteBuilder.resolveType("kotlin.String", isEnum = false))
        assertEquals("boolean", RouteBuilder.resolveType("kotlin.Boolean", isEnum = false))
        assertEquals("string", RouteBuilder.resolveType("kotlin.Int", isEnum = false))
        assertEquals("string", RouteBuilder.resolveType("kotlin.Long", isEnum = false))
        assertEquals("list", RouteBuilder.resolveType("kotlin.collections.List", isEnum = false))
        assertEquals("enum", RouteBuilder.resolveType("com.example.Tab", isEnum = true))
        assertNull(RouteBuilder.resolveType("com.example.Item", isEnum = false))
    }

    @Test
    fun objectRouteHasHostOnly() {
        val route = RouteBuilder.build("Home", "", "", emptyList())!!
        assertEquals("home", route.host)
        assertEquals("", route.path)
        assertEquals(emptyList(), route.query)
        assertEquals("home", route.name) // falls back to the host
    }

    @Test
    fun requiredParamsBecomePathOptionalBecomeQuery() {
        val route = RouteBuilder.build(
            "ProductDetails",
            name = "",
            description = "",
            params = listOf(
                ParamInfo("id", "string", optional = false),
                ParamInfo("ref", "string", optional = true),
            ),
        )!!
        assertEquals("product-details", route.host)
        assertEquals(":id", route.path)
        assertEquals(listOf(QueryParam("ref", "string")), route.query)
        assertEquals("product-details/:id", route.name)
    }

    @Test
    fun annotationNameOverridesFallback() {
        val route = RouteBuilder.build(
            "Settings",
            name = "Settings",
            description = "App settings",
            params = listOf(ParamInfo("tab", "string", optional = true)),
        )!!
        assertEquals("Settings", route.name)
        assertEquals("App settings", route.description)
        assertEquals("", route.path)
        assertEquals(listOf(QueryParam("tab", "string")), route.query)
    }

    @Test
    fun routeWithNonDeeplinkSafeParamIsSkipped() {
        val route = RouteBuilder.build(
            "Detail",
            name = "",
            description = "",
            params = listOf(ParamInfo("item", null, optional = false)),
        )
        assertNull(route)
    }

    @Test
    fun encodeSortsDedupesAndMatchesSchema() {
        val routes = listOf(
            RouteModel("Settings", "App settings", "settings", "", listOf(QueryParam("tab", "string"))),
            RouteModel("home", "", "home", "", emptyList()),
            RouteModel("home dup", "", "home", "", emptyList()), // same host+path -> dropped
        )
        val document = Json.parseToJsonElement(RouteJson.encode(routes)).jsonObject
        val array = document["routes"]!!.jsonArray

        assertEquals(2, array.size)
        // sorted by host: home before settings
        assertEquals("home", array[0].jsonObject["host"]!!.jsonPrimitive.content)
        assertEquals("settings", array[1].jsonObject["host"]!!.jsonPrimitive.content)

        val settings = array[1].jsonObject
        assertEquals("Settings", settings["name"]!!.jsonPrimitive.content)
        assertEquals("App settings", settings["description"]!!.jsonPrimitive.content)
        val query = settings["query"]!!.jsonArray
        assertEquals("tab", query[0].jsonObject["name"]!!.jsonPrimitive.content)
        assertEquals("string", query[0].jsonObject["type"]!!.jsonPrimitive.content)
    }

    @Test
    fun enumQueryParamCarriesItsValues() {
        val route = RouteBuilder.build(
            "Search",
            name = "",
            description = "",
            params = listOf(ParamInfo("sort", "enum", optional = true, values = listOf("newest", "price"))),
        )!!
        assertEquals(listOf(QueryParam("sort", "enum", listOf("newest", "price"))), route.query)

        val document = Json.parseToJsonElement(RouteJson.encode(listOf(route))).jsonObject
        val param = document["routes"]!!.jsonArray[0].jsonObject["query"]!!.jsonArray[0].jsonObject
        assertEquals("enum", param["type"]!!.jsonPrimitive.content)
        assertEquals(listOf("newest", "price"), param["values"]!!.jsonArray.map { it.jsonPrimitive.content })
    }

    @Test
    fun valuesAreLeftOutForOtherTypes() {
        val routes = listOf(RouteModel("s", "", "s", "", listOf(QueryParam("tab", "string"))))
        val document = Json.parseToJsonElement(RouteJson.encode(routes)).jsonObject
        val param = document["routes"]!!.jsonArray[0].jsonObject["query"]!!.jsonArray[0].jsonObject
        assertNull(param["values"])
    }
}
