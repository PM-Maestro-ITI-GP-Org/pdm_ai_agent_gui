# pdm_app_core

What every app in the PdM toolchain shares: the palette, a message bus, the app
registry, and the MQTT broker address.

Consumed as a submodule by [PdM-Maestro_gui](https://github.com/PM-Maestro-ITI-GP-Org/PdM-Maestro_gui)
and by each app repo. QML module URI: **`PdM.Core`**.

## Build

```bash
cmake -B build -DCMAKE_PREFIX_PATH=$HOME/Qt/6.10.3/gcc_64
cmake --build build -j$(nproc)
ctest --test-dir build --output-on-failure
```

Qt 6.5+, CMake 3.21+.

## What's in it

| | |
|---|---|
| `Theme` | The palette, type scale and metrics. A QML singleton. |
| `MessageBus` | Topic-based publish/subscribe, so apps talk without depending on each other. |
| `BusSubscription` | Declarative subscription for QML. |
| `AppRegistry` | The list of tabs and which have an app behind them. A list model. |
| `BrokerSettings` | The MQTT broker address, and unique client ids. |

## What is deliberately not in it

**The MQTT client.** The two apps ship different implementations — 690 lines
against 1421, different topic trees, different QoS, one threaded and one not —
and merging them would rewrite two working clients for no gain the shell can
see. Only the broker *address* is shared.

**The shared controls.** `AppCard`, `FilledButton` and `StatusPill` exist in
both apps under the same names but have diverged into different APIs
(`FilledButton` is 155 lines in one and 47 in the other). Consolidating them is
a separate job from Phase 1 and is best done once both apps are visible side by
side in the shell.

## Using it

From QML:

```qml
import PdM.Core

Rectangle {
    color: Theme.surface
    BusSubscription {
        topic: "recording.finished"
        onReceived: (payload) => reload(payload.path)
    }
}
```

From C++:

```cpp
#include "messagebus.h"
PdM::MessageBus::instance()->publish("recording.finished", {{ "path", path }});
```

Consumers add it with a guard, because in a Maestro build it is reached both
directly and through each app's own submodule:

```cmake
if(NOT TARGET pdm_core)
    add_subdirectory(core)
endif()
```

Static QML modules also need an explicit import from the executable that links
them, or the types resolve at build time and are missing at runtime:

```cpp
#include <QtQml/qqmlextensionplugin.h>
Q_IMPORT_QML_PLUGIN(PdM_CorePlugin)
```
