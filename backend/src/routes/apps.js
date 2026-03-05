const express = require('express');
const { authenticate } = require('../middleware/authenticate');
const { getAppsForUser } = require('../services/rdcbService');

const router = express.Router();

// GET /api/apps  — lista de RemoteApps del usuario autenticado
router.get('/', authenticate, async (req, res) => {
    try {
        console.log(`[apps] GET /api/apps → usuario: ${req.user?.username}`);
        const { apps, desktops } = await getAppsForUser(req.user);
        console.log(`[apps] Respuesta → ${apps.length} apps, ${desktops.length} escritorios`);
        return res.json({ ok: true, apps, desktops });
    } catch (err) {
        console.error('[apps/get]', err.message);
        return res.status(503).json({ error: 'No se pudo obtener el catálogo de aplicaciones', code: 'RDCB_ERROR' });
    }
});

module.exports = router;
