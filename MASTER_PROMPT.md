# MASTER_PROMPT.md — Domovník
> Komplexná dokumentácia projektu pre Claude a Claude Code.
> Verzia: 3.0 | Aktualizované: Jún 2026

---

## 1. Prehľad projektu

**Domovník** je slovenská B2B SaaS aplikácia pre správu bytových domov.

| | |
|---|---|
| **Flutter app** | https://domovnik.online |
| **Admin panel** | https://domovnik-admin.vercel.app |
| **Landing page** | https://domovnik-landing.vercel.app |
| **Supabase ID** | `pclawaxmilduvfkwhhge` |
| **Firebase** | `domovnik-e1e51` |
| **Android package** | `com.domovnik.app` |

---

## 2. Lokálne cesty

```
~/Projects/domovnik/          ← Flutter app (hlavný projekt)
~/Projects/domovnik-admin/    ← Next.js admin panel
~/Projects/domovnik-landing/  ← Next.js landing page + customer portal
```

---

## 3. Kľúčové príkazy

```bash
# Spustenie Claude Code agenta
cd ~/Projects/domovnik && claude

# Deploy Flutter web
cd ~/Projects/domovnik && flutter build web --release && cd build/web && vercel --prod

# Deploy admin panel
cd ~/Projects/domovnik-admin && vercel --prod

# Deploy landing page
cd ~/Projects/domovnik-landing && vercel --prod

# Deploy Supabase edge function
npx supabase functions deploy send-notification --project-ref pclawaxmilduvfkwhhge

# Build Android APK
cd ~/Projects/domovnik && flutter build apk --release

# Inštalácia na pripojený Android
cd ~/Projects/domovnik && flutter install

# Analýza kódu
flutter analyze
```

---

## 4. Tech stack

| Vrstva | Technológia |
|---|---|
| Frontend | Flutter + Riverpod + GoRouter |
| Backend | Supabase (auth, PostgreSQL, storage, realtime, edge functions) |
| Push notifikácie | Firebase Cloud Messaging (FCM) |
| Email | Resend (noreply@domovnik.online) |
| Hosting | Vercel |
| Admin panel | Next.js + Tailwind CSS |
| Landing page | Next.js + Tailwind CSS |
| Platby | Stripe (subscription, customer portal) |
| DNS | Cloudflare |

---

## 5. Farby aplikácie

| Názov | Konštanta | Hex |
|---|---|---|
| Primary | `AppColors.primary` | `#1A3C6E` (dark navy) |
| Primary light | `AppColors.primaryLight` | `#2E5FA3` (medium blue) |
| Primary dark | `AppColors.primaryDark` | `#0D2244` |
| Accent | `AppColors.accent` | `#F57C00` (orange) |
| Background | `AppColors.surface` | `#F5F7FA` |

> Všetky farby v: `lib/core/constants/app_colors.dart`

---

## 6. Credentials

### Supabase
```
URL:          https://pclawaxmilduvfkwhhge.supabase.co
Anon key:     sb_publishable_gpKnvoN9COL_WZPxOm5QhA_VyiI6woM
Service role: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBjbGF3YXhtaWxkdXZma3doaGdlIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NTgzNSwiZXhwIjoyMDkwNTYxODM1fQ.zhL-I2SgxK_a92-etSFlAFzAuIS1BaloPEjMsVrFlKE
```

### Firebase
```
Project ID:          domovnik-e1e51
Web API key:         AIzaSyCtaZ0rWoBEvZTU0ctNwjOZAoa4yGpPyWM
VAPID key:           BD-WctOQ4qd3dZkSc9i1NldHuc0ordU3MQ2gENtcDO3cZkllkCbKaycFcr9rwd3U1GP04An1-CLMBf5RnQdsJlU
Messaging sender ID: 56523663052
```

### Stripe (pridať do .env.local + Vercel)
```
STRIPE_SECRET_KEY=sk_live_...          ← z Stripe dashboard → Developers → API keys
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...        ← z Stripe dashboard → Developers → Webhooks
STRIPE_PRICE_STARTER=price_...         ← vytvor produkt Štart 19€/mes
STRIPE_PRICE_PROFESSIONAL=price_...    ← vytvor produkt Správca 49€/mes
STRIPE_PRICE_ENTERPRISE=price_...      ← vytvor produkt Pro 99€/mes
```

---

## 7. Databázové tabuľky

```
buildings, building_units, profiles, tickets, announcements,
polls, poll_options, poll_votes, forum_posts, forum_replies,
reservations, amenities, contacts, documents, invite_codes,
registration_requests, inspections, suppliers, messages,
house_rules, building_plan, feedback, customer_subscriptions
```

> `customer_subscriptions` — nová tabuľka pre Stripe platby (migrácia 020)
> `profiles` má nové stĺpce: `onboarding_completed boolean`, `company_name text`

---

## 8. Implementované funkcie

### Flutter app — 3 shelly (roly)

**Resident shell** — 5 tabs: Dashboard · Tikety · Fórum · Správy (Chat) · Ďalšie
**Manager shell** — 5 tabs: Prehľad · Oznamy · Tikety · Správy (Chat) · Ďalšie
**Supplier shell** — 2 tabs: Tikety · Profil

> ⚠️ Chat je primárny tab v oboch shelloch (nie Fórum/Ankety). Fórum a Ankety sú v More draweri.

### Obrazovky Flutter app

| Feature | Obrazovky | Poznámka |
|---|---|---|
| Auth | Login, Register, Reset Password | |
| Dashboard | ResidentDashboard, ManagerDashboard | |
| Tickets | List, Create, Detail, SupplierTickets | |
| Announcements | List, Create | |
| Forum | Forum screen | Manager má zvukový alert, v More draweri |
| Chat | ConversationsScreen + ChatScreen (1-to-1) | Primárny tab v oboch shelloch |
| Polls | List, Create, Detail | V More draweri |
| Contacts | Screen | |
| Documents | Screen | |
| Reservations | Screen | |
| Inspections | Screen | Len správca |
| Suppliers | Screen | Len správca |
| House Rules | Screen | |
| Building Plan | Screen | |
| Residents | ResidentsScreen — "Evidencia bytov" | Zoznam ľudí z profiles, len správca |
| Building Units | BuildingUnitsScreen — "Evidencia jednotiek" | Byty/pivnice/parkoviská z building_units, len správca |
| Profile | Profile, Edit Profile, Settings | |
| Invite Codes | Zabudované v ProfileScreen | Nie vlastná stránka |
| Feedback | FeedbackScreen | Odoslanie bugreportu/nápadu, email notifikácia na hrtanekmatus02@gmail.com |

### Admin panel (Next.js — domovnik-admin.vercel.app)
Poradie v sidebari:
`Dashboard → Requests → Buildings → Users → Tickets → Announcements → Polls → Forum → Reservations → Documents → Contacts → Inspections → Suppliers → House Rules → Building Plan → Messages → Invite Codes → Feedback`

- ✅ Users: všetky roly (admin, manager, resident, dodavatel) s farebnými badges, reset hesla, delete
- ✅ Buildings: vytvorenie, úprava, zmazanie
- ✅ Feedback: zoznam reportov s modálom na detail, farebné type badges
- ✅ Všetky ostatné sekcie: zoznam, vytvorenie, úprava, zmazanie

> ⚠️ V admin paneli existujú dve stránky pre dodávateľov:
> - `/suppliers` — adresár firiem/dodávateľov (tabuľka `suppliers`), **v sidebari**
> - `/dodavatelia` — používateľské účty s rolou `dodavatel` (z `profiles`), **NIE je v sidebari** — treba rozhodnúť: pridať do sidebaru alebo zmazať

### Landing page (Next.js — domovnik-landing.vercel.app)

**Stránky:**
- `/` — hlavná landing page (12 sekcií, hero, features, pricing, CTA atď.)
- `/features/tikety`, `/features/oznamy`, `/features/hlasovanie`, `/features/dokumenty` — detail stránky funkcií
- `/pricing` — cenník (Štart 19€, Správca 49€, Pro 99€) — stránka zatiaľ neexistuje, ceny sú v PricingPreview.tsx na hlavnej stránke
- `/privacy`, `/terms` — právne stránky (po slovensky)
- `/login` — prihlásenie (Supabase auth)
- `/register` — registrácia (Supabase auth)
- `/forgot-password` — reset hesla
- `/dashboard` — zákaznícky portal (vyžaduje login)
- `/dashboard/onboarding` — onboarding wizard (po prvom platení)
- `/auth/callback` — OAuth callback route

**Auth súbory:**
- `lib/supabase/client.ts` — browser Supabase client
- `lib/supabase/server.ts` — server Supabase client (cookies)
- `proxy.ts` — session refresh + route guards (Next.js 16, nie middleware.ts)
- `app/auth/callback/route.ts` — code exchange

**Stripe API routes:**
- `app/api/stripe/create-checkout/route.ts` — vytvorí checkout session
- `app/api/stripe/webhook/route.ts` — spracuje Stripe eventy
- `app/api/stripe/customer-portal/route.ts` — billing self-service

---

## 9. Testovacie účty

```
Admin:    matushrtanek02@gmail.com / Domovnik2026!
Resident: vytvor cez invite kód v admin paneli
```

---

## 10. Stav notifikácií

### Edge function: `send-notification`
- ✅ `service_role` key je **server-side** v Deno.env — **nie hardcoded** v Flutter
- ✅ Tikety: notifikácia pri vytvorení → `sendToBuilding()`
- ✅ Tikety: notifikácia pri zmene statusu → `sendToUser()`
- ✅ Chat: notifikácia pri novej správe → `sendToUser()`
- ✅ Foreground: `flutter_local_notifications` zobrazí banner

### Opravený bug (Jún 2026)
FCM token sa neukladal pri prihlásení — fix v `app.dart`:
```dart
if (data.event == AuthChangeEvent.signedIn) {
  final fcmService = FcmService();
  final token = await fcmService.getToken();
  if (token != null) await fcmService.saveFcmTokenToProfile(token);
}
```

> ❌ Firefox nepodporuje FCM — web push nefunguje vo Firefoxe. Workaround: Chrome/Edge/Safari.

---

## 11. Dizajnové pravidlá

> ⚠️ **KRITICKÉ: Žiadne emoji v UI** — ani v tlačidlách, kartách, badgeoch, dialógoch, navigácii, ani nikde inde — v appke, admin paneli, ani landing page. Výlučne Material Icons pre ikony a čistý text pre labely.

---

## 12. Workflow s Claude Code

1. **Matúš** napíše čo treba (po slovensky)
2. **Claude** (claude.ai Cowork) pripraví prompt v **angličtine**
3. **Claude Code** (`claude` v terminári) vykoná zmeny
4. **Matúš** otestuje na live prostredí

> Anglické prompty pre Claude Code dávajú presnejšie výsledky ako slovenské!

### ⚠️ KRITICKÉ PRAVIDLO — Kedy žiadať Matúša o manuálny krok

**Claude (Cowork) nikdy nepýta Matúša aby niečo ručne spúšťal v terminári, pokiaľ to Claude Code nevie urobiť sám.**

- Ak treba git push, deploy, terminal príkaz → pošli to Claude Code (`claude` v termináli)
- Claude Code má prístup ku git credentials, Vercel CLI, npm atď.
- Iba ak Claude Code sám povie "nemôžem to urobiť, musíš to spraviť ty" → vtedy to povedz Matúšovi
- **Nikdy** neposielajte Matúša kopírovať terminal príkazy priamo — to je práca Claude Code

---

## 13. Supabase migrácie — stav live DB

| Migrácia | Stav |
|---|---|
| 001–013 | ✅ Aplikované |
| 014_building_units | ✅ Aplikované manuálne (+ ALTER TABLE pre resident_name) |
| 015_building_plan | ✅ Aplikované (overené) |
| 016_supplier_access | ✅ Aplikované (overené) |
| 017–018_forum_likes | ✅ Aplikované (overené) |
| 019_feedback | ✅ Aplikované |
| 020_subscriptions | ✅ Aplikované + UNIQUE constraint na user_id |

> ⚠️ `https://domovnik.online` a `https://domovnik-landing.vercel.app` musia byť v **Supabase → Auth → Redirect URLs**.

### Skutočné schémy kľúčových tabuliek (overené v SQL Editor)

```
buildings:        id, name, address, manager_id, created_at
                  ❌ units_count NEEXISTUJE

invite_codes:     id, code, building_id, created_by, used (boolean), expires_at, created_at, role (text, default 'resident')
                  ❌ max_uses NEEXISTUJE, ❌ used_count NEEXISTUJE

customer_subscriptions: id, user_id (UNIQUE), stripe_customer_id, stripe_subscription_id,
                        plan, status, buildings_limit, current_period_end, created_at, updated_at
```

### RLS politiky invite_codes (overené)
- `anyone_can_read_invite_codes` — SELECT, public ✅ (Flutter môže čítať pred auth)
- `anyone_can_use_invite_code` — UPDATE, public ✅
- `managers_delete_own_invite_codes` — DELETE, public
- `managers_insert_invite_codes` — INSERT, public
- `managers_read_own_invite_codes` — SELECT, public

---

## 14. Backlog

### Hotové
| Feature | Poznámka |
|---|---|
| Customer portal — Auth | /login, /register, /forgot-password, middleware, Navbar auth-aware |
| Customer portal — Stripe checkout | create-checkout, webhook, customer-portal API routes |
| Customer portal — Dashboard | Plný dashboard s tiketmi, invite kódmi, stat kartami |
| Customer portal — Onboarding wizard | 3-krokový wizard — FUNGUJE end-to-end ✅ |
| Stripe webhook endpoint | "fascinating-legacy" na vercel, STRIPE_WEBHOOK_SECRET nastavený |
| migrácia 020 | customer_subscriptions tabuľka + UNIQUE constraint na user_id |
| Celý Stripe flow | Checkout → DB (trialing) → Onboarding → Dashboard — OVERENÉ ✅ (Jún 2026) |
| Web ↔ Flutter prepojenie | Invite kódy z web dashboardu fungujú v Flutter registrácii ✅ |

### Opravené bugy (Jún 2026)
| Bug | Oprava |
|---|---|
| `create-checkout` písal `status: 'inactive'` → dashboard nefungoval | Zmenené na `status: 'trialing'` |
| `dashboard/page.tsx` crash na `invite_codes.used_count` | Select zmenený, stĺpec odstránený |
| `onboarding/page.tsx` null assertion crash | Pridaný null check |
| `invite/generate/route.ts` vkladal `max_uses: 50` → DB error | Odstránené |
| OnboardingWizard: `created_by` → `manager_id` v buildings insert | Opravené |
| OnboardingWizard: vkladal neexistujúce stĺpce (`units_count`, `max_uses`) | Odstránené |
| Webhook vracal 200 aj pri DB chybe | Zmenené na 500 |

### Zostávajúce bugy

| Priorita | Projekt | Bug | Súbor |
|---|---|---|---|
| 🔴 P1 | Flutter | `updateUnit` prepisuje `resident_id/resident_name` aj keď sú null → dataloss | `building_unit_repository.dart:59` |
| 🟠 P2 | admin | Logout nemaže `admin_trusted_device` cookie → bypass 2FA | `app/api/admin/logout/route.ts` |
| 🟠 P2 | Flutter | `currentUser!.id` force-unwrap v forum repo → crash po session expiry | `forum_repository.dart:179,192` |
| 🟠 P2 | Flutter/admin | Emoji v push notifikáciách a UI tlačidlách — zakázané v MASTER_PROMPT | viacero súborov |
| 🟡 P3 | landing | Počet budov hardcoded ako "1 / limit" namiesto skutočného count | `dashboard/page.tsx` |
| 🟡 P3 | Flutter | `register_screen.dart` vkladá do `registration_requests` — tabuľka neexistuje | `register_screen.dart:46` |
| 🟡 P3 | admin | `reservations/page.tsx` referencuje `amenities.is_active` — tabuľka neexistuje | `app/reservations/page.tsx:34` |
| 🟡 P3 | admin | `/dodavatelia` duplicitná funkcionalita s `/users` | `app/dodavatelia/page.tsx` |

### Nezačaté features
| Feature | Stav | Poznámka |
|---|---|---|
| `registration_requests` | ❌ Chýba | Ani DB ani Flutter — feature nezačatá, ale Flutter na to referuje |
| `amenities` | ❌ Chýba | Ani DB ani Flutter — admin panel na to referuje |
| Google Play Store | 🟢 Nízka priorita | Potrebný vývojársky účet ($25) |
| Finálne logo/ikony | 🟢 Nízka priorita | Ideogram vygeneroval dobrú ikonu budovy |
| Pricing detail stránky | 🟢 Nízka priorita | /pricing/starter atď. |

---

## 15. Kde pokračovať (ďalší chat)

### Prvá úloha — Subscription guard vo Flutter routeri
**Problém:** Flutter appka (domovnik.online) vôbec nekontroluje `customer_subscriptions`. Každý zaregistrovaný manažér môže používať appku zadarmo bez predplatného.

**Riešenie:** Pridať check len pre `role == 'manager'` (obyvatelia a dodávatelia neplatia).

Logika v `lib/router/app_router.dart` — `_DashboardRedirect` widget:
```dart
// Po načítaní profilu, ak profile.isManager:
// 1. Načítaj z Supabase: customer_subscriptions WHERE user_id = profile.id
// 2. Ak neexistuje záznam ALEBO status nie je 'active'/'trialing':
//    → otvoriť URL https://domovnik-landing.vercel.app/#cennik
//    → alebo zobraziť obrazovku "Aktivujte si predplatné" s tlačidlom
// 3. Ak OK → pokračuj normálne do /manager/dashboard
```

Možnosť A (jednoduchšia): zobraziť v appke screen "Potrebujete predplatné" s tlačidlom otvoriť landing page.
Možnosť B: otvoriť landing page priamo cez `url_launcher`.

**Súbory na úpravu:**
- `lib/router/app_router.dart` — `_DashboardRedirect` + globálny redirect
- Možno nový screen `lib/features/subscription/presentation/screens/subscription_required_screen.dart`
- `lib/features/profile/data/profile_repository.dart` — pridať metódu `getSubscriptionStatus()`

---

## 16. Claude Code prompty — použité v tomto projekte

Tieto prompty boli vykonané cez Claude Code. Použiť ich znova ak treba znovu implementovať, alebo ako základ pre ďalšie rozšírenia.

---

### PROMPT A — Landing page Auth (Fáza 1) ✅ HOTOVO

> Pred spustením: vytvor `.env.local` v `~/Projects/domovnik-landing/` s Supabase credentials.
> Nainštaluj: `npm install @supabase/supabase-js @supabase/ssr`

```
Build Phase 1: Authentication for the Domovník landing page at ~/Projects/domovnik-landing/

This uses the SAME Supabase project as the Flutter app (pclawaxmilduvfkwhhge) — same users, same profiles table.

INSTALL DEPENDENCIES:
npm install @supabase/supabase-js @supabase/ssr

STEP 1 — Supabase client setup
Create lib/supabase/client.ts — browser client:
  import { createBrowserClient } from '@supabase/ssr'
  export const createClient = () =>
    createBrowserClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!)

Create lib/supabase/server.ts — server client using cookies (async).

Create middleware.ts at project root — refreshes session, protects /dashboard (redirect to /login if not logged in), redirects logged-in users away from /login and /register.

STEP 2 — Login page (app/login/page.tsx)
Centered card, max-width 440px. Email + password inputs, show/hide password toggle, "Prihlásiť sa" orange button, link to /register and /forgot-password. On submit: supabase.auth.signInWithPassword → redirect to /dashboard on success.

STEP 3 — Register page (app/register/page.tsx)
Same card layout. Full name, email, password, confirm password. supabase.auth.signUp with full_name in metadata. Redirect to /dashboard on success.

STEP 4 — Forgot password (app/forgot-password/page.tsx)
Email input, supabase.auth.resetPasswordForEmail with redirectTo: origin + '/reset-password'. Show success message.

STEP 5 — Update Navbar (components/Navbar.tsx)
Auth-aware: logged-out shows "Prihlásiť sa" + "Dohodnúť demo"; logged-in shows "Dashboard" + user email.

STEP 6 — Auth callback (app/auth/callback/route.ts)
Exchange code for session, redirect to /dashboard.

After all steps: npx tsc --noEmit && npm run build && vercel --prod
```

---

### PROMPT B — Stripe + Onboarding + Dashboard (Fáza 2) 🔄 ČAKÁ NA STRIPE KĽÚČE

> Pred spustením:
> 1. Vytvor Stripe účet na stripe.com
> 2. Vytvor 3 produkty — "Štart" 19€/mes, "Správca" 49€/mes, "Pro" 99€/mes — skopíruj Price IDs
> 3. Pridaj do `.env.local` a Vercel env vars: STRIPE_SECRET_KEY, NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY, STRIPE_PRICE_STARTER, STRIPE_PRICE_PROFESSIONAL, STRIPE_PRICE_ENTERPRISE
> 4. Spusti migráciu 020 v Supabase SQL Editor (SQL vyššie v sekcii 13)
> 5. Nainštaluj: `npm install stripe @stripe/stripe-js`

```
Build Phase 2: Stripe payments + onboarding wizard + live dashboard for ~/Projects/domovnik-landing/

Context:
- Next.js 16 app (uses proxy.ts instead of middleware.ts for route guards)
- Supabase project: pclawaxmilduvfkwhhge (same as Flutter app)
- Auth already implemented: /login, /register, /forgot-password, /reset-password, proxy.ts, lib/supabase/client.ts, lib/supabase/server.ts
- Plans: "Štart" (starter, 19€/mes, 1 building), "Správca" (professional, 49€/mes, up to 5 buildings), "Pro" (enterprise, 99€/mes, unlimited)
- DB plan values: 'starter', 'professional', 'enterprise' (internal keys)
- buildings_limit per plan: starter=1, professional=5, enterprise=999
- Pricing already shown in components/PricingPreview.tsx on homepage

STEP 0 — Install: npm install stripe @stripe/stripe-js

STEP 1 — Database: Run this SQL in Supabase SQL Editor:
create table if not exists customer_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  stripe_customer_id text unique,
  stripe_subscription_id text unique,
  plan text not null check (plan in ('starter', 'professional', 'enterprise')),
  status text not null default 'inactive' check (status in ('active', 'trialing', 'canceled', 'past_due', 'inactive')),
  buildings_limit integer not null default 1,
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table customer_subscriptions enable row level security;
create policy "users_own_subscription" on customer_subscriptions for all using (user_id = auth.uid());
alter table profiles add column if not exists onboarding_completed boolean not null default false;
alter table profiles add column if not exists company_name text;

STEP 2 — Stripe API routes:
- app/api/stripe/create-checkout/route.ts: POST body: {plan: 'starter'|'professional'|'enterprise'}. Get user from Supabase server client. Create or reuse Stripe customer (check customer_subscriptions for existing stripe_customer_id). Create checkout session: mode=subscription, trial_period_days=14, success_url=/dashboard?setup=1, cancel_url=/pricing, metadata={user_id, plan}. Map plan to env var: starter→STRIPE_PRICE_STARTER, professional→STRIPE_PRICE_PROFESSIONAL, enterprise→STRIPE_PRICE_ENTERPRISE.
- app/api/stripe/webhook/route.ts: Verify Stripe-Signature header using STRIPE_WEBHOOK_SECRET. Handle: checkout.session.completed → upsert customer_subscriptions (set plan from metadata, status='trialing', buildings_limit based on plan). customer.subscription.updated → update status + current_period_end. customer.subscription.deleted → set status='canceled'.
- app/api/stripe/customer-portal/route.ts: POST, get user, get stripe_customer_id from customer_subscriptions, create Stripe billing portal session, return {url}.

STEP 3 — Update components/PricingPreview.tsx: Change CTA buttons from <a href="#kontakt"> to buttons that call POST /api/stripe/create-checkout when logged in, or redirect to /register?plan=X when logged out. Keep existing design. Add "14-dňová bezplatná skúška" if not already present. Plan param values: starter, professional, enterprise.

STEP 4 — Onboarding wizard (app/dashboard/onboarding/page.tsx):
Multi-step wizard, 3 steps. Show only if user has active/trialing subscription AND onboarding_completed=false. Redirect to /dashboard if already completed.
Step 1: Welcome screen — show plan name (Štart/Správca/Pro), explain what happens next. Button: "Začať nastavenie".
Step 2: Create building — form with fields: name (text, required), address (text, required), units_count (number, required). On submit: INSERT into buildings (name, address, units_count, created_by=user_id), UPDATE profiles SET building_id=new_building_id, role='manager' WHERE id=user_id.
Step 3: Invite codes — generate 3 codes (INSERT into invite_codes: code=random 8-char uppercase string, building_id, created_by, expires_at=+30days, max_uses=50). Display each code with copy-to-clipboard button. Button "Dokončiť" → UPDATE profiles SET onboarding_completed=true → redirect to /dashboard.
No emoji anywhere. Use only text and SVG icons if needed.

STEP 5 — Live Dashboard (app/dashboard/page.tsx):
Server component. Flow: no auth → redirect /login. Auth but no subscription (or status=inactive/canceled) → show "Vyberte plán" screen with link to /#cennik. Auth + active/trialing subscription + onboarding_completed=false → redirect /dashboard/onboarding. Auth + active/trialing + onboarding_completed=true → show full dashboard.
Full dashboard content (fetch from Supabase using service role or user's building_id from profile):
- Header: "Dobrý deň, [name]" + plan badge (Štart/Správca/Pro, colored)
- "Spravovať platby" button → POST /api/stripe/customer-portal → redirect to portal URL
- 4 stat cards: počet obyvateľov (profiles WHERE building_id), otvorené tikety (tickets WHERE status='open'), oznamy tento mesiac (announcements WHERE building_id + this month), bytové jednotky (building_units WHERE building_id)
- Recent tickets: last 5 tickets with status badge
- Invite codes: list with copy button + "Generovať nový kód" button (POST to generate 1 new code)
- Plan info: current plan, buildings used / buildings limit, subscription status

STEP 6 — Register page update (app/register/page.tsx): if URL has ?plan=starter|professional|enterprise query param, after successful registration redirect to /api/stripe/create-checkout?plan=X (or store in cookie and redirect after callback).

After all steps: npx tsc --noEmit && npm run build && vercel --prod

IMPORTANT POST-DEPLOY: Set up Stripe webhook in Stripe Dashboard → Developers → Webhooks → Add endpoint:
URL: https://domovnik-landing.vercel.app/api/stripe/webhook
Events: checkout.session.completed, customer.subscription.updated, customer.subscription.deleted
Copy webhook signing secret → add as STRIPE_WEBHOOK_SECRET in Vercel env vars → redeploy.
```

---

## 16. Dôležité manuálne nastavenia

> ⚠️ **Supabase → Auth → Redirect URLs** musí obsahovať:
> - `https://domovnik.online`
> - `https://domovnik-landing.vercel.app`

> ⚠️ **Po Stripe deploy:** Nastaviť webhook endpoint v Stripe dashboarde (URL + eventy), skopírovať `STRIPE_WEBHOOK_SECRET` do Vercel env vars a redeployovať.

---

## 17. Súbory loga a ikon

```
assets/logo_horizontal.png     ← 1100×360px, používa sa na login screene
web/favicon.svg                ← brandovaný "D" dizajn
web/favicon.png                ← 32×32px
web/icons/Icon-192.png         ← 192×192px
web/icons/Icon-512.png         ← 512×512px
```

---

## 18. História zmien

| Dátum | Zmena |
|---|---|
| Jún 2026 | Landing page — Auth (login/register/forgot-password/dashboard placeholder, middleware, auth-aware Navbar) |
| Jún 2026 | Landing page — feature detail stránky (/features/tikety, /features/oznamy, /features/hlasovanie, /features/dokumenty) |
| Jún 2026 | Landing page — kompletná (12 sekcií, privacy, terms, deployment na Vercel) |
| Jún 2026 | Feedback feature — FeedbackScreen v appke, edge function send-feedback-email, 019_feedback migrácia |
| Jún 2026 | Audit — CLAUDE.md navigácia opravená, /dodavatelia dead code označený |
| Jún 2026 | Back navigácia z "Ďalšie" — context.go → context.push (21 miest v app_router.dart) |
| Jún 2026 | Building units — opravené 4 UX chyby (poznámka na karte, delete error, zmena typu, validácia poschodia) |
| Jún 2026 | Building units — resident_name stĺpec chýbal v live DB, pridaný cez ALTER TABLE |
| Jún 2026 | Building units — sort opravený na numerický (1,2,3,10 namiesto 1,10,2,3) |
| Jún 2026 | Chat — Enter odošle správu (mobile + desktop), Shift+Enter = nový riadok |
| Jún 2026 | BuildingUnitsScreen — nová feature, /manager/building-units |
| Jún 2026 | Fix FCM token — ukladanie pri signedIn evente v app.dart |
| Máj 2026 | Admin panel — kompletný audit, všetky stránky funkčné |
| Máj 2026 | Password reset — funkčný end-to-end |
| Máj 2026 | Users stránka — všetky roly, farby, reset, delete |
