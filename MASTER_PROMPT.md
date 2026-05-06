# MASTER_PROMPT.md — Domovník

> Komplexná dokumentácia projektu pre AI asistentov a nových vývojárov.
> Generované: 2026-05-06

---

## 1. Prehľad projektu

**Domovník** je slovenská B2B SaaS aplikácia pre správu bytových domov. Cieľom je digitalizovať komunikáciu medzi správcom budovy (`manager`) a obyvateľmi (`resident`), a umožniť správu dodávateľov (`dodavatel`).

- **Jazyk UI:** Slovenský (`sk_SK`) – všetky reťazce sú hardcoded v slovenčine, bez i18n abstrakcie
- **Cieľové platformy:** Web (primárne), Android, iOS (čiastočne)
- **Produkčná URL:** `https://domovnik.online`
- **Supabase projekt ID:** `pclawaxmilduvfkwhhge`
- **Firebase projekt:** `domovnik-e1e51`

---

## 2. Lokálne cesty

```
/Users/matthew/Projects/domovnik/          ← koreň projektu
├── lib/                                    ← Flutter zdrojový kód
│   ├── main.dart                           ← vstupný bod
│   ├── app.dart                            ← DomovnikApp widget
│   ├── router/app_router.dart              ← GoRouter konfigurácia
│   ├── core/
│   │   ├── constants/app_colors.dart       ← farebná paleta
│   │   ├── constants/supabase_constants.dart ← názvy tabuliek/bucketov
│   │   ├── services/notification_service.dart ← volanie Edge Function
│   │   ├── services/sound_service.dart     ← zvukové notifikácie (platform stub)
│   │   ├── theme/app_theme.dart            ← Material theme
│   │   └── utils/                          ← date_formatter, validators
│   ├── features/                           ← feature-driven architektúra
│   └── shared/widgets/                     ← zdieľané widgety
├── supabase/
│   ├── migrations/                         ← 16 SQL migrácií
│   └── functions/send-notification/        ← Deno Edge Function
├── assets/
│   └── logo_horizontal.png
├── icons/
│   ├── Icon-192.png
│   └── Icon-512.png
├── web/                                    ← Flutter web build output config
├── android/                                ← Android konfigurácia
├── .env                                    ← Supabase credentials (nie v gite)
├── CLAUDE.md                               ← Inštrukcie pre AI
├── MIGRATION_INSTRUCTIONS.md              ← Manuál pre migrácie
└── pubspec.yaml                            ← závislosti
```

---

## 3. Tech stack

| Vrstva | Technológia | Verzia |
|---|---|---|
| Framework | Flutter | ≥3.3.0 |
| Jazyk | Dart | ≥3.3.0 |
| Backend | Supabase (PostgreSQL + Auth + Storage + Realtime + Edge Functions) | supabase_flutter ^2.3.4 |
| State management | Riverpod | flutter_riverpod ^2.5.1 |
| Navigácia | GoRouter | ^13.2.0 |
| Notifikácie | Firebase Cloud Messaging | firebase_messaging ^14.7.19 |
| Lokálne notifikácie | flutter_local_notifications | ^17.1.2 |
| Obrázky | image_picker + cached_network_image | ^1.0.7 / ^3.3.1 |
| Súbory | file_picker | ^8.0.7 |
| HTTP | http | ^1.2.0 |
| ENV premenné | flutter_dotenv | ^5.1.0 |
| UUID | uuid | ^4.3.3 |
| Dátum/čas | intl | ^0.20.2 |
| Otváranie URL | url_launcher | ^6.3.1 |
| Perzistencia nastavení | shared_preferences | ^2.3.2 |
| Reaktívne streamy (chat) | rxdart | (tranzitívna závislosť) |
| Lint | flutter_lints + riverpod_lint | ^3.0.0 / ^2.3.10 |
| Generovanie kódu | build_runner + riverpod_generator | ^2.4.9 / ^2.4.0 |

---

## 4. Príkazy

### Vývoj

```bash
# Inštalácia závislostí
flutter pub get

# Spustenie (výber zariadenia)
flutter run

# Spustenie vo webovom prehliadači (Chrome)
flutter run -d chrome

# Spustenie na konkrétnom zariadení
flutter run -d <device-id>

# Lint
flutter analyze

# Testy
flutter test
flutter test test/path/to_test.dart

# Regenerácia Riverpod providerov
dart run build_runner build --delete-conflicting-outputs
```

### Deployment

```bash
# Build pre web
flutter build web --release

# Build pre Android APK
flutter build apk --release

# Build pre Android App Bundle (Google Play)
flutter build appbundle --release

# Deploy Edge Function do Supabase
supabase functions deploy send-notification --project-ref pclawaxmilduvfkwhhge

# Spustenie migrácií (cez Supabase SQL editor alebo CLI)
supabase db push --project-ref pclawaxmilduvfkwhhge
```

### Environment setup

1. Skopíruj `.env.example` → `.env`
2. Vyplň `SUPABASE_URL` a `SUPABASE_ANON_KEY`
3. Spusti všetkých 16 SQL migrácií zo `supabase/migrations/` v poradí

---

## 5. Architektúra

### Štruktúra feature modulu

```
lib/features/<feature>/
├── data/
│   └── <feature>_repository.dart     ← Supabase volania
├── models/
│   └── <feature>_model.dart          ← immutable dáta, fromJson/toJson/copyWith
└── presentation/
    ├── providers/
    │   └── <feature>_provider.dart   ← Riverpod state
    └── screens/
        └── <feature>_screen.dart     ← Flutter widgety
```

### State management vzory

- **Read-only realtime dáta:** `StreamProvider.family<List<T>, String>` — wraps `.stream()` na Supabase
- **Mutácie:** `AsyncNotifierProvider` — create/update/delete operácie
- **Koreňový stav:** `profileProvider` (AsyncNotifier) — riadi role-based routing

### Navigácia (GoRouter)

Dve shell trasy:
- **ResidentShell** — spodná nav: Oznamy → Tikety → Fórum → Ankety → Viac
- **ManagerShell** — spodná nav: Dashboard → Oznamy → Tikety → Fórum → Viac

Na desktop (šírka > 600px) sa používa `NavigationRail` namiesto spodnej lišty.

Route guards: presmerujú na `/login` ak nie je autentifikovaný, na správny shell podľa `profile.isManager`.

---

## 6. Implementované funkcie

### 6.1 Autentifikácia (`lib/features/auth/`)

- **Prihlásenie** — email + heslo, checkbox „Zapamätať ma" (via `shared_preferences` + `session_only` flag, odhlásenie pri cold-starte ak nie je zaškrtnuté)
- **Registrácia** — rozlíšenie rola/budova pri signup, RPC `handle_user_signup()` ako fallback pre trigger race condition
- **Reset hesla** — email flow cez Supabase Auth
- **Automatické obnovenie tokenu** — `autoRefreshToken: true`
- **Auth flow:** `implicit` (PKCE nie je použité)

### 6.2 Profil (`lib/features/profile/`)

Polia: `id`, `email`, `full_name`, `flat_number`, `phone`, `role`, `building_id`, `fcm_token`, `created_at`

Role:
- `manager` — správca budovy
- `resident` — obyvateľ
- `dodavatel` — dodávateľ/zhotoviteľ

Editovateľné: meno, číslo bytu, telefón.

### 6.3 Tikety (`lib/features/tickets/`)

- **Triedy závad (TicketCategory):** Vodoinštalácia, Elektrina, Výťah, Spoločné priestory, Iné
- **Stavy (TicketStatus):** Prijaté, V riešení, Ukončené
- **Viacero fotografií:** tabuľka `ticket_photos` (nové) + legacy pole `photo_url`
- **Priradenie dodávateľa:** manager môže priradiť dodávateľa (`supplier_id`)
- **Pohľady:** zoznam pre obyvateľa (vlastné tikety), správcu (všetky), dodávateľa (priradené)
- **Push notifikácie:** pri vytvorení tiketu sa odošle notifikácia celej budove
- **Upload fotiek:** Supabase Storage bucket `ticket-photos`, cesta `tickets/<uuid>.<ext>`

### 6.4 Oznamy (`lib/features/announcements/`)

- **Naliehavé oznamy** (`is_urgent: true`) — vizuálne odlíšené
- **Fotky** — upload do bucketu `ticket-photos`, cesta `announcements/<uuid>.<ext>`
- **Push notifikácie** — pri vytvorení
- **CRUD:** vytvoriť, zmazať (len manažér)
- **Realtime stream** cez Supabase `.stream()`

### 6.5 Fórum (`lib/features/forum/`)

- **Príspevky (ForumPostModel):** title, content, created_by, reply_count, likes_count
- **Odpovede (ForumReplyModel):** content, post_id, likes_count
- **Lajky** — inkrementálny counter na príspevkoch aj odpovediach (bez anti-duplicate logiky)
- **Realtime** — stream príspevkov + helper stream `getReplyCount()` pre triggering refresh
- **CRUD:** vytvoriť/editovať/zmazať príspevok aj odpoveď

### 6.6 Ankety (`lib/features/polls/`)

- **PollModel:** question, expires_at, options, hasVoted
- **PollOptionModel:** option_text, voteCount (enriched)
- **Hlasovanie** — unique constraint `(poll_id, user_id)` zabraňuje dvojitému hlasovaniu
- **Uplynutie** — voliteľné `expires_at`
- **Mazanie** — kaskádové (votes → options → poll)
- **Realtime** — stream cez `.stream()` s asyncMap enrichment

### 6.7 Chat (`lib/features/chat/`)

- **Priama správa** medzi dvomi používateľmi v budove
- **MessageModel polia:** `building_id`, `sender_id`, `receiver_id`, `content`, `read`
- **Realtime** — dva oddělené `.stream()` streamy (sent + received) kombinované cez `rxdart.Rx.combineLatest2` (dôvod: Supabase `.stream()` nepodporuje OR filtre)
- **Prečítané správy** — `markAsRead()`, `getUnreadCount()`
- **Zoznam konverzácií** — `ConversationsScreen` zobrazuje všetkých obyvateľov s poslednou správou
- **Watchovanie** — `watchBuildingMessageCount()` pre refresh konverzácií

### 6.8 Rezervácie (`lib/features/reservations/`)

- **Spoločné priestory (AmenityModel):** name, description, is_active
- **Rezervácia (ReservationModel):** amenity_id, date, time_from, time_to, note
- **Kontrola prekrytia** — klientská validácia v `createReservation()` pred insertom
- **Stream** pre všetky rezervácie (manažér) aj vlastné (obyvateľ)
- **CRUD amenities:** manažér vytvára/ruší spoločné priestory
- **Formát času:** DB vracia `HH:MM:SS`, UI oreže na `HH:MM`

### 6.9 Dokumenty (`lib/features/documents/`)

- **Upload:** PDF, DOC, DOCX, PNG, JPG — max 20 MB
- **Storage bucket:** `documents`, cesta `<building_id>/<uuid>.<ext>`
- **DocumentModel polia:** name, file_url, file_size, created_by
- **fileSizeLabel** — helper getter (B / KB / MB)
- **Mazanie:** najprv zo storage, potom z DB

### 6.10 Kontakty (`lib/features/contacts/`)

- **ContactModel polia:** name, phone, description
- **CRUD:** len manažér môže vytvárať/editovať/mazať
- **Čítanie:** všetci členovia budovy
- **Realtime stream**

### 6.11 Dodávatelia (`lib/features/suppliers/`)

- **SupplierModel polia:** name, category, phone, email, note
- **CRUD:** len manažér
- **Priraďovanie k tiketom:** cez `supplier_id` na tikete
- **Dodávateľský pohľad:** `SupplierTicketsScreen` — zobrazuje priradené tikety

### 6.12 Inšpekcie (`lib/features/inspections/`)

- **InspectionModel polia:** title, description, inspection_date, next_date, status
- **Vypršanie:** `isExpired`, `isExpiringSoon` (≤ 30 dní), `daysUntilNext`
- **CRUD:** manažér
- **Realtime stream**

### 6.13 Dashboard

- **ManagerDashboard:** štatistiky tikety, oznamy, ankety, inšpekcie, najbližšie rezervácie, počet obyvateľov
- **ResidentDashboard:** vlastné tikety (počet, stav), posledné oznamy

### 6.14 Plán budovy (`lib/features/building_plan/`)

- **Storage:** upsert URL do tabuľky `building_plan`
- **Zobrazenie:** `BuildingPlanScreen` — zobrazuje PDF/obrázok plánu
- **Realtime stream** URL

### 6.15 Domový poriadok (`lib/features/house_rules/`)

- **Obsah:** voľný text, jeden záznam na budovu
- **Upsert** pri uložení (unique constraint na `building_id`)
- **CRUD:** len manažér môže editovať, všetci čítajú

### 6.16 Obyvatelia (`lib/features/residents/`)

- **ResidentsScreen** — zoznam obyvateľov budovy (len pre manažéra)
- **ResidentsCountProvider** — počet obyvateľov pre dashboard

---

## 7. Databázová schéma

### Tabuľky

#### `buildings`
```sql
id          uuid PK
name        text NOT NULL
address     text NOT NULL
manager_id  uuid FK → profiles(id)
created_at  timestamptz
```

#### `profiles`
```sql
id           uuid PK FK → auth.users(id) ON DELETE CASCADE
email        text NOT NULL
full_name    text
flat_number  text
phone        text
role         text CHECK (role IN ('manager', 'resident', 'dodavatel'))
building_id  uuid FK → buildings(id)
fcm_token    text
created_at   timestamptz
```

#### `tickets`
```sql
id           uuid PK
title        text NOT NULL
description  text
category     ticket_category ENUM ('Vodoinštalácia','Elektrina','Výťah','Spoločné priestory','Iné')
status       ticket_status ENUM ('Prijaté','V riešení','Ukončené') DEFAULT 'Prijaté'
photo_url    text (legacy)
supplier_id  uuid FK → profiles(id) ON DELETE SET NULL
created_by   uuid FK → profiles(id) NOT NULL
building_id  uuid FK → buildings(id) NOT NULL
created_at   timestamptz
updated_at   timestamptz (auto-update trigger)
```

#### `ticket_photos`
```sql
id          uuid PK
ticket_id   uuid FK → tickets(id)
photo_url   text NOT NULL
created_at  timestamptz
```

#### `announcements`
```sql
id           uuid PK
title        text NOT NULL
content      text NOT NULL
is_urgent    boolean DEFAULT false
photo_urls   text[] (pole URL)
created_by   uuid FK → profiles(id)
building_id  uuid FK → buildings(id)
created_at   timestamptz
```

#### `polls`
```sql
id           uuid PK
question     text NOT NULL
building_id  uuid FK → buildings(id)
created_by   uuid FK → profiles(id)
expires_at   timestamptz
created_at   timestamptz
```

#### `poll_options`
```sql
id           uuid PK
poll_id      uuid FK → polls(id) ON DELETE CASCADE
option_text  text NOT NULL
```

#### `poll_votes`
```sql
id           uuid PK
poll_id      uuid FK → polls(id) ON DELETE CASCADE
option_id    uuid FK → poll_options(id)
user_id      uuid FK → profiles(id)
building_id  uuid FK → buildings(id)
created_at   timestamptz
UNIQUE (poll_id, user_id)
```

#### `messages`
```sql
id           uuid PK
building_id  uuid FK → buildings(id)
sender_id    uuid FK → profiles(id)
receiver_id  uuid FK → profiles(id)
content      text NOT NULL
read         boolean DEFAULT false
created_at   timestamptz
```

#### `forum_posts`
```sql
id           uuid PK
building_id  uuid FK → buildings(id)
created_by   uuid FK → profiles(id)
title        text NOT NULL
content      text NOT NULL
likes_count  integer DEFAULT 0
created_at   timestamptz
updated_at   timestamptz
```

#### `forum_replies`
```sql
id           uuid PK
post_id      uuid FK → forum_posts(id) ON DELETE CASCADE
building_id  uuid FK → buildings(id)
created_by   uuid FK → profiles(id)
content      text NOT NULL
likes_count  integer DEFAULT 0
created_at   timestamptz
```

#### `reservations`
```sql
id           uuid PK
amenity_id   uuid FK → amenities(id)
building_id  uuid FK → buildings(id)
resident_id  uuid FK → profiles(id)
date         date NOT NULL
time_from    time NOT NULL
time_to      time NOT NULL
note         text
created_at   timestamptz
```

#### `amenities`
```sql
id           uuid PK
building_id  uuid FK → buildings(id)
name         text NOT NULL
description  text
is_active    boolean DEFAULT true
created_at   timestamptz
```

#### `contacts`
```sql
id           uuid PK
building_id  uuid FK → buildings(id) ON DELETE CASCADE
name         text NOT NULL
phone        text NOT NULL
description  text
created_by   uuid FK → profiles(id)
created_at   timestamptz
```

#### `documents`
```sql
id           uuid PK
building_id  uuid FK → buildings(id) ON DELETE CASCADE
name         text NOT NULL
file_url     text NOT NULL
file_size    bigint
created_by   uuid FK → profiles(id)
created_at   timestamptz
```

#### `suppliers`
```sql
id           uuid PK
building_id  uuid FK → buildings(id)
name         text NOT NULL
category     text
phone        text
email        text
note         text
created_at   timestamptz
```

#### `inspections`
```sql
id               uuid PK
building_id      uuid FK → buildings(id)
title            text NOT NULL
description      text
inspection_date  date NOT NULL
next_date        date
status           text DEFAULT 'active'
created_at       timestamptz
```

#### `house_rules`
```sql
id           uuid PK
building_id  uuid NOT NULL FK → buildings(id) ON DELETE CASCADE
content      text NOT NULL DEFAULT ''
updated_by   uuid FK → profiles(id)
updated_at   timestamptz NOT NULL
UNIQUE (building_id)
```

#### `building_plan`
```sql
building_id  uuid PK FK → buildings(id) ON DELETE CASCADE
file_url     text NOT NULL
updated_at   timestamptz NOT NULL
```

#### `building_units`
```sql
id           uuid PK
building_id  uuid FK → buildings(id) ON DELETE CASCADE
unit_type    text CHECK (unit_type IN ('byt', 'pivnica', 'parkovisko'))
unit_number  text NOT NULL
floor        integer DEFAULT 0
resident_id  uuid FK → profiles(id) ON DELETE SET NULL
resident_name text
note         text
created_at   timestamptz
```

#### `invite_codes`
```sql
-- používa sa pri registrácii
code         text
building_id  uuid FK → buildings(id)
role         text CHECK (role IN ('resident', 'dodavatel')) DEFAULT 'resident'
created_by   uuid
expires_at   timestamptz
```

### Storage buckety

| Bucket | Obsah | Max veľkosť | Prístup |
|---|---|---|---|
| `ticket-photos` | Fotky tiketov + fotky oznamov | — | Public read |
| `documents` | Dokumenty budovy (PDF, DOC, obrázky) | 20 MB | Public read |

### RLS pomocné funkcie

```sql
auth_building_id() → uuid  -- building_id prihláseného používateľa
auth_role() → text         -- rola prihláseného používateľa
```

### Supabase Realtime (publikácie)

Pridané do `supabase_realtime` publikácie:
`tickets`, `announcements`, `polls`, `poll_votes`, `contacts`, `documents`, `messages`, `forum_posts`, `forum_replies`

---

## 8. Edge Functions (Supabase / Deno)

### `send-notification`

**Cesta:** `supabase/functions/send-notification/index.ts`

**Účel:** Odošle FCM push notifikáciu všetkým používateľom budovy (okrem odosielateľa).

**Postup:**
1. Načíta FCM tokeny všetkých profilov s `building_id` (okrem `exclude_user_id`)
2. Získa Google OAuth2 access token cez JWT (RS256) z `FIREBASE_SERVICE_ACCOUNT`
3. Volá FCM v1 API pre každý token

**Požadované env premenné v Supabase:**
- `SUPABASE_URL` (auto)
- `SUPABASE_SERVICE_ROLE_KEY` (auto)
- `FIREBASE_SERVICE_ACCOUNT` (JSON string zo Google Service Account)

**Volanie z Flutteru:** `NotificationService.sendToBuilding()` v `lib/core/services/notification_service.dart`

---

## 9. Push notifikácie

### Architektúra

```
Flutter app
  └── NotificationService.sendToBuilding()
        └── HTTP POST → Supabase Edge Function (send-notification)
              └── Firebase FCM v1 API → zariadenie používateľa
```

### Trigre notifikácií

| Akcia | Nadpis | Trigger |
|---|---|---|
| Nový tiket | `🔧 Nový tiket` | `TicketRepository.createTicket()` |
| Nový oznam | `📢 Nový oznam` | `AnnouncementRepository.createAnnouncement()` |

### FCM konfigurácia

- **Web VAPID kľúč:** `BD-WctOQ4qd3dZkSc9i1NldHuc0ordU3MQ2gENtcDO3cZkllkCbKaycFcr9rwd3U1GP04An1-CLMBf5RnQdsJlU`
- **Android kanál:** `domovnik_high_importance` (High importance)
- **iOS:** alert + badge + sound

---

## 10. Migrácie databázy

| Súbor | Obsah |
|---|---|
| `001_initial_schema.sql` | Základná schéma: buildings, profiles, tickets, announcements, polls, poll_options, poll_votes |
| `002_rls_policies.sql` | RLS politiky + helper funkcie `auth_building_id()`, `auth_role()` |
| `003_rpc_and_storage.sql` | RPC funkcie + storage bucket `ticket-photos` |
| `004_auth_trigger.sql` | Trigger pri registrácii nového používateľa |
| `005_fix_trigger_and_disable_confirm.sql` | Oprava triggera, vypnutie email potvrdenia |
| `006_bootstrap_profile_rpc.sql` | RPC `handle_user_signup()` ako fallback pre trigger |
| `007_contacts_and_documents.sql` | Tabuľky contacts, documents + bucket `documents` |
| `008_profiles_resident_read.sql` | RLS pre čítanie profilov obyvateľmi |
| `009_messages_realtime.sql` | Pridanie `messages` do Realtime publikácie |
| `010_forum_realtime.sql` | forum_posts, forum_replies tabuľky + Realtime |
| `011_forum_likes.sql` | Stĺpec `likes_count` na forum_posts a forum_replies |
| `012_announcement_photos.sql` | Stĺpec `photo_urls` (text[]) na announcements |
| `013_house_rules.sql` | Tabuľka `house_rules` + RLS |
| `014_building_units.sql` | Tabuľka `building_units` (byty, pivnice, parkoviská) + RLS |
| `015_building_plan.sql` | Tabuľka `building_plan` + RLS |
| `016_supplier_access.sql` | Rola `dodavatel`, stĺpec `supplier_id` na tickets, RLS pre dodávateľov, `generate_supplier_invite()` RPC |

---

## 11. Čo NIE JE dokončené / Known issues

### Chýbajúce funkcie

1. **`building_units` nemá Flutter UI** — tabuľka existuje v DB (migrácia 014), ale chýba feature modul v `lib/features/`. Správca nemôže spravovať byty/pivnice/parkoviská cez UI.

2. **FCM notifikácia neklikne na správnu obrazovku** — pri kliknutí na push notifikáciu sa len zaloguje route, ale skutočná navigácia neprebehne (`_onNotificationTap` a `_handleMessageNavigation` nevolajú GoRouter).

3. **Lajky sú bez anti-duplicate ochrany** — `incrementPostLikes` a `incrementReplyLikes` len incrementujú counter bez kontroly, či používateľ už lajkol. Jeden používateľ môže lajkovať donekonečna.

4. **Dodávateľský invite flow nie je celý v UI** — RPC `generate_supplier_invite()` existuje v DB, ale nie je vystavená v manažérskom UI (nie je tlačidlo „Pozvať dodávateľa" s generovaním kódu).

5. **Chat - OR filter workaround** — `ChatRepository.getMessages()` používa dva samostatné `.stream()` volania kombinované cez rxdart, pretože Supabase `.stream()` nepodporuje OR filtre. Toto môže spôsobiť nadbytočné DB záťaže.

6. **Chýba pagination** — všetky listy (tikety, oznamy, fórum) načítavajú všetky záznamy bez stránkovania. Môže byť problém pre budovy s dlhšou históriou.

### Bezpečnostné upozornenia

1. **KRITICKÉ: Hardcoded service role key** — `NotificationService` v `lib/core/services/notification_service.dart` obsahuje hardcoded Supabase `service_role` JWT token priamo v kóde. Tento token má plný prístup k DB. Mal by byť nahradený volaním cez anon key s Supabase Auth, alebo token presunutý mimo kódu.

2. **Firebase config v `main.dart`** — Firebase `apiKey`, `appId` a `messagingSenderId` sú hardcoded v `main.dart`. Pre web je to bežná prax (Firebase web kľúče sú verejné), ale je to suboptimálne.

### Menšie nedostatky

- `TicketRepository.getTickets()` robí N+1 queries (separate `await` pre každý tiket pri načítaní profilu a fotiek) — môže byť pomalé pri veľa tiketoch
- Rezervácie — kontrola prekrytia (`overlaps`) prebieha na klientovi, nie na DB úrovni. Race condition možná pri súbežnom vytváraní.
- `InspectionModel.status` je `String`, nie enum — hodnota `'active'` je hardcoded default

---

## 12. Závislosti (`pubspec.yaml`)

### Runtime

```yaml
flutter_riverpod: ^2.5.1       # state management
riverpod_annotation: ^2.3.5    # generátor anotácie
go_router: ^13.2.0             # navigácia
supabase_flutter: ^2.3.4       # backend
firebase_core: ^2.27.1         # Firebase init
firebase_messaging: ^14.7.19   # FCM push notifikácie
flutter_local_notifications: ^17.1.2  # lokálne notifikácie (Android/iOS)
image_picker: ^1.0.7           # výber obrázkov z galérie/kamery
cached_network_image: ^3.3.1   # cachovanie obrázkov
intl: ^0.20.2                  # formátovanie dátumov
flutter_dotenv: ^5.1.0         # načítanie .env
uuid: ^4.3.3                   # generovanie UUID
url_launcher: ^6.3.1           # otváranie URL/telefónu
file_picker: ^8.0.7            # výber súborov (PDF, DOC...)
http: ^1.2.0                   # HTTP volania (Edge Function)
shared_preferences: ^2.3.2     # perzistencia nastavení (remember me)
flutter_localizations           # l10n podpora (SK locale)
```

### Dev

```yaml
flutter_lints: ^3.0.0          # statická analýza
build_runner: ^2.4.9           # generovanie kódu
riverpod_generator: ^2.4.0     # Riverpod codegen
custom_lint: ^0.6.4            # custom lint rules
riverpod_lint: ^2.3.10         # Riverpod-specific lint
```

### Assets

```yaml
assets:
  - .env                        # environment variables
  - icons/Icon-192.png          # web manifest ikona
  - assets/logo_horizontal.png  # logo aplikácie
```

---

## 13. TODO komentáre v kóde

> Spustením `grep -rn "TODO\|FIXME\|HACK" lib/` neboli nájdené žiadne TODO/FIXME/HACK komentáre.

---

## 14. Kľúčové konvencie kódu

### Supabase patterns

```dart
// Realtime stream (read-only)
_client.from('table').stream(primaryKey: ['id']).eq('building_id', id).order('created_at', ascending: false)

// Jednorazové načítanie
await _client.from('table').select().eq('id', id).maybeSingle()

// Vloženie s výsledkom
await _client.from('table').insert({...}).select().single()

// Join (denormalizované)
await _client.from('profiles').select('full_name').eq('id', userId).maybeSingle()

// Upsert s conflict
await _client.from('table').upsert({...}, onConflict: 'building_id')
```

### Riverpod patterns

```dart
// Stream provider (realtime)
@riverpod
Stream<List<T>> items(Ref ref) {
  final buildingId = ref.watch(profileProvider).value?.buildingId ?? '';
  return ref.watch(repositoryProvider).getItems(buildingId);
}

// Notifier pre mutácie
@riverpod
class ItemNotifier extends _$ItemNotifier {
  @override
  FutureOr<void> build() {}
  
  Future<void> create(...) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => repository.create(...));
  }
}
```

---

## 15. Prostredie a nasadenie

### `.env` súbor (potrebné premenné)

```env
SUPABASE_URL=https://pclawaxmilduvfkwhhge.supabase.co
SUPABASE_ANON_KEY=<anon_key>
```

### Firebase

- Firebase konfigurácia pre Android: `android/app/google-services.json`
- Firebase konfigurácia pre web: hardcoded v `lib/main.dart`
- Web push VAPID kľúč: hardcoded v `lib/features/notifications/data/fcm_service.dart`

### Supabase Edge Function env

Nastaviť v Supabase Dashboard → Edge Functions → send-notification → Secrets:
- `FIREBASE_SERVICE_ACCOUNT` — JSON string zo Google Cloud Service Account s oprávnením `firebase.messaging`

---

*Posledná aktualizácia: 2026-05-06*
