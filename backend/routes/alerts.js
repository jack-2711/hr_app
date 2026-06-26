const express = require('express');
const router = express.Router();
const supabase = require('../db/supabase');

// GET /api/alerts - Fetch all alerts
router.get('/', async (req, res, next) => {
    try {
        const { data, error } = await supabase
            .from('alerts')
            .select('*')
            .order('created_at', { ascending: false });
        if (error) throw error;
        res.json(data);
    } catch (err) {
        next(err);
    }
});

// POST /api/alerts - Create new alert (Admin/HR only)
router.post('/', async (req, res, next) => {
    try {
        const { title, message, type } = req.body;
        const { data, error } = await supabase
            .from('alerts')
            .insert([{ title, message, type }])
            .select();
        if (error) throw error;
        res.json(data[0]);
    } catch (err) {
        next(err);
    }
});

module.exports = router;
