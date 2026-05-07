-- Migration 018: Add SECURITY DEFINER to like RPCs so any user can update likes_count

create or replace function increment_post_likes(p_post_id uuid, p_user_id uuid)
returns void language plpgsql security definer as $$
begin
  insert into post_likes(post_id, user_id) values (p_post_id, p_user_id)
  on conflict (post_id, user_id) do nothing;
  update forum_posts set likes_count = (
    select count(*) from post_likes where post_id = p_post_id
  ) where id = p_post_id;
end;
$$;

create or replace function increment_reply_likes(p_reply_id uuid, p_user_id uuid)
returns void language plpgsql security definer as $$
begin
  insert into reply_likes(reply_id, user_id) values (p_reply_id, p_user_id)
  on conflict (reply_id, user_id) do nothing;
  update forum_replies set likes_count = (
    select count(*) from reply_likes where reply_id = p_reply_id
  ) where id = p_reply_id;
end;
$$;
