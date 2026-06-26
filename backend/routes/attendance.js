const express = require('express');
const router = express.Router();
const supabase = require('../db/supabase');

router.get('/office-location', (req, res) => {
    // These values could ideally be fetched from a config table in Supabase
    res.json({
        latitude: 12.9038,
        longitude: 80.1472,
        maxDistanceMeters: 500
    });
});


router.post('/register', async (req, res, next) => {
    try {
        const { userId, liveEmbedding } = req.body;
        const { error } = await supabase
            .from('profiles')
            .update({ face_embedding: liveEmbedding })
            .eq('id', userId);

        if (error) throw error;
        res.json({ message: 'Face registered successfully' });
    } catch (err) {
        next(err);
    }
});

router.post('/verify', async (req, res, next) => {
    try {
        const { userId, liveEmbedding, action } = req.body;

        const { data: user, error: fetchError } = await supabase
            .from('profiles')
            .select('face_embedding')
            .eq('id', userId)
            .single();

        if (fetchError || !user || !user.face_embedding) {
            return res.status(404).json({ error: 'Face signature not found. Please register first.' });
        }

        const storedEmbedding = user.face_embedding;
        const distance = calculateDistance(liveEmbedding, storedEmbedding);
        const threshold = 1.4;

        if (distance > threshold) {
            return res.status(401).json({ error: 'Face does not match stored signature.' });
        }

        const now = new Date();
        const todayStr = now.toISOString().split('T')[0];

        // Fetch today's entry
        const { data: existing } = await supabase
            .from('attendance')
            .select('*')
            .eq('employee_id', userId)
            .gte('created_at', todayStr)
            .order('created_at', { ascending: false })
            .limit(1);

        let entry = existing && existing.length > 0 ? existing[0] : null;

        if (action === 'Clock In') {
            if (entry && !entry.clock_out) {
                return res.status(400).json({ error: 'Already clocked in for today.' });
            }
            const { error: insErr } = await supabase
                .from('attendance')
                .insert({
                    employee_id: userId,
                    clock_in: now.toISOString(),
                    action: 'Clock In'
                });
            if (insErr) throw insErr;
        } else if (action === 'Clock Out') {
            if (!entry || entry.clock_out) {
                return res.status(400).json({ error: 'No active clock-in found for today.' });
            }
            const clockIn = new Date(entry.clock_in);
            const workingHours = (now - clockIn) / (1000 * 60 * 60);

            const { error: updErr } = await supabase
                .from('attendance')
                .update({
                    clock_out: now.toISOString(),
                    working_hours: workingHours,
                    action: 'Clock Out'
                })
                .eq('id', entry.id);
            if (updErr) throw updErr;
        } else if (action === 'Break In') {
            if (!entry || entry.clock_out || (entry.break_start_time && !entry.break_end_time)) {
                return res.status(400).json({ error: 'Cannot start break.' });
            }
            const { error: updErr } = await supabase
                .from('attendance')
                .update({
                    break_start_time: now.toISOString(),
                    action: 'Break In'
                })
                .eq('id', entry.id);
            if (updErr) throw updErr;
        } else if (action === 'Break Out') {
            if (!entry || !entry.break_start_time || entry.break_end_time) {
                return res.status(400).json({ error: 'No active break found.' });
            }
            const breakStart = new Date(entry.break_start_time);
            const breakDuration = (now - breakStart) / (1000 * 60 * 60);
            const totalBreak = (entry.total_break_duration || 0) + breakDuration;

            const { error: updErr } = await supabase
                .from('attendance')
                .update({
                    break_end_time: now.toISOString(),
                    total_break_duration: totalBreak,
                    action: 'Break Out'
                })
                .eq('id', entry.id);
            if (updErr) throw updErr;
        }

        res.json({ message: `${action} recorded successfully` });
    } catch (err) {
        next(err);
    }
});

function calculateDistance(vec1, vec2) {
    if (vec1.length !== vec2.length) return Infinity;
    let sum = 0;
    for (let i = 0; i < vec1.length; i++) {
        const diff = vec1[i] - vec2[i];
        sum += diff * diff;
    }
    return Math.sqrt(sum);
}

module.exports = router;
