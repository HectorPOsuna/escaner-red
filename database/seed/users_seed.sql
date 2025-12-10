-- Password is 'admin123' hashed with bcrypt
-- Generated using PHP password_hash('admin123', PASSWORD_BCRYPT) or online generator
-- Replace with a fresh hash if needed for production security
INSERT INTO users (username, password_hash, role) VALUES 
('admin', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin')
ON DUPLICATE KEY UPDATE role='admin';
