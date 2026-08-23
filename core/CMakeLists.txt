#
# pdm_app_core -- what every PdM app shares.
#
# This is a library and nothing else: no window, no main(). It is pulled in
# three ways, and all three have to work.
#
#   1. by PdM-Maestro_gui, alongside the four app libraries
#   2. by an app repo building standalone, as its own submodule
#   3. directly, to run the smoke test below
#
# Case 2 is why this is a separate repository rather than a directory inside
# Maestro. An app that resolves its palette through PdM.Core has to be able to
# reach PdM.Core when someone clones just that app and builds it, or "every app
# still builds on its own" quietly stops being true.
#
# Cases 1 and 2 together mean core gets added twice in a Maestro build: once by
# Maestro, once by each app that carries it as a submodule. The guard belongs in
# the CONSUMER, not here -- every consumer writes:
#
#     if(NOT TARGET pdm_core)
#         add_subdirectory(core)
#     endif()
#
# so Maestro's pinned core wins and the nested checkouts are simply not visited.
# The apps therefore have to tolerate the core commit Maestro chooses, which is
# the ordinary cost of a shared library and the reason to keep this small.
#
cmake_minimum_required(VERSION 3.21)

project(PdMCore
    VERSION 0.1.0
    DESCRIPTION "Shared palette, message bus and app registry for the PdM toolchain"
    LANGUAGES CXX
)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick Qml)

qt_standard_project_setup(REQUIRES 6.5)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

qt_add_library(pdm_core STATIC)

# Must precede qt_add_qml_module -- the property is read when the qmldir is
# generated. Flagged here and `pragma Singleton` in the file itself: a mismatch
# between the two is fatal at load time, not a warning.
set_source_files_properties(Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

# Theme.qml sits at the repository root rather than in qml/. A QML file in a
# subdirectory needs its own generated qmldir (policy QTP0004) and resolves
# under a sub-namespace; for a module this small, the root is simpler than the
# alternative.
qt_add_qml_module(pdm_core
    URI PdM.Core
    VERSION 1.0
    SOURCES
        src/messagebus.h
        src/messagebus.cpp
        src/appregistry.h
        src/appregistry.cpp
        src/brokersettings.h
        src/brokersettings.cpp
        src/safetystop.h
        src/safetystop.cpp
    QML_FILES
        Theme.qml
)

target_include_directories(pdm_core PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
)

target_link_libraries(pdm_core PUBLIC
    Qt6::Quick
    Qt6::Qml
)

#
# Standalone only. Maestro and the app repos add_subdirectory() this file, where
# PROJECT_IS_TOP_LEVEL is false and none of the below is built.
#
if(PROJECT_IS_TOP_LEVEL)
    qt_add_executable(pdm_core_smoke test/smoke.cpp)
    # The plugin as well as the library: the smoke test creates a QML object
    # that imports PdM.Core, and a static QML module needs both halves.
    target_link_libraries(pdm_core_smoke PRIVATE pdm_core pdm_coreplugin)

    enable_testing()
    add_test(NAME smoke COMMAND pdm_core_smoke)
endif()
