CREATE TABLE IF NOT EXISTS alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT DEFAULT 'general',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Sample Alert
INSERT INTO alerts (title, message, type)
VALUES ('Welcome to HR Connect', 'Please register your biometric profile to start checking in.', 'system');
