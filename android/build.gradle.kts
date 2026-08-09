allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 老版本插件(如 file_picker 8.x)声明的 compileSdk 过低,统一抬到 36。
// 必须在子项目求值后覆盖(否则被其 android{} 块改回),已求值的直接改。
subprojects {
    fun bumpCompileSdk(p: Project) {
        (p.extensions.findByName("android")
                as? com.android.build.gradle.BaseExtension)
            ?.compileSdkVersion(36)
    }
    if (state.executed) bumpCompileSdk(project)
    else afterEvaluate { bumpCompileSdk(this) }
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
