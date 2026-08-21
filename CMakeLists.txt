#
# pdm_ai_agent_gui -- the AI Agent app.
#
# Written against the integration contract from the start, same shape as
# pdm_mlops_gui (see docs/INTEGRATION_CONTRACT.md and that repo's
# CMakeLists.txt, which this one deliberately mirrors).
#
# Builds two ways and both matter:
#
#   * on its own: cmake -B build && ./build/agent_gui
#   * as a library inside PdM-Maestro_gui, where it becomes the AI Agent tab
#
# A0/A1 need no AI runtime at all -- see docs/SCOPE.md. Nothing here pulls in
# a model, a vector store or a network client yet; that stays true for as
# long as the phase plan does.
#
cmake_minimum_required(VERSION 3.21)

project(PdMAiAgent
    VERSION 0.1.0
    DESCRIPTION "Developer assistant for the PdM toolchain"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick Qml Widgets QuickControls2 Network)

qt_standard_project_setup(REQUIRES 6.5)

# The palette, message bus and app registry. Carried as a submodule so this
# repo still builds when cloned on its own; the guard stops it being added a
# second time inside a Maestro build, where Maestro has already added its own
# pinned copy and both would claim the PdM.Core module URI.
if(NOT TARGET pdm_core)
    add_subdirectory(core)
endif()

#
# ---- the app, as a library --------------------------------------------------
#
qt_add_library(pdm_agent STATIC)

# Main.qml is deliberately not in this list: it belongs to the standalone
# executable's module further down, because a file that imports PdM.Agent
# cannot also be a member of it.
qt_add_qml_module(pdm_agent
    URI PdM.Agent
    VERSION 1.0
    SOURCES
        agentapp.h
        agentapp.cpp
        src/agentclient.h
        src/agentclient.cpp
    QML_FILES
        AgentPage.qml
        ChatView.qml
        SystemMapView.qml
        LifecycleView.qml
        SettingsView.qml
        RepoCard.qml
        StageCard.qml
)

# So the shell can reach agentapp.h to call registerWithShell().
target_include_directories(pdm_agent PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
)
target_include_directories(pdm_agent PRIVATE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
)

target_link_libraries(pdm_agent PUBLIC
    pdm_core
    Qt6::Quick
    Qt6::Qml
    Qt6::Widgets
    Qt6::QuickControls2
    Qt6::Network
)

#
# ---- the standalone app -----------------------------------------------------
#
if(PROJECT_IS_TOP_LEVEL)
    qt_add_executable(agent_gui main.cpp)

    qt_add_qml_module(agent_gui
        URI AgentGuiApp
        VERSION 1.0
        QML_FILES Main.qml
    )

    # Both halves of each static QML module: the library carries the types,
    # the plugin carries the registration Q_IMPORT_QML_PLUGIN refers to.
    target_link_libraries(agent_gui PRIVATE
        pdm_agent
        pdm_agentplugin
        pdm_core
        pdm_coreplugin
    )

    install(TARGETS agent_gui RUNTIME DESTINATION bin)
endif()
