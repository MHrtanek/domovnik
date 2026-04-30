-- Migration 012: Add photo_urls array to announcements table

alter table announcements
  add column if not exists photo_urls text[] not null default '{}';
