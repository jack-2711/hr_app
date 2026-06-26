const express = require('express');
const supabase = require('../db/supabase');

const router = express.Router();

// GET /api/employee/:id/stats
router.get('/:id/stats', async (req, res) => {
  try {
    const userId = req.params.id;

    // Fetch all leaves for this employee
    const { data: leaves } = await supabase
      .from('leave_requests')
      .select('*')
      .eq('employee_id', userId)
      .order('created_at', { ascending: false });

    let casualLeaves = 0;
    let sickLeaves = 0;
    let lopAmount = 0.0;

    for (const leave of leaves || []) {
      if (leave.status && leave.status.toLowerCase() === 'approved') {
        const start = new Date(leave.start_date);
        const end = new Date(leave.end_date);
        const days = Math.ceil((end - start) / (1000 * 60 * 60 * 24)) + 1;

        if (leave.leave_type === 'casual') casualLeaves += days;
        if (leave.leave_type === 'sick') sickLeaves += days;
        if (leave.leave_type === 'Loss of Pay (LOP)') lopAmount += days * 500;
      }
    }

    // Determine today's shift state
    const today = new Date().toISOString().split('T')[0];
    const { data: attendance } = await supabase
      .from('attendance')
      .select('*')
      .eq('employee_id', userId)
      .gte('created_at', today)
      .order('created_at', { ascending: false })
      .limit(1);

    let shiftState = 'not_started';
    if (attendance && attendance.length > 0) {
      const existing = attendance[0];
      if (existing.clock_out) shiftState = 'completed';
      else if (existing.break_start_time && !existing.break_end_time) shiftState = 'on_break';
      else if (existing.clock_in) shiftState = 'working';
    }

    // Fetch recent attendance history
    const { data: attendanceHistory } = await supabase
      .from('attendance')
      .select('*')
      .eq('employee_id', userId)
      .order('created_at', { ascending: false })
      .limit(30);

    // Check if face is registered
    const { data: profile } = await supabase
      .from('profiles')
      .select('face_embedding')
      .eq('id', userId)
      .single();

    res.json({
      casualLeaves,
      sickLeaves,
      lopAmount,
      shiftState,
      isRegistered: !!(profile && profile.face_embedding),
      attendanceHistory: attendanceHistory || [],
      leaveRequests: leaves || [],
    });
  } catch (err) {
    console.error('Stats error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/employee/leave
router.post('/leave', async (req, res, next) => {
  try {
    const { employee_id, leave_type, start_date, end_date, reason } = req.body;
    if (!employee_id || !leave_type || !start_date || !end_date) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const { data, error } = await supabase
      .from('leave_requests')
      .insert({
        employee_id,
        leave_type,
        start_date,
        end_date,
        reason,
        status: 'pending',
      })
      .select();

    if (error) throw error;
    res.json({ message: 'Leave request submitted successfully', data: data[0] });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
