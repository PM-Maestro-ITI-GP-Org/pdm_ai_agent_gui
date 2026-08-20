#
# Declares this repository as a PdM Maestro app.
#
# Maestro's top-level CMakeLists.txt compiles an app in only when this file is
# present. The variables below are read by Maestro; nothing here uses them.
#
set(PDM_APP_ID       "agent")
set(PDM_APP_TARGET   "pdm_agent")
set(PDM_APP_PLUGIN   "pdm_agentplugin")
set(PDM_APP_QML_URI  "PdM.Agent")

# The macro Maestro's main.cpp checks before calling registerWithShell().
set(PDM_APP_DEFINE   "PDM_HAVE_AGENT")
