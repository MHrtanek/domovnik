# Domovník

[![CI](https://github.com/MHrtanek/domovnik/actions/workflows/ci.yml/badge.svg)](https://github.com/MHrtanek/domovnik/actions/workflows/ci.yml)

**A property-management app for Slovak apartment buildings — connecting residents, building managers, and suppliers in one place.**

Domovník ("building custodian") digitises the day-to-day running of a residential building: reporting maintenance issues, posting announcements, running votes, booking shared amenities, and keeping documents and contacts in one place. It is a Flutter app targeting **web and Android** from a single codebase, backed by Supabase.

## Live demo

| | URL |
|---|---|
| **App** | https://domovnik.online |
| **Landing page** | https://domovnik-landing.vercel.app |

> Want to look around without signing up? The login screen has a **"Try demo"** button that signs you into a pre-seeded building with realistic data.

## Screenshots

| Dashboard | Tickets | Announcements |
|---|---|---|
| ![Dashboard](docs/screenshots/dashboard.png) | ![Tickets](docs/screenshots/tickets.png) | ![Announcements](docs/screenshots/announcements.png) |

| Polls | Chat | Building plan |
|---|---|---|
| ![Polls](docs/screenshots/polls.png) | ![Chat](docs/screenshots/chat.png) | ![Building plan](docs/screenshots/building_plan.png) |

_Screenshots live under `docs/screenshots/`._

## Tech stack

| Layer | Technology |
|---|---|
| **Client** | Flutter (web + Android) |
| **State management** | Riverpod |
| **Navigation** | GoRouter (role-based shell routes) |
| **Backend** | Supabase — Postgres, Auth, Realtime, Storage, Edge Functions |
| **Push notifications** | Firebase Cloud Messaging via a Supabase Edge Function |
| **Transactional email** | Resend (feedback + notifications) |
| **Hosting** | Vercel (Flutter web build + landing page) |

## Features by role

Domovník has three roles, each with its own navigation shell.

### 🏠 Resident
- **Tickets** — report maintenance issues with photos and category, track status (Prijaté → V riešení → Ukončené)
- **Announcements** — read building-wide announcements, with urgent flagging
- **Forum** — neighbourhood discussion threads with replies and likes
- **Polls** — vote in building decisions and see live results
- **Chat** — direct messaging with the manager (realtime)
- **Reservations** — book shared amenities (e.g. common room, laundry)
- **Contacts & Documents** — building contact directory and shared files
- **Inspections, House rules, Building plan** — reference information
- **Feedback** — send product feedback directly to the team

### 🛠️ Manager
- Everything a resident sees, **plus**:
- **Dashboard** — overview of open tickets and building activity
- **Ticket management** — change status, assign a supplier
- **Create** announcements and polls, post to the forum
- **Residents & Building units** — manage who lives where
- **Suppliers** — invite and manage external suppliers
- Manage contacts, documents, inspections, house rules, and the building plan

### 🔧 Supplier
- **Tickets** — see and work the tickets assigned to them
- **Profile** — a focused, two-tab shell (no resident/manager drawer)

## Project structure

Feature-first clean architecture — each feature owns its models, data layer, and presentation.

```
lib/
├── main.dart                 # bootstrap: dotenv, Supabase.initialize, Firebase, FCM
├── app.dart                  # MaterialApp.router + auth-state listener
├── core/                     # cross-cutting concerns
│   ├── constants/            # colors, Supabase table/column names
│   ├── services/             # notification + sound services
│   ├── theme/                # app theme
│   └── utils/                # validators, helpers
├── router/
│   └── app_router.dart       # GoRouter + Resident/Manager/Supplier shells
├── shared/
│   └── widgets/              # reusable widgets
└── features/<feature>/
    ├── models/               # immutable data classes (fromJson/toJson/copyWith)
    ├── data/                 # repository classes wrapping Supabase
    └── presentation/
        ├── providers/        # Riverpod providers
        └── screens/          # Flutter widgets

supabase/
├── migrations/               # SQL schema migrations
├── functions/                # Edge Functions (send-notification, send-feedback-email)
└── seed_demo.sql             # demo data for the "Try demo" account
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for a deeper walkthrough of the data flow, routing, database schema, and push-notification pipeline.

## Getting started

### Prerequisites
- Flutter SDK (Dart `>=3.3.0 <4.0.0`)
- A Supabase project

### Setup

```bash
# 1. Install dependencies
flutter pub get

# 2. Configure environment
cp .env.example .env
# then fill in your Supabase credentials in .env

# 3. Apply the database migrations
#    Run the SQL files in supabase/migrations/ (in order) against your
#    Supabase project — via the SQL editor or the Supabase CLI.

# 4. (Optional) Seed demo data for the "Try demo" button
#    Run supabase/seed_demo.sql in the Supabase SQL editor.

# 5. Run
flutter run -d chrome      # web
flutter run                # mobile (select a device)
```

### Environment variables

`.env` (see [`.env.example`](.env.example)):

| Key | Purpose |
|---|---|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase anon/public key |
| `DEMO_EMAIL` | Email for the "Try demo" login |
| `DEMO_PASSWORD` | Password for the "Try demo" login |

### Common commands

```bash
flutter analyze      # lint (flutter_lints + riverpod_lint)
flutter test         # run tests
flutter build web --release
dart run build_runner build --delete-conflicting-outputs   # regenerate Riverpod providers
```

## Engineering decisions

A few choices worth calling out, and why they were made.

### Supabase + Row-Level Security
Rather than build and host a bespoke API, data access goes directly from the Flutter client to Postgres through Supabase, with **Row-Level Security (RLS) as the authorization boundary**. Every table is scoped by `building_id` and role via SQL policies (`auth_building_id()`, `auth_role()` helpers), so a resident physically cannot read or write another building's data — the rules live next to the data, not in client code that could be bypassed. This keeps the client thin and pushes correctness into the database, while Supabase Realtime gives live updates "for free" on top of the same tables.

### Feature-first architecture
Code is organised by **feature** (`tickets`, `polls`, `chat`, …) rather than by technical layer. Each feature is a self-contained slice — `models/ → data/ → presentation/` — so a feature can be understood, changed, or removed in isolation, and the structure scales as the number of features grows (there are 20+). Cross-cutting concerns live in `core/` and genuinely shared widgets in `shared/`.

### Role-based shell routes
The app has three distinct audiences, so GoRouter is configured with **three `ShellRoute`s** — Resident, Manager, and Supplier — each with its own navigation. The authoritative `profileProvider` (role + building) drives a redirect guard that routes a user into the correct shell and keeps them out of screens they shouldn't see. On wide screens the bottom navigation bar is swapped for a `NavigationRail`, so the same routes adapt from phone to desktop web.

### Push notifications via an Edge Function
Clients never hold privileged credentials. To send a push, the app calls the **`send-notification` Supabase Edge Function**, which runs server-side with the service-role key, looks up the recipients' FCM tokens, and dispatches via Firebase Cloud Messaging. Notifications carry a `route` payload so a tap deep-links straight to the relevant screen (a ticket whose status changed, a new chat message). This keeps secrets off the device and centralises the notification logic in one auditable place.

## License

This project is part of a personal portfolio.
