buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.2.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.22")
        classpath("com.google.gms:google-services:4.4.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Modern Gradle build directory configuration
val newBuildDir = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()

rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    project.layout.buildDirectory.set(
        newBuildDir.dir(project.name)
    )
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}