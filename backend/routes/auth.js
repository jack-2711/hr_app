const express = require('express');
const bcrypt = require('bcryptjs');
const router = express.Router();
const supabase = require('../db/supabase');

router.post('/login', async (req, res, next) => {
    try {
        const { email, password } = req.body;
        console.log('Login attempt for:', email);

        if (!email || !password) {
            return res.status(400).json({ error: 'Email and password are required' });
        }

        // Fetch user by email
        const { data: user, error } = await supabase
            .from('profiles')
            .select('*')
            .eq('email', email)
            .single();

        if (error || !user) {
            console.log('User not found or error:', error);
            return res.status(401).json({ error: 'Invalid email or password' });
        }

        console.log('User found:', user.email, 'Has password field:', !!user.password);

        if (!user.password) {
            console.log('Error: password field is missing/undefined for user');
            return res.status(500).json({ error: 'User record is corrupted (missing password). Please recreate the user.' });
        }

        // Compare hashed password
        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(401).json({ error: 'Invalid email or password' });
        }

        res.json({
            message: 'Login successful',
            user: {
                id: user.id,
                email: user.email,
                role: user.role,
                full_name: user.full_name
            }
        });
    } catch (err) {
        console.error('Login error:', err);
        next(err);
    }
});

module.exports = router;
