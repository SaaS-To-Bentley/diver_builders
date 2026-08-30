import com.vanniktech.maven.publish.SonatypeHost

plugins {
    kotlin("jvm") version "2.1.0"
    id("com.vanniktech.maven.publish") version "0.30.0"
}

group = "io.github.saas-to-bentley"
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

mavenPublishing {
    publishToMavenCentral(SonatypeHost.CENTRAL_PORTAL, automaticRelease = true)
    signAllPublications()

    coordinates(group.toString(), "diver-android", version.toString())

    pom {
        name.set("diver-android")
        description.set(
            "KSP processor that aggregates Jetpack Navigation type-safe routes " +
                "into diver/app_urls.json and uploads them to the Diver API."
        )
        inceptionYear.set("2026")
        url.set("https://github.com/SaaS-To-Bentley/diver_builders")

        licenses {
            license {
                name.set("MIT License")
                url.set("https://opensource.org/licenses/MIT")
                distribution.set("repo")
            }
        }

        developers {
            developer {
                id.set("saas-to-bentley")
                name.set("SaaS-To-Bentley")
                url.set("https://github.com/SaaS-To-Bentley")
            }
        }

        scm {
            url.set("https://github.com/SaaS-To-Bentley/diver_builders")
            connection.set("scm:git:git://github.com/SaaS-To-Bentley/diver_builders.git")
            developerConnection.set("scm:git:ssh://git@github.com/SaaS-To-Bentley/diver_builders.git")
        }
    }
}
