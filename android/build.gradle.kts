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

// Some plugins (e.g. irondash_engine_context) hardcode an outdated compileSdkVersion
// in their own build.gradle instead of inheriting the app's. That trips AGP's AAR
// metadata check against newer androidx transitive dependencies, so force every
// Android library subproject onto the app's compileSdk. Must be registered before
// evaluationDependsOn(":app") below forces early evaluation of the app project.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { androidExt ->
            val commonExtension = androidExt as com.android.build.gradle.BaseExtension
            commonExtension.compileSdkVersion(36)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
