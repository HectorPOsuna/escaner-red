INSERT INTO users (username, password_hash, role, created_at) 
VALUES (
    'admin',
    '$2y$10$Jh0a.e5MbiUcc7GmDs5O7ushXuCZbnSBHKQTSfLrpEYV/V5DBf7he',
    'admin',
    NOW()
);