package com.diver.android.upload

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.put
import java.io.File
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import kotlin.system.exitProcess

private const val DEFAULT_FILE_PATH = "diver/app_urls.json"
private const val CONFIG_PATH = "diver/diver_config.properties"
private const val ORG_ID_VAR = "ORG_ID"
private const val APP_ID_VAR = "APP_ID"
private const val IMPORT_URL = "https://api.diver.mthy.dev/import"

/**
 * Reads a generated `diver/app_urls.json`, injects `org_id`/`app_id`, and POSTs
 * it to the Diver API. Mirrors the Flutter `upload_urls` executable and the
 * `diver-expo-builder upload` command.
 */
fun main(args: Array<String>) {
    val filePath = args.firstOrNull() ?: DEFAULT_FILE_PATH
    val file = File(filePath)
    if (!file.exists()) {
        System.err.println("Error: $filePath not found.")
        System.err.println()
        System.err.println("Build your app with the Diver KSP processor first, passing the")
        System.err.println("output directory so the file lands somewhere uploadable, e.g.:")
        System.err.println()
        System.err.println("    ksp { arg(\"diver.outputDir\", \"\$projectDir/diver\") }")
        exitProcess(1)
    }

    // Environment variables take precedence over the properties file.
    val config = loadConfig() + System.getenv()
    val orgId = config[ORG_ID_VAR]
    val appId = config[APP_ID_VAR]
    if (orgId.isNullOrEmpty() || appId.isNullOrEmpty()) {
        System.err.println("Error: $ORG_ID_VAR and $APP_ID_VAR must be set, either as")
        System.err.println("environment variables or in $CONFIG_PATH (KEY=value format).")
        exitProcess(1)
    }

    val root = Json.parseToJsonElement(file.readText()).jsonObject
    val body = buildJsonObject {
        root.forEach { (key, value) -> put(key, value) }
        put("org_id", orgId)
        put("app_id", appId)
    }
    val payload = Json.encodeToString(JsonObject.serializer(), body)

    println("Uploading $filePath -> $IMPORT_URL")
    val request = HttpRequest.newBuilder(URI.create(IMPORT_URL))
        .header("Content-Type", "application/json")
        .POST(HttpRequest.BodyPublishers.ofString(payload))
        .build()
    val response = HttpClient.newHttpClient().send(request, HttpResponse.BodyHandlers.ofString())

    if (response.statusCode() in 200..299) {
        println("Upload succeeded (${response.statusCode()}).")
    } else {
        System.err.println("Upload failed (${response.statusCode()}): ${response.body()}")
        exitProcess(1)
    }
}

private fun loadConfig(): Map<String, String> {
    val file = File(CONFIG_PATH)
    if (!file.exists()) return emptyMap()

    val result = mutableMapOf<String, String>()
    for (raw in file.readLines()) {
        val line = raw.trim()
        if (line.isEmpty() || line.startsWith("#")) continue

        val eq = line.indexOf('=')
        if (eq < 0) continue

        val key = line.substring(0, eq).trim()
        var value = line.substring(eq + 1).trim()
        if (value.length >= 2 &&
            ((value.startsWith("\"") && value.endsWith("\"")) ||
                (value.startsWith("'") && value.endsWith("'")))
        ) {
            value = value.substring(1, value.length - 1)
        }
        result[key] = value
    }
    return result
}
