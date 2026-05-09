<!-- GSD:project-start source:PROJECT.md -->
## Project

**QAudit**

App Flutter para realização de auditorias industriais em campo. Auditores executam checklists configuráveis por template, registrando respostas por item com cálculo automático de conformidade ponderada. O backend é Supabase (auth, banco, RLS) e o app suporta múltiplas empresas com RBAC por perfil.

**Core Value:** Nenhum dado de auditoria preenchido em campo deve ser perdido — save silencioso ou falha de rede não pode comprometer o trabalho do auditor.

### Constraints

- **Stack**: Flutter + Dart + Supabase — sem trocar de stack nesta milestone
- **Estado**: Sem introduzir BLoC/Riverpod/Provider nesta milestone — refactor de estado é trabalho futuro separado
- **DB**: Migrações devem seguir padrão idempotente já estabelecido
- **Compatibilidade**: Não quebrar fluxos existentes (criação/execução/encerramento de auditorias)
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Dart `>=3.11.4 <4.0.0` - All application logic (`primeaudit/lib/`)
- SQL (PostgreSQL dialect) - Database migrations (`primeaudit/supabase/migrations/`, `primeaudit/lib/supabase/migrations/`)
- Kotlin (Android host shell) - `primeaudit/android/app/src/main/kotlin/com/example/primeaudit/`
- XML - Android manifest and resources (`primeaudit/android/app/src/main/`)
## Runtime
- Flutter `>=3.38.4` (locked in `pubspec.lock`)
- Dart SDK `>=3.11.4 <4.0.0`
- `pub` (Flutter's built-in package manager)
- Lockfile: `primeaudit/pubspec.lock` — present and committed
## Frameworks
- `flutter` SDK — Cross-platform UI framework; Material 3 design system enabled (`uses-material-design: true` in `pubspec.yaml`)
- `ValueNotifier<ThemeMode>` (global `appThemeMode` in `primeaudit/lib/main.dart`) — lightweight reactive state for theme switching
- `StreamBuilder<AuthState>` — drives the authentication gate in `primeaudit/lib/main.dart`
- No third-party state management library (no Riverpod, BLoC, Provider, etc.)
- `flutter_test` SDK — standard Flutter test framework
- No additional test packages declared
- `flutter_lints` `^6.0.0` (resolved `6.0.0`) — lint ruleset extending `package:flutter_lints/flutter.yaml`
- Gradle `8.14` (Android build system, `primeaudit/android/gradle/wrapper/gradle-wrapper.properties`)
- Java 17 compile target (`primeaudit/android/app/build.gradle.kts`)
- Dart DevTools — `primeaudit/devtools_options.yaml` present
## Key Dependencies
| Package | Resolved Version | Purpose |
|---------|-----------------|---------|
| `supabase_flutter` | `2.12.2` | Primary backend SDK — auth, database, storage, realtime |
| `shared_preferences` | `2.5.5` | Local persistence for theme, settings, and company context |
| `cupertino_icons` | `1.0.9` | iOS-style icon set for Material widgets |
| Package | Resolved Version | Role |
|---------|-----------------|------|
| `supabase` | `2.10.4` | Core Supabase Dart client (wrapped by `supabase_flutter`) |
| `postgrest` | `2.6.0` | PostgREST query builder — all database calls use this |
| `gotrue` | `2.19.0` | Supabase Auth client (email/password, session management) |
| `realtime_client` | `2.7.1` | Supabase Realtime (WebSocket subscriptions) |
| `storage_client` | `2.5.1` | Supabase Storage client (included but not actively used in app code) |
| `functions_client` | `2.5.0` | Supabase Edge Functions client (included but not actively used in app code) |
| `app_links` | `7.0.0` | Deep link / OAuth redirect handling (required by `supabase_flutter`) |
| `dart_jsonwebtoken` | `3.4.0` | JWT parsing for Supabase tokens |
| `http` | `1.6.0` | HTTP client used internally by Supabase packages |
| `web_socket_channel` | `3.0.3` | WebSocket support for Realtime |
| `rxdart` | `0.28.0` | Reactive streams (used internally by Supabase packages) |
| `url_launcher` | `6.3.2` | Opens external URLs (OAuth, magic links) |
| `path_provider` | `2.1.5` | File system path access |
| `pointycastle` | `4.0.0` | Cryptographic primitives for JWT handling |
## Configuration
- Supabase URL and anon key are hardcoded as Dart constants in `primeaudit/lib/core/supabase_config.dart`
- No `.env` file — credentials are compiled into the binary (anon key is designed to be public per Supabase's model)
- Theme preference stored under key `settings_theme` in `SharedPreferences`
- Company context for superuser/dev roles stored under keys `ctx_company_id` / `ctx_company_name` in `SharedPreferences`
- `primeaudit/pubspec.yaml` — Flutter package manifest
- `primeaudit/analysis_options.yaml` — Dart static analysis config
- `primeaudit/android/app/build.gradle.kts` — Android Gradle config
- `primeaudit/android/build.gradle.kts` — Android root Gradle config
## Platform Targets
- Android: `primeaudit/android/` — Gradle 8.14, Java 17, `compileSdk` from Flutter defaults
- iOS: `primeaudit/ios/` — Xcode project present
- `primeaudit/macos/`, `primeaudit/web/` — Flutter scaffold directories present; no custom platform code
- Flutter `>=3.38.4` and Dart `>=3.11.4` required
- Android Studio or VS Code with Dart/Flutter extensions
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Linting and Static Analysis
- Extends `package:flutter_lints/flutter.yaml` (the standard Flutter recommended ruleset)
- No custom rules are enabled or disabled — the file uses the default configuration with commented-out examples
- No `prefer_single_quotes` rule is enforced (commented out), so the codebase uses double quotes throughout
- No `avoid_print` override — the Flutter lints default applies
## Naming Conventions
- `snake_case` for all Dart files: `audit_execution_screen.dart`, `company_context_service.dart`, `app_theme.dart`
- Screens are suffixed `_screen.dart`; services are suffixed `_service.dart`; models have no suffix
- Admin screens live in a subdirectory and still follow the same pattern: `screens/admin/companies_tab.dart`
- `PascalCase` for all public classes: `AuditService`, `AppUser`, `TemplateSection`
- Private widget helpers within a file use `_PascalCase`: `_AuditCard`, `_InfoGrid`, `_NewAuditSheet`, `_PerimeterTreeStep`
- State classes follow Flutter convention: `_LoginScreenState` (private, appending `State` to the widget name)
- `camelCase` for all methods: `getAudits()`, `upsertAnswer()`, `calculateConformity()`
- Private methods prefix with `_`: `_load()`, `_buildHeader()`, `_confirmEncerrar()`, `_snack()`
- Builder methods are prefixed `_build`: `_buildBody()`, `_buildSearchAndFilters()`, `_buildStepContent()`
- Loader methods are named `_load()` or `_loadX()`: `_loadProfile()`, `_loadSheetData()`, `_loadTemplates()`
- `camelCase` for all locals and fields
- Private state fields prefixed with `_`: `_isLoading`, `_audits`, `_formKey`
- Controller fields are `_xCtrl` or `_xController`: `_emailController`, `_searchCtrl`
- Service instances in widgets: `final _auditService = AuditService()`
- Constants use `_keyX` pattern for SharedPreferences keys: `static const _keyEmail = 'saved_email'`
- `PascalCase` for enum types: `AuditStatus`, `_AuditFilter`
- Enum values use `camelCase` (Dart 2.17+ enhanced enums): `emAndamento`, `concluida`, `atrasada`
- Private screen-local enums prefix with `_`: `_AuditFilter`
## Code Organization Within Files
## State Management Pattern
- `StatefulWidget` + `setState()` for local screen state (loading, error, data lists, form fields)
- `ValueNotifier<ThemeMode>` for global theme state — declared at top level in `lib/main.dart`:
- `StreamBuilder<AuthState>` in `_AuthGate` to react to Supabase auth changes
- `CompanyContextService` singleton for cross-screen company context (not a proper reactive solution — screens call `CompanyContextService.instance.activeCompanyId` imperatively)
## Services Layer
- Holds a `final _client = Supabase.instance.client` reference
- Exposes `Future<T>` methods for CRUD operations
- Handles Supabase queries using the `supabase_flutter` fluent API
- Does not handle exceptions internally — callers are responsible for try/catch
- `getX()` / `getXById()` — read operations
- `createX()` — insert
- `updateX()` — update
- `deleteX()` — delete
- `upsertX()` — upsert (used in `AuditAnswerService`)
- `calculateX()` — pure computation (e.g., `calculateConformity()` in `AuditAnswerService`)
## Model Pattern
- Has a `const` or regular constructor with required/optional named parameters
- Implements `factory XModel.fromMap(Map<String, dynamic> map)` for deserialization from Supabase rows
- Does NOT implement `toMap()` (serialization is done inline in service methods)
- May carry computed getters (e.g., `Audit.isOverdue`, `AppUser.canAccessAdmin`, `AuditTemplate.isGlobal`)
- May carry display getters returning `String`, `Color`, or `IconData` (e.g., `AuditStatus.label`, `AuditStatus.color`, `AuditStatus.icon`)
## Theming Pattern
## Error Handling Pattern
- `ScaffoldMessenger.of(context).showSnackBar(...)` with `SnackBarBehavior.floating` — short messages
- Inline error widget in the body with a retry button — for list/load failures
## UI Patterns
## Singleton Pattern
## Dart Language Features Used
- Enhanced enums (Dart 2.17+) with methods and getters: `AuditStatus` in `lib/models/audit.dart`
- `extension` on enums for UI labels: `extension _AuditFilterLabel on _AuditFilter`
- `Future.wait([...])` for parallel async operations
- Named parameters everywhere (`required` for mandatory, optional with `?` type)
- Null-aware operators (`?.`, `??`, `??=`) used throughout
- `switch` expressions without `break` (enhanced switch in Dart 3): used in enum getter bodies
- No `async*` / `yield` / streams in application logic (only Supabase's `onAuthStateChange` stream is consumed)
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- Screens own local service instances; no shared DI / provider
- All remote data access goes through dedicated service classes that wrap `Supabase.instance.client`
- Models are plain Dart classes with `fromMap` factory constructors (no code generation)
- State management is local `setState`; no BLoC, Riverpod, or Provider
- RBAC is enforced in the UI layer via `AppRole` helpers; backend enforcement relies on Supabase RLS policies
## Layers
- Purpose: UI rendering, local ephemeral state, user interaction
- Location: `primeaudit/lib/screens/`
- Contains: `StatefulWidget` screens, private sub-widgets (underscore-prefixed classes defined in the same file)
- Depends on: services, models, `core/`
- Used by: navigation calls from other screens
- Purpose: Supabase CRUD operations, business logic helpers (conformity calculation, auth checks)
- Location: `primeaudit/lib/services/`
- Contains: plain Dart classes, each wrapping one domain concept; no base class
- Depends on: `supabase_flutter`, models
- Used by: screens
- Purpose: Typed representations of database rows; value parsing; domain enums
- Location: `primeaudit/lib/models/`
- Contains: immutable data classes, `fromMap` factories, domain enums with display helpers
- Depends on: nothing (pure Dart + Flutter `material.dart` for `Color`/`IconData`)
- Used by: services, screens
- Purpose: App-wide constants, theming, role definitions
- Location: `primeaudit/lib/core/`
- Contains: `AppColors`, `AppTheme`, `AppRole`, `SupabaseConfig`
- Depends on: nothing except Flutter
- Used by: all other layers
## Data Flow
## Key Abstractions
- Purpose: Centralized role constants and permission checks
- Roles: `superuser`, `dev`, `adm`, `auditor`, `anonymous`
- Key methods: `canAccessAdmin(role)`, `isSuperOrDev(role)`, `canAccessDev(role)`
- Used in: `HomeScreen` (drawer item visibility), `CompanyContextService` (company switching), `UsersTab` (role assignment)
- Purpose: Singleton tracking the active company context for data-scoped queries
- `superuser`/`dev` roles may switch companies; other roles are locked to their `profile.company_id`
- Persisted via `SharedPreferences` keys `ctx_company_id` / `ctx_company_name`
- Consumed by: `AuditsScreen`, `_NewAuditSheet`, any screen needing scoped company queries
- `AuditType` → `AuditTemplate` → `TemplateSection` → `TemplateItem`
- Managed by `AuditTemplateService` (`primeaudit/lib/services/audit_template_service.dart`)
- Templates can be global (`company_id IS NULL`) or company-specific; queries always include both via `.or('company_id.is.null,company_id.eq.$companyId')`
- Purpose: Typed color token object resolved at build time from `BuildContext`
- Usage: `final t = AppTheme.of(context);` then `t.background`, `t.surface`, `t.textPrimary`, etc.
- Does not replace Flutter's `ThemeData`; supplements it with semantic tokens
## Entry Points
- Location: `primeaudit/lib/main.dart`
- Triggers: Flutter engine startup
- Responsibilities: Supabase init, theme restore from `SharedPreferences`, run `QAuditApp`
- Location: `_AuthGate` class in `primeaudit/lib/main.dart`
- Triggers: Supabase auth state stream
- Responsibilities: Route to `HomeScreen` or `LoginScreen` based on session
- Location: `primeaudit/lib/screens/home_screen.dart`
- Triggers: Successful authentication
- Responsibilities: Load user profile, init `CompanyContextService`, render drawer navigation, dashboard placeholders
## Error Handling
- Service calls wrapped in `try/catch` inside async methods; errors surfaced via `setState(() => _error = '...')` or `ScaffoldMessenger.showSnackBar`
- Loading states tracked with boolean flags (`_isLoading`, `_loading`, `_finalizing`) toggled around async calls
- Auth deactivation throws `AuthException` from `AuthService.signIn`; caller handles it in the login form
- Answer auto-save (`_saveAnswer` in `AuditExecutionScreen`) fails silently — catch block is empty — to avoid disrupting the UI mid-audit
## Cross-Cutting Concerns
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
