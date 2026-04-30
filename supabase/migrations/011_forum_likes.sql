-- Migration 011: Add likes_count to forum_posts and forum_replies

alter table forum_posts
  add column if not exists likes_count integer not null default 0;

alter table forum_replies
  add column if not exists likes_count integer not null default 0;
