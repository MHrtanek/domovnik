-- Migration 017: Forum like duplicate protection

create table if not exists post_likes (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid references forum_posts(id) on delete cascade not null,
  user_id    uuid references profiles(id) on delete cascade not null,
  created_at timestamptz default now(),
  unique(post_id, user_id)
);

create table if not exists reply_likes (
  id         uuid primary key default gen_random_uuid(),
  reply_id   uuid references forum_replies(id) on delete cascade not null,
  user_id    uuid references profiles(id) on delete cascade not null,
  created_at timestamptz default now(),
  unique(reply_id, user_id)
);

alter table forum_posts add column if not exists likes_count int default 0;
alter table forum_replies add column if not exists likes_count int default 0;

create or replace function increment_post_likes(p_post_id uuid, p_user_id uuid)
returns void language plpgsql as $$
begin
  insert into post_likes(post_id, user_id) values (p_post_id, p_user_id)
  on conflict (post_id, user_id) do nothing;
  update forum_posts set likes_count = (
    select count(*) from post_likes where post_id = p_post_id
  ) where id = p_post_id;
end;
$$;

create or replace function increment_reply_likes(p_reply_id uuid, p_user_id uuid)
returns void language plpgsql as $$
begin
  insert into reply_likes(reply_id, user_id) values (p_reply_id, p_user_id)
  on conflict (reply_id, user_id) do nothing;
  update forum_replies set likes_count = (
    select count(*) from reply_likes where reply_id = p_reply_id
  ) where id = p_reply_id;
end;
$$;

-- RLS
alter table post_likes enable row level security;
alter table reply_likes enable row level security;

create policy "Users can insert own likes" on post_likes
  for insert with check (auth.uid() = user_id);
create policy "Anyone can view likes" on post_likes
  for select using (true);

create policy "Users can insert own likes" on reply_likes
  for insert with check (auth.uid() = user_id);
create policy "Anyone can view likes" on reply_likes
  for select using (true);
