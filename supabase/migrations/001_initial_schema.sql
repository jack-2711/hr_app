-- PROFILES TABLE
CREATE TABLE profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    password TEXT NOT NULL,
    role TEXT CHECK (role IN ('employee', 'hr', 'admin')) DEFAULT 'employee',
    status TEXT DEFAULT 'active',
    per_day_rate NUMERIC DEFAULT 0,
    base_salary NUMERIC DEFAULT 0,
    basic_percent NUMERIC DEFAULT 50,
    hra_percent NUMERIC DEFAULT 30,
    da_percent NUMERIC DEFAULT 20,
    pf_percent NUMERIC DEFAULT 12,
    tax_percent NUMERIC DEFAULT 10,
    manual_leave_adjustment NUMERIC DEFAULT 0,
    join_date DATE DEFAULT CURRENT_DATE,
    last_working_day DATE,
    face_embedding JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ATTENDANCE TABLE
CREATE TABLE attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    clock_in TIMESTAMP WITH TIME ZONE,
    clock_out TIMESTAMP WITH TIME ZONE,
    break_start_time TIMESTAMP WITH TIME ZONE,
    break_end_time TIMESTAMP WITH TIME ZONE,
    working_hours NUMERIC,
    total_break_duration NUMERIC,
    action TEXT, -- For simple logging if needed
    standard_start_time TIME DEFAULT '09:00',
    standard_end_time TIME DEFAULT '18:00',
    half_day_late_threshold INTEGER DEFAULT 120,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- LEAVE REQUESTS TABLE
CREATE TABLE leave_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    leave_type TEXT NOT NULL, -- 'casual', 'sick', 'Loss of Pay (LOP)'
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT,
    status TEXT CHECK (status IN ('pending', 'approved', 'rejected')) DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- PAYROLL TABLE
CREATE TABLE payroll (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    billing_month TEXT NOT NULL, -- e.g., '2024-06'
    basic_pay NUMERIC,
    hra NUMERIC,
    da NUMERIC,
    other_allowances NUMERIC DEFAULT 0,
    overtime_bonus NUMERIC DEFAULT 0,
    calculated_salary NUMERIC,
    tax_deduction NUMERIC DEFAULT 0,
    pf_deduction NUMERIC DEFAULT 0,
    lop_deduction NUMERIC DEFAULT 0,
    lop_days_counted NUMERIC DEFAULT 0,
    net_salary NUMERIC,
    is_finalized BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- SETTINGS (Stored in profiles with a sentinel ID)
-- This matches the logic in admin.js
INSERT INTO profiles (id, email, full_name, password, role)
VALUES ('00000000-0000-0000-0000-000000000000', 'settings@hrconnect.internal', '{}', 'internal', 'admin')
ON CONFLICT DO NOTHING;
