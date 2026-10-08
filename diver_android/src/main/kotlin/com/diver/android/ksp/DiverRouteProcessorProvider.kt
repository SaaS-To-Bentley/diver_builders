package com.diver.android.ksp

import com.google.devtools.ksp.processing.SymbolProcessor
import com.google.devtools.ksp.processing.SymbolProcessorEnvironment
import com.google.devtools.ksp.processing.SymbolProcessorProvider

/**
 * KSP entry point. Registered via
 * `META-INF/services/com.google.devtools.ksp.processing.SymbolProcessorProvider`
 * so that adding `ksp(...)` on this artifact wires up [DiverRouteProcessor].
 */
class DiverRouteProcessorProvider : SymbolProcessorProvider {
    override fun create(environment: SymbolProcessorEnvironment): SymbolProcessor =
        DiverRouteProcessor(
            codeGenerator = environment.codeGenerator,
            logger = environment.logger,
            options = environment.options,
        )
}
