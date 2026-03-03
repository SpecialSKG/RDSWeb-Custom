const express = require('express');
const jwt = require('jsonwebtoken');
const { authenticateUser } = require('../services/adService');
const { authenticate } = require('../middleware/authenticate');
const config = require('../config');

const router = express.Router();

function getInitials(name = '') {
    return name.split(' ').slice(0, 2).map((n) => n[0]?.toUpperCase() || '').join('');
}

// POST /api/auth/login
router.post('/login', async (req, res) => {
    const { username, password, privateMode } = req.body;
    if (!username || !password) {
        return res.status(400).json({ error: 'Usuario y contraseña son requeridos', code: 'MISSING_FIELDS' });
    }
    try {
        const user = await authenticateUser(username.trim(), password);
        const payload = {
            username: user.username,
            displayName: user.displayName,
            email: user.email,
            domain: user.domain,
            groups: user.groups,
            privateMode: privateMode === true,
        };
        const token = jwt.sign(payload, config.jwt.secret, { expiresIn: config.jwt.expiresIn });
        const timeoutMinutes = privateMode ? 240 : 20;
        res.cookie('rdweb_token', token, {
            httpOnly: true,
            secure: config.nodeEnv === 'production',
            sameSite: 'lax',
            maxAge: timeoutMinutes * 60 * 1000,
            path: '/',
        });
        return res.json({
            ok: true,
            user: {
                username: user.username,
                displayName: user.displayName,
                email: user.email,
                domain: user.domain,
                initials: getInitials(user.displayName),
            },
        });
    } catch (err) {
        console.error('[auth/login]', err.message);
        if (err.code === 'INVALID_CREDENTIALS') {
            return res.status(401).json({ error: 'Credenciales incorrectas. Verifica tu usuario y contraseña.', code: 'INVALID_CREDENTIALS' });
        }
        return res.status(500).json({ error: 'Error interno del servidor', code: 'INTERNAL_ERROR' });
    }
});

// POST /api/auth/logout
router.post('/logout', (req, res) => {
    res.clearCookie('rdweb_token', { path: '/' });
    return res.json({ ok: true });
});

// GET /api/auth/me
router.get('/me', authenticate, (req, res) => {
    const u = req.user;
    return res.json({
        username: u.username,
        displayName: u.displayName,
        email: u.email,
        domain: u.domain,
        initials: getInitials(u.displayName),
        privateMode: u.privateMode,
    });
});

module.exports = router;
