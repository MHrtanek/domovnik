-- ============================================================
-- seed_demo.sql — demo data for the "Try demo" login button
-- ============================================================
-- Run this manually in the Supabase SQL editor (it is NOT run by CI/app).
--
-- What it creates:
--   * 1 demo building ("Demo — Bytový dom Lipová 12")
--   * 1 manager login account  → demo@domovnik.online / Demo1234!
--     (these MUST match DEMO_EMAIL / DEMO_PASSWORD in your .env)
--   * 10 residents (random passwords — they exist only to author content)
--   * 8 tickets (mixed statuses), 3 announcements, 2 polls with votes,
--     2 forum posts with replies, a chat thread, 2 reservations,
--     contacts and documents.
--
-- Idempotent: re-running first deletes the previous demo building and its
-- data, then recreates everything. Runs as one transaction — if anything
-- fails, nothing is committed.
--
-- How it works: inserting into auth.users fires the on_auth_user_created
-- trigger (handle_new_user), which creates the building + profile from the
-- user's metadata. We then capture the generated building_id and seed the
-- rest of the content against it.
-- ============================================================

do $$
declare
  v_instance     uuid := '00000000-0000-0000-0000-000000000000';
  v_demo_email   text := 'demo@domovnik.online';
  v_demo_pw      text := 'Demo1234!';
  v_building_name text := 'Demo — Bytový dom Lipová 12';

  v_manager_id   uuid := gen_random_uuid();
  v_building_id  uuid;

  v_res          uuid[] := '{}';          -- resident profile ids
  v_id           uuid;
  v_names        text[] := array[
                    'Ján Novák','Mária Kováčová','Peter Horváth','Zuzana Tóthová',
                    'Martin Varga','Eva Balážová','Michal Šimon','Lucia Krajčíová',
                    'Tomáš Polák','Andrea Ďuríková'];
  i              int;

  v_amenity1     uuid := gen_random_uuid();
  v_amenity2     uuid := gen_random_uuid();

  v_poll1        uuid := gen_random_uuid();
  v_poll2        uuid := gen_random_uuid();
  v_p1o1         uuid := gen_random_uuid();
  v_p1o2         uuid := gen_random_uuid();
  v_p1o3         uuid := gen_random_uuid();
  v_p2o1         uuid := gen_random_uuid();
  v_p2o2         uuid := gen_random_uuid();

  v_post1        uuid := gen_random_uuid();
  v_post2        uuid := gen_random_uuid();
begin
  -- ----------------------------------------------------------
  -- 0. Clean up a previous demo run (idempotency)
  -- ----------------------------------------------------------
  select id into v_building_id from public.buildings
    where name = v_building_name limit 1;

  if v_building_id is not null then
    delete from public.poll_votes    where building_id = v_building_id;
    delete from public.poll_options  where poll_id in (
      select id from public.polls where building_id = v_building_id);
    delete from public.polls         where building_id = v_building_id;
    delete from public.forum_replies where building_id = v_building_id;
    delete from public.forum_posts   where building_id = v_building_id;
    delete from public.messages      where building_id = v_building_id;
    delete from public.reservations  where building_id = v_building_id;
    delete from public.amenities     where building_id = v_building_id;
    delete from public.contacts      where building_id = v_building_id;
    delete from public.documents     where building_id = v_building_id;
    delete from public.tickets       where building_id = v_building_id;
    delete from public.announcements where building_id = v_building_id;
    -- break the building → manager FK before deleting users
    update public.buildings set manager_id = null where id = v_building_id;
    delete from auth.users where id in (
      select id from public.profiles where building_id = v_building_id);
    delete from public.buildings where id = v_building_id;
    v_building_id := null;
  end if;

  -- ----------------------------------------------------------
  -- 1. Manager (login account). Trigger creates building + profile.
  -- ----------------------------------------------------------
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change, email_change_token_new
  ) values (
    v_instance, v_manager_id, 'authenticated', 'authenticated',
    v_demo_email, crypt(v_demo_pw, gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object(
      'role','manager',
      'full_name','Demo Správca',
      'building_name', v_building_name,
      'building_address','Lipová 12, 821 01 Bratislava'),
    '', '', '', ''
  );

  insert into auth.identities (
    id, user_id, provider_id, provider, identity_data,
    last_sign_in_at, created_at, updated_at
  ) values (
    gen_random_uuid(), v_manager_id, v_manager_id::text, 'email',
    jsonb_build_object('sub', v_manager_id::text, 'email', v_demo_email,
                       'email_verified', true, 'phone_verified', false),
    now(), now(), now()
  );

  -- building_id was set by the trigger when it created the manager profile
  select building_id into v_building_id from public.profiles where id = v_manager_id;

  -- ----------------------------------------------------------
  -- 2. Residents (content authors). Trigger links them to the building.
  -- ----------------------------------------------------------
  for i in 1 .. array_length(v_names, 1) loop
    v_id := gen_random_uuid();
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data,
      confirmation_token, recovery_token, email_change, email_change_token_new
    ) values (
      v_instance, v_id, 'authenticated', 'authenticated',
      'resident' || i || '@demo.domovnik.local',
      crypt(gen_random_uuid()::text, gen_salt('bf')),
      now(), now(), now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('role','resident','full_name', v_names[i],
                         'building_id', v_building_id::text),
      '', '', '', ''
    );

    insert into auth.identities (
      id, user_id, provider_id, provider, identity_data,
      last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), v_id, v_id::text, 'email',
      jsonb_build_object('sub', v_id::text,
                         'email', 'resident' || i || '@demo.domovnik.local',
                         'email_verified', true, 'phone_verified', false),
      now(), now(), now()
    );

    update public.profiles set flat_number = i::text where id = v_id;
    v_res := array_append(v_res, v_id);
  end loop;

  -- ----------------------------------------------------------
  -- 3. Tickets (8, mixed statuses & categories)
  -- ----------------------------------------------------------
  insert into public.tickets (title, description, category, status, created_by, building_id, created_at) values
    ('Nesvieti svetlo v spoločných priestoroch', 'Na 3. poschodí nefunguje osvetlenie na chodbe už týždeň.', 'Elektrina', 'V riešení', v_res[1], v_building_id, now() - interval '6 days'),
    ('Kvapkajúci kohútik v práčovni', 'Z kohútika nad práčkou stále kvapká voda.', 'Vodoinštalácia', 'Prijaté', v_res[2], v_building_id, now() - interval '5 days'),
    ('Výťah sa zasekáva medzi 2. a 3. poschodím', 'Dnes ráno sa výťah dvakrát zasekol.', 'Výťah', 'V riešení', v_res[3], v_building_id, now() - interval '4 days'),
    ('Rozbité sklo na vstupných dverách', 'Pravé krídlo vstupných dverí má prasknuté sklo.', 'Spoločné priestory', 'Prijaté', v_res[4], v_building_id, now() - interval '3 days'),
    ('Upchatá kanalizácia v pivnici', 'Po daždi sa v pivnici objavuje voda, pravdepodobne upchatý odtok.', 'Vodoinštalácia', 'Ukončené', v_res[5], v_building_id, now() - interval '12 days'),
    ('Nefunkčný zvonček pri byte č. 7', 'Zvonček nereaguje, treba vymeniť.', 'Elektrina', 'Prijaté', v_res[6], v_building_id, now() - interval '2 days'),
    ('Poškodená dlažba v garáži', 'Pri parkovacom mieste 12 je uvoľnená dlažba.', 'Spoločné priestory', 'V riešení', v_res[7], v_building_id, now() - interval '8 days'),
    ('Hluk z technickej miestnosti', 'V noci je počuť hlasné hučanie z technickej miestnosti.', 'Iné', 'Ukončené', v_res[8], v_building_id, now() - interval '15 days');

  -- ----------------------------------------------------------
  -- 4. Announcements (3)
  -- ----------------------------------------------------------
  insert into public.announcements (title, content, is_urgent, created_by, building_id, created_at) values
    ('Plánovaná odstávka vody', 'V utorok od 8:00 do 14:00 bude odstávka teplej vody z dôvodu opravy stúpačky. Odporúčame zásobiť sa vodou vopred.', true, v_manager_id, v_building_id, now() - interval '1 day'),
    ('Brigáda — upratovanie okolia', 'V sobotu o 9:00 organizujeme spoločné upratovanie okolia domu. Náradie zabezpečíme, prineste si pracovné rukavice.', false, v_manager_id, v_building_id, now() - interval '4 days'),
    ('Revízia elektroinštalácie', 'Budúci týždeň prebehne povinná revízia elektroinštalácie. Technik bude potrebovať prístup do spoločných priestorov.', false, v_manager_id, v_building_id, now() - interval '7 days');

  -- ----------------------------------------------------------
  -- 5. Polls (2) with options and votes
  -- ----------------------------------------------------------
  insert into public.polls (id, question, building_id, created_by, expires_at, created_at) values
    (v_poll1, 'Máme zrekonštruovať vstupný vchod?', v_building_id, v_manager_id, now() + interval '7 days', now() - interval '3 days'),
    (v_poll2, 'Kedy preferujete spoločnú brigádu?', v_building_id, v_manager_id, now() + interval '10 days', now() - interval '2 days');

  insert into public.poll_options (id, poll_id, option_text) values
    (v_p1o1, v_poll1, 'Áno, kompletná rekonštrukcia'),
    (v_p1o2, v_poll1, 'Stačí vymaľovanie'),
    (v_p1o3, v_poll1, 'Nie, netreba'),
    (v_p2o1, v_poll2, 'Sobota doobeda'),
    (v_p2o2, v_poll2, 'Nedeľa poobede');

  insert into public.poll_votes (poll_id, option_id, user_id, building_id) values
    (v_poll1, v_p1o1, v_res[1], v_building_id),
    (v_poll1, v_p1o1, v_res[2], v_building_id),
    (v_poll1, v_p1o1, v_res[3], v_building_id),
    (v_poll1, v_p1o2, v_res[4], v_building_id),
    (v_poll1, v_p1o2, v_res[5], v_building_id),
    (v_poll1, v_p1o3, v_res[6], v_building_id),
    (v_poll2, v_p2o1, v_res[1], v_building_id),
    (v_poll2, v_p2o1, v_res[2], v_building_id),
    (v_poll2, v_p2o1, v_res[7], v_building_id),
    (v_poll2, v_p2o2, v_res[8], v_building_id),
    (v_poll2, v_p2o2, v_res[9], v_building_id);

  -- ----------------------------------------------------------
  -- 6. Forum posts (2) with replies
  -- ----------------------------------------------------------
  insert into public.forum_posts (id, title, content, created_by, building_id, likes_count, created_at) values
    (v_post1, 'Odporúčanie na dobrého elektrikára?', 'Potrebujem prerobiť elektriku v byte. Vie niekto odporučiť spoľahlivého elektrikára z okolia?', v_res[2], v_building_id, 3, now() - interval '5 days'),
    (v_post2, 'Parkovanie pred vchodom', 'Opäť tu parkujú cudzie autá a blokujú vjazd. Mohli by sme to nejako riešiť?', v_res[4], v_building_id, 5, now() - interval '2 days');

  insert into public.forum_replies (content, post_id, created_by, building_id, likes_count, created_at) values
    ('Volal som pánovi Horváthovi, robil mi to minulý rok — super práca a férová cena.', v_post1, v_res[3], v_building_id, 2, now() - interval '4 days'),
    ('Ja mám kontakt, pošlem ti ho do správy.', v_post1, v_res[5], v_building_id, 1, now() - interval '4 days'),
    ('Súhlasím, navrhujem dať na schôdzu hlasovanie o závore.', v_post2, v_res[1], v_building_id, 4, now() - interval '1 day');

  -- ----------------------------------------------------------
  -- 7. Chat thread (manager ↔ resident 1)
  -- ----------------------------------------------------------
  insert into public.messages (building_id, sender_id, receiver_id, content, read, created_at) values
    (v_building_id, v_res[1], v_manager_id, 'Dobrý deň, kedy sa bude riešiť svetlo na chodbe?', true,  now() - interval '2 days'),
    (v_building_id, v_manager_id, v_res[1], 'Dobrý deň, elektrikár príde vo štvrtok doobeda.', true,  now() - interval '2 days' + interval '1 hour'),
    (v_building_id, v_res[1], v_manager_id, 'Super, ďakujem za info!', false, now() - interval '2 days' + interval '2 hours');

  -- ----------------------------------------------------------
  -- 8. Amenities + reservations
  -- ----------------------------------------------------------
  insert into public.amenities (id, name, description, building_id) values
    (v_amenity1, 'Spoločenská miestnosť', 'Kapacita 20 osôb, kuchynka.', v_building_id),
    (v_amenity2, 'Práčovňa', 'Dve práčky a sušička.', v_building_id);

  insert into public.reservations (amenity_id, building_id, resident_id, date, time_from, time_to, note) values
    (v_amenity1, v_building_id, v_res[1], (current_date + 3)::text, '16:00', '19:00', 'Oslava narodenín'),
    (v_amenity2, v_building_id, v_res[2], (current_date + 1)::text, '10:00', '12:00', 'Veľké pranie');

  -- ----------------------------------------------------------
  -- 9. Contacts
  -- ----------------------------------------------------------
  insert into public.contacts (building_id, name, phone, description, created_by) values
    (v_building_id, 'Demo Správca', '+421 900 123 456', 'Správca budovy', v_manager_id),
    (v_building_id, 'Údržbár Jozef', '+421 905 222 333', 'Bežná údržba a opravy', v_manager_id),
    (v_building_id, 'Pohotovostná výťahová služba', '+421 800 111 222', 'Poruchy výťahu 24/7', v_manager_id);

  -- ----------------------------------------------------------
  -- 10. Documents
  -- ----------------------------------------------------------
  insert into public.documents (building_id, name, file_url, file_size, created_by) values
    (v_building_id, 'Domový poriadok.pdf', 'https://example.com/demo/domovy_poriadok.pdf', 184320, v_manager_id),
    (v_building_id, 'Zápisnica zo schôdze 2026.pdf', 'https://example.com/demo/zapisnica_2026.pdf', 256000, v_manager_id),
    (v_building_id, 'Vyúčtovanie 2025.pdf', 'https://example.com/demo/vyuctovanie_2025.pdf', 512000, v_manager_id);

  raise notice 'Demo seed complete. Building %, manager %, % residents.',
    v_building_id, v_manager_id, array_length(v_res, 1);
end $$;
