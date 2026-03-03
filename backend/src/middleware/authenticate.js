const jwt = require('jsonwebtoken');
const config = require('../config');

function authenticate(req, res, next) {
    const token = req.cookies?.rdweb_token;
    if (!token) {
        return res.status(401).json({ error: 'No autenticado', code: 'NO_TOKEN' });
    }
    try {
        const payload = jwt.verify(token, config.jwt.secret);
        req.user = payload;
        next();
    } catch (err) {
        if (err.name === 'TokenExpiredError') {
            return res.status(401).json({ error: 'Sesión expirada', code: 'TOKEN_EXPIRED' });
        }
        return res.status(401).json({ error: 'Token inválido', code: 'INVALID_TOKEN' });
    }
}

module.exports = { authenticate };
