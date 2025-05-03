ALTER TABLE public.users
ADD COLUMN notify_new_post_in_community BOOLEAN DEFAULT TRUE,
ADD COLUMN notify_new_reply_to_post BOOLEAN DEFAULT TRUE,
ADD COLUMN notify_new_event_in_community BOOLEAN DEFAULT TRUE,
ADD COLUMN notify_event_reminder BOOLEAN DEFAULT TRUE,
ADD COLUMN notify_direct_message BOOLEAN DEFAULT FALSE;
