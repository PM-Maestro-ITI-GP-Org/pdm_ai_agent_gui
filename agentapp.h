#ifndef PDM_AGENT_APP_H
#define PDM_AGENT_APP_H

namespace PdM {
namespace Agent {

/*
 * Hands this app's page to the shell.
 *
 * Maestro's main.cpp calls this once, and the placeholder tab becomes the
 * real one. The app owns the URL rather than the shell hard-coding it, so
 * moving or renaming the page is a change inside this repository alone.
 */
void registerWithShell();

} // namespace Agent
} // namespace PdM

#endif // PDM_AGENT_APP_H
