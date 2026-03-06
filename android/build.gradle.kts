allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// FIX: Point to the correct Flutter build directory (one level up from android/)
val newBuildDir = rootProject.layout.projectDirectory.dir("../build")
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
subprojects {
    tasks.configureEach {
        if (name.contains("generateDebugUnitTestConfig") || name.contains("generateReleaseUnitTestConfig")) {
            enabled = false
        }
    }
}