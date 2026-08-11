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
subprojects {
    project.evaluationDependsOn(":app")
}

// file_picker / flutter_plugin_android_lifecycle need compileSdk 36+
subprojects {
    fun forceCompileSdk36() {
        val android = extensions.findByName("android") ?: return
        try {
            android.javaClass.methods
                .firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 }
                ?.invoke(android, 36)
        } catch (_: Exception) {
            // ignore plugins that don't expose compileSdk
        }
    }

    pluginManager.withPlugin("com.android.library") {
        forceCompileSdk36()
    }
    pluginManager.withPlugin("com.android.application") {
        forceCompileSdk36()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
