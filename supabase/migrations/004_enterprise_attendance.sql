-- OFFICE LOCATIONS TABLE
CREATE TABLE office_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    latitude NUMERIC NOT NULL,
    longitude NUMERIC NOT NULL,
    radius_meters NUMERIC DEFAULT 100,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert default Head Office location (this replaces the hardcoded values)
INSERT INTO office_locations (id, name, latitude, longitude, radius_meters)
VALUES ('11111111-1111-1111-1111-111111111111', 'Head Office', 12.9038, 80.1472, 500)
ON CONFLICT DO NOTHING;

-- BREAK SESSIONS TABLE
CREATE TABLE break_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    attendance_id UUID REFERENCES attendance(id) ON DELETE CASCADE,
    break_out_time TIMESTAMP WITH TIME ZONE NOT NULL,
    break_in_time TIMESTAMP WITH TIME ZONE,
    duration_hours NUMERIC DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
