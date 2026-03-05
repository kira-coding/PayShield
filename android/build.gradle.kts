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
    val projectNamespaceFix: (Project) -> Unit = { proj ->
        if (proj.name == "telephony") {
            val android = proj.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            if (android != null) {
                android.namespace = "com.shounakmulay.telephony"
            }
        }
    }

    if (project.state.executed) {
        projectNamespaceFix(project)
    } else {
        project.afterEvaluate { projectNamespaceFix(this) }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
