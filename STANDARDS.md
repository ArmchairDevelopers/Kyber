# Table of Contents

- [Module](#module)
- [Launcher](#launcher)

## Module Code Standards <a name="module"></a>

### Module General Rules

- Generally follow Cpp11 standards & everything in the .clang-format
- Brackets must be attached to any statements that can have them (ex `if`s, `for`s, etc. No one-lining)
- Always put a newline after a block (after a })
- Always use guards instead of nesting
- Prefix `g_` for global variables (ex `g_program`).
- Prefix `m_` for owned member variables in module classes. *Note: this does not apply to game structs.*
- All `#defines` should be capitalized snake case.
- Use `_t` primitive types whenever possible
- Inline arrays when short enough
- If you are ever unsure of how to format just apply clang format

#### Hooks

- All hooked functions with the hook manager should have the suffix `Hk`
- All trampolines should be formatted `static const auto trampoline = HookManager::Call(funcName);`
- All `TL_DECLARE_FUNC`s should be named as `ClassName_functionName` or `functionName` if not given a class
- Do not use repeat hooked functions, instead move them to files where they are more shared

### Guidelines

- Avoid C-style casting wherever possible
- Use EASTL types whenever they can replace std library functions (ex `eastl::vector` & `eastl::string`)
- Very rarely should you ever use the general std heap alloc `new`, you should generally always use the game's memory arenas to be as safe as possible
  - Ensure the arena you are using actually makes sense for the case. You should not be allocating stuff into the server arena when in the client and vice versa.
  - Examples:
    - `Class* serverAllocatedClass = new (FB_SERVER_ARENA->alloc(sizeof(Class))) Class(args);`
    - `reasonText = StringUtils::CopyWithArena("Timed out.", FB_CLIENT_ARENA);`
- Use the `ThreadExecutor` whenever you are interacting with any game logic when not in the main game threads
  - Example: `g_threadExecutor->Queue(GameThread_Server, [this, cmd]() { g_program->m_console->EnqueueCommand(cmd) });`
- Use `Mutex<>` on fields that may be accessed from multiple threads
  - Example usage: `MutexGuard<LoadLevelRequest> requestGuard = s_program->m_server->m_latestLoadLevelRequest.Lock();`

------

## Launcher Code Standards (Flutter/Dart) <a name="launcher"></a>

### Project Structure

The launcher follows a **feature-based architecture**:

```text
lib/
  core/                      # Shared application infrastructure
    config/                  # App-wide configuration (colors, strings, locales)
    i18n/                    # Internationalization
    routing/                 # App router configuration
    services/                # Core services (storage, window, etc.)
    utils/                   # Utilities and extensions
  features/                  # Feature modules
    <feature>/
      dialogs/               # Feature-specific dialogs
      helper/                # Feature-specific utilities
      models/                # Data models and types
      providers/             # Cubits (state management)
      screens/               # Full-page widgets
      services/              # Business logic
      widgets/               # Reusable UI components
  shared/                    # Shared UI components
    ui/
      buttons/
      cards/
      elements/
  main.dart
```

### Launcher General Rules

- Follow the [Effective Dart](https://dart.dev/effective-dart) style guide
- Use `dart format` for consistent formatting
- Prefer `const` constructors wherever possible
- Avoid deeply nested widget trees - extract private widgets or helper methods

### Naming Conventions

| Type | Convention | Example |
| ------ | ---------------- | -------------------- |
| Cubits | `<Feature>Cubit` | `ServerBrowserCubit` |
| Cubit States | `<Feature>State`, `<Feature><Variant>` | `KyberStatusState`, `KyberStatusPlaying` |
| Services | `<Feature>Service` | `ModService`, `VoipService` |
| Helpers | `<Feature>Helper` | `MaximaHelper`, `StorageHelper` |
| Private Widgets | `_<Widget>` | `_HeaderBar`, `_StatusWidget` |
| Screens | `<Feature>` | `ServerBrowser`, `Settings` |

### State Management

#### Cubits

- Place cubits in the `providers/` folder with `_cubit.dart` suffix
- Define state classes in the same file as the cubit
- Keep cubits focused on a single responsibility

#### BlocBuilder/BlocListener

- Use `BlocBuilder` for rebuilding UI based on state
- Use `BlocListener` for side effects (navigation, dialogs, etc.)
- Access cubits via `context.read<T>()` for events, `context.watch<T>()` for reactive state

### Dependency Injection

- Use GetIt via the global `sl` instance
- Register services in `injection_container.dart`
- Use `registerSingleton` for immediate initialization
- Use `registerSingletonAsync` for async initialization
- Check registration with `sl.isRegistered<T>()` before access when appropriate

### Assets

- Use generated asset classes from `gen/assets.gen.dart`
- Access via `Assets.icons.<name>`, `Assets.images.<name>`, etc.
