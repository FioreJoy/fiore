CREATE TABLE IF NOT EXISTS public.user_blocks (
    blocker_id INT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    blocked_id INT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (blocker_id, blocked_id),
    -- Prevent users from blocking themselves
    CONSTRAINT check_blocker_not_blocked CHECK (blocker_id <> blocked_id)
);

-- Add indexes for efficient lookups
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON public.user_blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON public.user_blocks(blocked_id);