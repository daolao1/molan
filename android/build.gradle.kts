allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 老版本插件(如 file_picker 8.x)声明的 compileSdk 过低,统一抬到 36
subprojects {
    plugins.withId("com.android.library") {
        (extensions.findByName("android")
                as? com.android.build.gradle.BaseExtension)
            ?.compileSdkVersion(36)
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
