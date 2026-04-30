-- Migration 010: Enable Supabase Realtime for forum tables
--
-- Problem: forum_posts and forum_replies were never added to the supabase_realtime
-- publication. Without this, .stream() subscriptions receive only the initial
-- REST snapshot; INSERT/UPDATE/DELETE events are never broadcast live.

alter publication supabase_realtime add table forum_posts;
alter publication supabase_realtime add table forum_replies;
