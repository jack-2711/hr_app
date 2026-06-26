const express = require('express');
const bcrypt = require('bcryptjs');
const supabase = require('../db/supabase');

const router = express.Router();

const SENTINEL_ID = '00000000-0000-0000-0000-000000000000';

// Helper: parse settings from sentinel profile row
async function getSettings() {
  const { data } = await supabase
    .from('profiles')
    .select('full_name')
    .eq('id', SENTINEL_ID)
    .single();
  try {
    return JSON.parse(data?.full_name || '{}');
  } catch (e) {
    return {};
  }
}

// GET /api/admin/dashboard
router.get('/dashboard', async (req, res) => {
  try {
    const todayStr = new Date().toISOString().split('T')[0];
    const settings = await getSettings();

    // Total employees (exclude sentinel)
    const { data: allProfiles } = await supabase
      .from('profiles')
      .select('*')
      .neq('id', SENTINEL_ID);

    // Approved leaves today
    const { data: approvedLeaves } = await supabase
      .from('leave_requests')
      .select('id')
      .eq('status', 'approved')
      .lte('start_date', todayStr)
      .gte('end_date', todayStr);

    // Today's attendance entries
    const { data: todaysEntries } = await supabase
      .from('attendance')
      .select('*, profiles(full_name)')
      .gte('created_at', todayStr);

    // Pending leave requests
    const { data: pendingLvs } = await supabase
      .from('leave_requests')
      .select('*, profiles(full_name)')
      .eq('status', 'pending')
      .order('created_at', { ascending: false });

    // MTD Payroll
    const currentMonth = new Date().toISOString().slice(0, 7);
    const { data: payrollData } = await supabase
      .from('payroll')
      .select('net_salary')
      .eq('billing_month', currentMonth);

    const mtdPayroll = (payrollData || []).reduce(
      (sum, p) => sum + Number(p.net_salary || 0),
      0
    );

    // LOP Savings
    const { data: lopData } = await supabase
      .from('payroll')
      .select('lop_deduction')
      .eq('billing_month', currentMonth);

    const lopSaved = (lopData || []).reduce(
      (sum, p) => sum + Number(p.lop_deduction || 0),
      0
    );

    // Dynamic chart data (last 6 months attendance rate)
    const dynamicChartData = [];
    const now = new Date();
    for (let i = 5; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const monthStr = d.toISOString().slice(0, 7);
      const monthName = d.toLocaleString('default', { month: 'short' });
      const { count } = await supabase
        .from('attendance')
        .select('*', { count: 'exact', head: true })
        .gte('created_at', `${monthStr}-01`)
        .lt(
          'created_at',
          `${new Date(d.getFullYear(), d.getMonth() + 1, 1).toISOString().slice(0, 10)}`
        );

      const totalEmployees = allProfiles?.length || 1;
      const workDays = 22;
      const attendance = Math.min(
        100,
        Math.round(((count || 0) / (totalEmployees * workDays)) * 100)
      );
      dynamicChartData.push({ name: monthName, attendance });
    }

    // HR Alerts (from alerts table)
    const { data: hrAlerts } = await supabase
      .from('alerts')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(5);

    res.json({
      stats: {
        totalEmployees: allProfiles?.length || 0,
        activeToday: allProfiles?.filter((p) => p.status === 'active').length || 0,
        onLeaveToday: approvedLeaves?.length || 0,
        liveClockIns:
          todaysEntries?.filter((e) => e.clock_in && !e.clock_out).length || 0,
        onBreakToday:
          todaysEntries?.filter((e) => e.break_start_time && !e.break_end_time)
            .length || 0,
        mtdPayroll,
        lopSaved,
      },
      pendingLeaves: pendingLvs || [],
      pendingOvertime: [],
      hrAlerts: hrAlerts || [],
      dynamicChartData,
    });
  } catch (err) {
    console.error('Dashboard error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/admin/employees
router.get('/employees', async (req, res) => {
  try {
    const { data: profiles } = await supabase
      .from('profiles')
      .select('*')
      .order('created_at', { ascending: false });

    const employees = (profiles || []).filter((p) => p.id !== SENTINEL_ID);

    // Get leaves taken per employee
    const { data: allLeaves } = await supabase
      .from('leave_requests')
      .select('employee_id, leave_type, start_date, end_date, status')
      .eq('status', 'approved');

    const leavesTaken = {};
    let maxLeaves = 0;

    const settings = await getSettings();
    maxLeaves =
      Number(settings.sickAllowance || 7) +
      Number(settings.casualAllowance || 3);

    for (const leave of allLeaves || []) {
      const days =
        (new Date(leave.end_date) - new Date(leave.start_date)) /
          (1000 * 60 * 60 * 24) +
        1;
      leavesTaken[leave.employee_id] =
        (leavesTaken[leave.employee_id] || 0) + days;
    }

    // Remove sensitive fields
    employees.forEach((emp) => {
      delete emp.password;
      delete emp.face_embedding;
    });

    res.json({ employees, leavesTaken, maxLeaves });
  } catch (err) {
    console.error('Employees error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/admin/employees — Provision new employee
router.post('/employees', async (req, res) => {
  try {
    const { full_name, email, password, role, per_day_rate } = req.body;
    if (!full_name || !email || !password) {
      return res.status(400).json({ error: 'Name, email, and password are required' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const { data, error } = await supabase
      .from('profiles')
      .insert({
        full_name,
        email,
        password: hashedPassword,
        role: role || 'employee',
        per_day_rate: per_day_rate || 0,
        base_salary: (per_day_rate || 0) * 30,
      })
      .select();

    if (error) {
        console.error('Provision DB Error:', error);
        return res.status(500).json({ error: error.message });
    }

    // Remove sensitive fields
    if (data && data[0]) {
      delete data[0].password;
      delete data[0].face_embedding;
    }

    res.json({ message: 'Employee provisioned successfully', data });
  } catch (err) {
    console.error('Provision error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/admin/employees/:id — Update employee
router.put('/employees/:id', async (req, res) => {
  try {
    const { full_name, email, role, per_day_rate, base_salary } = req.body;
    const updates = {};
    if (full_name !== undefined) updates.full_name = full_name;
    if (email !== undefined) updates.email = email;
    if (role !== undefined) updates.role = role;
    if (per_day_rate !== undefined) updates.per_day_rate = per_day_rate;
    if (base_salary !== undefined) updates.base_salary = base_salary;

    const { data, error } = await supabase
      .from('profiles')
      .update(updates)
      .eq('id', req.params.id)
      .select();

    if (error) throw error;

    if (data && data[0]) {
      delete data[0].password;
      delete data[0].face_embedding;
    }

    res.json({ message: 'Employee updated successfully', data });
  } catch (err) {
    console.error('Update employee error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/admin/leaves — All leave requests with profiles
router.get('/leaves', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('leave_requests')
      .select('*, profiles(full_name)')
      .order('created_at', { ascending: false });

    if (error) throw error;
    res.json(data || []);
  } catch (err) {
    console.error('Leaves error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/admin/leaves/:id/status — Update leave status
router.put('/leaves/:id/status', async (req, res) => {
  try {
    const { status } = req.body;
    if (!['pending', 'approved', 'rejected'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }

    const { error } = await supabase
      .from('leave_requests')
      .update({ status })
      .eq('id', req.params.id);

    if (error) throw error;
    res.json({ message: `Leave ${status} successfully` });
  } catch (err) {
    console.error('Update leave status error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/admin/timesheets — All attendance records with profiles
router.get('/timesheets', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('attendance')
      .select('*, profiles(full_name, email)')
      .order('created_at', { ascending: false });

    if (error) throw error;
    res.json(data || []);
  } catch (err) {
    console.error('Timesheets error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/admin/settings — Get global settings
router.get('/settings', async (req, res) => {
  try {
    const settings = await getSettings();
    res.json(settings);
  } catch (err) {
    console.error('Get settings error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/admin/settings — Save global settings
router.post('/settings', async (req, res) => {
  try {
    const settingsJson = JSON.stringify(req.body);
    const { error } = await supabase
      .from('profiles')
      .update({ full_name: settingsJson })
      .eq('id', SENTINEL_ID);

    if (error) throw error;
    res.json({ message: 'Settings synchronized globally.' });
  } catch (err) {
    console.error('Save settings error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
