const express = require('express');
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

// GET /api/payroll/:month
router.get('/:month', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('payroll')
      .select(
        '*, profiles!payroll_employee_id_fkey ( id, full_name, base_salary, per_day_rate, status )'
      )
      .eq('billing_month', req.params.month)
      .order('calculated_salary', { ascending: false });

    if (error) throw error;
    res.json(data || []);
  } catch (err) {
    console.error('Payroll fetch error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/payroll/generate
router.post('/generate', async (req, res) => {
  try {
    const { selectedMonth, allowances } = req.body;
    const [yearStr, monthStr] = selectedMonth.split('-');
    const year = parseInt(yearStr);
    const month = parseInt(monthStr) - 1;
    const now = new Date();
    const endOfMonth = new Date(year, month + 1, 0);
    const startOfYear = new Date(year, 0, 1);

    // Fetch all employees (exclude sentinel)
    const { data: employees } = await supabase
      .from('profiles')
      .select('*')
      .neq('id', SENTINEL_ID);

    // Fetch approved leaves for the year up to the selected month
    const { data: leaves } = await supabase
      .from('leave_requests')
      .select('*')
      .eq('status', 'approved')
      .gte('start_date', startOfYear.toISOString().split('T')[0])
      .lte('start_date', endOfMonth.toISOString().split('T')[0]);

    // Fetch attendance logs for the year
    const { data: attendanceLogs } = await supabase
      .from('attendance')
      .select('*')
      .gte('created_at', startOfYear.toISOString().split('T')[0])
      .lte('created_at', endOfMonth.toISOString().split('T')[0]);

    // Previous LOP already deducted
    const pastPayrolls = (
      await supabase
        .from('payroll')
        .select('employee_id, lop_days_counted')
        .gte('billing_month', `${year}-01`)
        .lt('billing_month', selectedMonth)
    ).data;

    const previousLopDeducted = {};
    pastPayrolls?.forEach((p) => {
      previousLopDeducted[p.employee_id] =
        (previousLopDeducted[p.employee_id] || 0) +
        Number(p.lop_days_counted || 0);
    });

    // Half-day penalties from late arrivals
    const halfDayPenalties = {};
    attendanceLogs?.forEach((log) => {
      if (
        log.clock_in &&
        log.standard_start_time &&
        log.half_day_late_threshold
      ) {
        const [startH, startM] = log.standard_start_time
          .split(':')
          .map(Number);
        const maxAllowedMins =
          startH * 60 + startM + Number(log.half_day_late_threshold);
        const clockInDate = new Date(log.clock_in);
        const inMins = clockInDate.getHours() * 60 + clockInDate.getMinutes();
        if (inMins > maxAllowedMins) {
          halfDayPenalties[log.employee_id] =
            (halfDayPenalties[log.employee_id] || 0) + 0.5;
        }
      }
    });

    // Overtime hours for the selected month
    const overtimeBonus = {};
    attendanceLogs?.forEach((log) => {
      const logDate = new Date(
        log.clock_in || log.clock_out || log.created_at
      );
      if (
        logDate.getMonth() === month &&
        log.clock_out &&
        log.working_hours &&
        log.standard_start_time &&
        log.standard_end_time
      ) {
        const [startH, startM] = log.standard_start_time
          .split(':')
          .map(Number);
        const [endH, endM] = log.standard_end_time.split(':').map(Number);
        const standardHrs = (endH * 60 + endM - (startH * 60 + startM)) / 60;
        const ot = Math.max(0, log.working_hours - standardHrs);
        if (ot > 0) {
          overtimeBonus[log.employee_id] =
            (overtimeBonus[log.employee_id] || 0) + ot;
        }
      }
    });

    // Generate payroll for each employee
    const newPayrolls = (employees || []).map((emp) => {
      const empLeaves =
        leaves?.filter(
          (l) =>
            l.employee_id === emp.id &&
            (l.leave_type === 'sick' || l.leave_type === 'casual')
        ) || [];

      let leavesBeforeThisMonth = 0;
      let leavesThisMonth = 0;

      empLeaves.forEach((leave) => {
        const start = new Date(leave.start_date);
        const end = new Date(leave.end_date);
        const days =
          Math.ceil((end - start) / (1000 * 60 * 60 * 24)) + 1;
        if (end < new Date(year, month, 1)) {
          leavesBeforeThisMonth += days;
        } else {
          leavesThisMonth += days;
        }
      });

      const totalYTDLeaves =
        leavesBeforeThisMonth +
        leavesThisMonth +
        (halfDayPenalties[emp.id] || 0) +
        (emp.manual_leave_adjustment || 0);

      const lopDaysThisMonth = Math.max(
        0,
        Math.max(
          0,
          totalYTDLeaves - (allowances.sick + allowances.casual)
        ) - (previousLopDeducted[emp.id] || 0)
      );

      const rate = emp.per_day_rate || 0;
      const baseSalary = emp.base_salary || rate * 30;

      // Calculate active days in the month
      const totalDaysInMonth = endOfMonth.getDate();
      const joinDate = emp.join_date ? new Date(emp.join_date) : null;
      const lwd = emp.last_working_day
        ? new Date(emp.last_working_day)
        : null;

      let calcStartDay =
        joinDate &&
        joinDate.getFullYear() === year &&
        joinDate.getMonth() === month
          ? joinDate.getDate()
          : 1;
      let calcEndDay =
        lwd && lwd.getFullYear() === year && lwd.getMonth() === month
          ? lwd.getDate()
          : totalDaysInMonth;

      let activeDaysInMonth = 0;
      if (
        !(
          year > now.getFullYear() ||
          (year === now.getFullYear() && month > now.getMonth())
        )
      ) {
        if (
          year === now.getFullYear() &&
          month === now.getMonth() &&
          now.getDate() !== totalDaysInMonth
        ) {
          activeDaysInMonth = Math.max(
            0,
            Math.min(now.getDate(), calcEndDay) - calcStartDay + 1
          );
        } else {
          activeDaysInMonth = Math.max(0, calcEndDay - calcStartDay + 1);
        }
      }

      if (
        (joinDate && joinDate > endOfMonth) ||
        (lwd && lwd < new Date(year, month, 1))
      ) {
        activeDaysInMonth = 0;
      }

      const effectiveBaseSalary = (activeDaysInMonth / 30) * baseSalary;
      const basicPay = Number(
        (effectiveBaseSalary * ((emp.basic_percent ?? 50) / 100)).toFixed(2)
      );
      const hra = Number(
        (effectiveBaseSalary * ((emp.hra_percent ?? 30) / 100)).toFixed(2)
      );
      const da = Number(
        (effectiveBaseSalary * ((emp.da_percent ?? 20) / 100)).toFixed(2)
      );
      const calculatedOtBonus = Number(
        ((overtimeBonus[emp.id] || 0) * (rate / 8) * 1.5).toFixed(2)
      );
      const lopDeduction = Number((lopDaysThisMonth * rate).toFixed(2));
      const pfDeduction = Number(
        (basicPay * ((emp.pf_percent ?? 12) / 100)).toFixed(2)
      );
      const grossEarnings = basicPay + hra + da + calculatedOtBonus;
      const taxDeduction = Number(
        (grossEarnings * ((emp.tax_percent ?? 10) / 100)).toFixed(2)
      );

      return {
        employee_id: emp.id,
        billing_month: selectedMonth,
        lop_days_counted: lopDaysThisMonth,
        calculated_salary: grossEarnings,
        basic_pay: basicPay,
        hra,
        da,
        other_allowances: 0,
        overtime_bonus: calculatedOtBonus,
        tax_deduction: taxDeduction,
        pf_deduction: pfDeduction,
        lop_deduction: lopDeduction,
        net_salary: Number(
          (grossEarnings - (lopDeduction + pfDeduction + taxDeduction)).toFixed(2)
        ),
        is_finalized: true,
      };
    });

    // Delete existing payroll for this month and insert fresh
    await supabase.from('payroll').delete().eq('billing_month', selectedMonth);
    if (newPayrolls.length > 0) {
      await supabase.from('payroll').insert(newPayrolls);
    }

    res.json({ message: 'Payroll generated successfully' });
  } catch (err) {
    console.error('Payroll generate error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
