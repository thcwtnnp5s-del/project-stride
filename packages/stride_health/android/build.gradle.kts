group = "com.projectstride.stride_health"
version = "1.0-SNAPSHOT"

// Pinned explicitly, in one place, so a version bump is a reviewable edit.
val healthConnectVersion = "1.1.0"
val coroutinesVersion = "1.10.2"

buildscript {
    val kotlinVersion = "2.3.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.0.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.projectstride.stride_health"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
            // The CANONICAL origin-key vectors, read at test time rather than
            // transcribed into Kotlin. Three transcribed copies is three
            // chances to drift, and a drift re-keys every origin and re-grants
            // the retention window silently -- with nothing to detect it.
            //
            // Pointed at the shared fixture directory itself, not a copy: a
            // copy would be the fourth transcription wearing a build step.
            resources.srcDirs("../test_fixtures")
        }
    }

    defaultConfig {
        // Unchanged, deliberately. Health Connect's client library declares
        // minSdk 26; raising the whole application to 26 to satisfy a
        // dependency the game degrades gracefully without would drop Android 7
        // devices for no gain. `src/main/AndroidManifest.xml` overrides the
        // library's floor, and `HealthConnectStepSource.availability()` checks
        // the OS version BEFORE touching a Health Connect type -- below
        // Android 8 the answer is SERVICE_MISSING, which is the same normal,
        // fully-playable state as a phone without Health Connect installed.
        minSdk = 24
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Health Connect. Pinned to an exact stable version rather than a range:
    // the origin key, the changes-token contract, and the aggregation shape are
    // all load-bearing, and a silent minor bump is not a thing this adapter
    // should be able to absorb without a test run.
    implementation("androidx.health.connect:connect-client:$healthConnectVersion")

    // The Health Connect client is suspend-based. Declared explicitly rather
    // than relied on transitively, for the same reason.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:$coroutinesVersion")

    testImplementation("org.jetbrains.kotlin:kotlin-test")

    // Mockito is gone deliberately. The platform now sits behind `StepSource`,
    // so the suite substitutes a real fake with real behaviour instead of
    // stubbing an Android `Context` -- and every interesting case (corrections,
    // deletions, several origins, token expiry, truncation, pagination,
    // resumption) is expressible without a mocking framework.

    // The canonical origin-key vectors are JSON. `android.jar`'s `org.json` is
    // a stub that throws in a unit test, so the real implementation is required
    // to READ THE FIXTURE rather than transcribe it into Kotlin.
    testImplementation("org.json:json:20250107")
}
