// Minimal consumer that exercises the Diver KSP processor end to end. It does
// NOT need the kotlinx.serialization plugin: the processor keys off @DiverRoute,
// not @Serializable, so plain annotated classes are enough to verify output.
plugins {
    kotlin("jvm") version "2.1.0"
    id("com.google.devtools.ksp") version "2.1.0-1.0.29"
}

repositories {
    mavenCentral()
}

dependencies {
    compileOnly(rootProject)
    ksp(rootProject)
}

ksp {
    arg("diver.outputDir", "${projectDir}/diver")
}
