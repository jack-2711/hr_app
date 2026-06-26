-- Add missing columns to the existing profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS password TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS per_day_rate NUMERIC DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS base_salary NUMERIC DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS basic_percent NUMERIC DEFAULT 50;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS hra_percent NUMERIC DEFAULT 30;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS da_percent NUMERIC DEFAULT 20;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS pf_percent NUMERIC DEFAULT 12;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS tax_percent NUMERIC DEFAULT 10;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS manual_leave_adjustment NUMERIC DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS join_date DATE DEFAULT CURRENT_DATE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_working_day DATE;

-- Ensure RLS is disabled for now to allow the node backend to work easily
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';
