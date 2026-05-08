buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
<<<<<<< HEAD
        classpath("com.android.tools.build:gradle:8.6.0")
=======
        classpath("com.android.tools.build:gradle:8.1.0")
        // Firebase google-services plugin
>>>>>>> c00c9d440be47def005461b5f096b9180b2c8584
        classpath("com.google.gms:google-services:4.4.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
<<<<<<< HEAD

subprojects {
    project.evaluationDependsOn(":app")
}
=======
subprojects {
    project.evaluationDependsOn(":app")
}
subprojects {
    project.plugins.withId("com.android.library") {
        project.extensions.configure<com.android.build.gradle.LibraryExtension> {
            compileSdk = 36
        }
    }
}
>>>>>>> c00c9d440be47def005461b5f096b9180b2c8584

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}