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

subprojects {
    pluginManager.withPlugin("com.android.library") {
        val androidExt = extensions.findByName("android") ?: return@withPlugin
        val currentNamespace = runCatching {
            androidExt.javaClass.getMethod("getNamespace").invoke(androidExt) as? String
        }.getOrNull()
        if (!currentNamespace.isNullOrBlank()) return@withPlugin
        val manifestFile = project.file("src/main/AndroidManifest.xml")
        if (!manifestFile.exists()) return@withPlugin
        val manifestText = manifestFile.readText()
        val packageName = Regex("package\\s*=\\s*\"([^\"]+)\"")
            .find(manifestText)
            ?.groupValues
            ?.getOrNull(1)
            ?.trim()
        if (packageName.isNullOrBlank()) return@withPlugin
        runCatching {
            androidExt.javaClass.getMethod("setNamespace", String::class.java).invoke(androidExt, packageName)
        }
    }
}


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

