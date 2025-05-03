-- Create the main media item table
CREATE TABLE IF NOT EXISTS public.media_items (
    id SERIAL PRIMARY KEY,
    uploader_user_id INT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    minio_object_name TEXT NOT NULL UNIQUE, -- Path within the bucket (e.g., media/posts/123/uuid.jpg)
    mime_type VARCHAR(100) NOT NULL,       -- e.g., image/jpeg, video/mp4, image/gif
    file_size_bytes BIGINT,                -- Optional: size in bytes
    original_filename TEXT,                -- Optional: original name from upload
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- Optional metadata fields (can be JSONB too)
    width INT,
    height INT,
    duration_seconds FLOAT -- For audio/video
    -- metadata JSONB -- Alternative for flexible metadata
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_media_items_uploader ON public.media_items(uploader_user_id);
CREATE INDEX IF NOT EXISTS idx_media_items_minio_object ON public.media_items(minio_object_name); -- If lookup by path needed

-- Remove old single image path columns (run AFTER data migration if needed)
ALTER TABLE public.users DROP COLUMN IF EXISTS image_path;
ALTER TABLE public.communities DROP COLUMN IF EXISTS logo_path;
ALTER TABLE public.posts DROP COLUMN IF EXISTS image_path;
-- Add similar DROPs for any other single media path columns you might have added

-- Create Linking Tables (Junction Tables)

CREATE TABLE IF NOT EXISTS public.post_media (
    post_id INT NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    media_id INT NOT NULL REFERENCES public.media_items(id) ON DELETE CASCADE,
    display_order SMALLINT DEFAULT 0, -- Optional: for ordering multiple media items
    PRIMARY KEY (post_id, media_id)
);
CREATE INDEX IF NOT EXISTS idx_post_media_media ON public.post_media(media_id);

CREATE TABLE IF NOT EXISTS public.reply_media (
    reply_id INT NOT NULL REFERENCES public.replies(id) ON DELETE CASCADE,
    media_id INT NOT NULL REFERENCES public.media_items(id) ON DELETE CASCADE,
    display_order SMALLINT DEFAULT 0,
    PRIMARY KEY (reply_id, media_id)
);
CREATE INDEX IF NOT EXISTS idx_reply_media_media ON public.reply_media(media_id);

CREATE TABLE IF NOT EXISTS public.chat_message_media (
    message_id INT NOT NULL REFERENCES public.chat_messages(id) ON DELETE CASCADE,
    media_id INT NOT NULL REFERENCES public.media_items(id) ON DELETE CASCADE,
    PRIMARY KEY (message_id, media_id) -- Assuming one media per message for now, adjust if multiple needed
);
CREATE INDEX IF NOT EXISTS idx_chat_message_media_media ON public.chat_message_media(media_id);

-- Tables for specific single items like profile picture / logo
CREATE TABLE IF NOT EXISTS public.user_profile_picture (
    user_id INT PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    media_id INT NOT NULL REFERENCES public.media_items(id) ON DELETE RESTRICT, -- Prevent deleting media if used as profile pic? Or CASCADE?
    set_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_user_profile_picture_media ON public.user_profile_picture(media_id);

CREATE TABLE IF NOT EXISTS public.community_logo (
    community_id INT PRIMARY KEY REFERENCES public.communities(id) ON DELETE CASCADE,
    media_id INT NOT NULL REFERENCES public.media_items(id) ON DELETE RESTRICT,
    set_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_community_logo_media ON public.community_logo(media_id);

-- Add tables for event banners etc. similarly if needed