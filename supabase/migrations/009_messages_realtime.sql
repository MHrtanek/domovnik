-- Migration 009: Enable Supabase Realtime for the messages table
--
-- Problem: the messages table was never added to the supabase_realtime publication.
-- Without this, .stream() subscriptions in ChatRepository receive only the initial
-- REST snapshot and no subsequent INSERT/UPDATE/DELETE events, so new messages
-- are not delivered live to either party.

alter publication supabase_realtime add table messages;
