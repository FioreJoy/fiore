CREATE TABLE user_followers (
    follower_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    following_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (follower_id, following_id)
);

CREATE INDEX idx_followers_follower ON user_followers(follower_id);
CREATE INDEX idx_followers_following ON user_followers(following_id);

-- Add mock follower relationships
INSERT INTO user_followers (follower_id, following_id) VALUES
(1, 2), -- User 1 follows User 2
(1, 3), -- User 1 follows User 3
(2, 1), -- User 2 follows User 1
(3, 1), -- User 3 follows User 1
(4, 1), -- User 4 follows User 1
(5, 1), -- User 5 follows User 1
(2, 3), -- User 2 follows User 3
(3, 4), -- User 3 follows User 4
(4, 5)  -- User 4 follows User 5
ON CONFLICT DO NOTHING;

ALTER TABLE users ADD COLUMN current_location_address TEXT NULL
