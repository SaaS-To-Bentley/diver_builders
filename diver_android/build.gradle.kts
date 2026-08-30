plugins {
    kotlin("jvm") version "2.1.0"
}

group = "com.diver"
version = "0.1.0"

repositories {
    mavenCentral()
}

dependencies {
    // KSP API — the processor ("builder") compiles against this. It is an
    // `implementation` dependency so it does NOT leak onto a consuming app's
    // compile classpath when the artifact is also used for the annotation.
    implementation("com.google.devtools.ksp:symbol-processing-api:2.1.0-1.0.29")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.0")

    testImplementation("org.jetbrains.kotlin:kotlin-test-junit:2.1.0")
}

// The upload entrypoint can be run with `./gradlew run --args="..."` during
// development of this library itself.
tasks.register<JavaExec>("uploadUrls") {
    group = "diver"
    description = "POST a generated diver/app_urls.json to the Diver API."
    mainClass.set("com.diver.android.upload.UrlUploaderKt")
    classpath = sourceSets["main"].runtimeClasspath
}
