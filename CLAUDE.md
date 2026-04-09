# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Domovnik** is a Slovak property management app ("building custodian") for residents and building managers. Built with Flutter targeting mobile and web.

## Common Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run app (select device when prompted)
flutter run -d chrome    # Run as web app
flutter test             # Run all tests
flutter test test/path/to_test.dart  # Run single test
flutter analyze          # Lint (flutter_lints + riverpod_lint)
dart run build_runner build --delete-conflicting-outputs  # Regenerate Riverpod providers
```

## Environment Setup

Copy `.env.example` to `.env` and fill in Supabase credentials. Run the three database migrations described in `MIGRATION_INSTRUCTIONS.md` against your Supabase project before first run.

## Architecture

Feature-driven clean architecture: `lib/features/<feature>/{data,models,presentation}/`

Each feature is self-contained:
- `models/` — immutable data classes with `.fromJson()`, `.toJson()`, `.copyWith()`, and enums with `.label` for Slovak display strings
- `data/` — repository classes that wrap Supabase calls directly
- `presentation/` — `providers/` (Riverpod) + `screens/` (Flutter widgets)

`lib/core/` holds cross-cutting concerns: theme, color constants (`app_colors.dart`), Supabase table/column name constants (`supabase_constants.dart`), and utilities.

`lib/shared/` holds reusable widgets used across features.

## State Management (Riverpod)

- **Read-only data:** `StreamProvider.family<List<T>, String>` — wraps `.stream()` on Supabase tables for real-time subscriptions keyed by building ID
- **Mutations:** `AsyncNotifierProvider` — create/update/delete operations
- **Root state:** `profileProvider` (AsyncNotifier) — drives role-based routing and permission checks throughout the app

Profile is authoritative: manager vs. resident role determines which shell route the user sees.

## Navigation (GoRouter)

Two shell routes in `lib/router/`:
- **ResidentShell** — bottom nav: Announcements → Tickets → Forum → Polls → More
- **ManagerShell** — bottom nav: Dashboard → Announcements → Tickets → Forum → More

Route guards redirect to `/login` if unauthenticated, and to the correct shell based on `profile.isManager`. On desktop (width > 600px), a `NavigationRail` replaces the bottom nav bar.

## Backend (Supabase)

All data access goes through repository classes using `SupabaseClient`. Key patterns:
- Real-time: `.from(table).stream(primaryKey: ['id']).eq('building_id', id)`
- Joins: `.select('*, profiles(full_name)')` for denormalized display data
- File uploads: Supabase storage bucket `tickets/` for ticket photos
- Profile bootstrap: if post-auth profile is missing, repository calls RPC `handle_user_signup()` as fallback for trigger race conditions

Firebase FCM is optional — initialization failures are caught and logged but don't crash the app.

## Localization

The app is fully in Slovak (`sk_SK`). All UI strings, enum labels, and status text are hardcoded in Slovak. There is no i18n abstraction — string changes should be made directly in the relevant widget or model.
