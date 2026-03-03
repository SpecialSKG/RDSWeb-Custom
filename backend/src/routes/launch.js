const express = require('express');
const { authenticate } = require('../middleware/authenticate');
const { getAppsForUser } = require('../services/rdcbService');
const { generateRemoteAppRdp, generateDesktopRdp } = require('../services/rdpService');

const router = express.Router();

// GET /api/launch/:alias  — genera y descarga el archivo .rdp de una app
router.get('/:alias', authenticate, async (req, res) => {
    const { alias } = req.params;
    const isPrivate = req.user.privateMode !== false;

    try {
        const { apps, desktops } = await getAppsForUser(req.user);
        const allResources = [...apps, ...desktops];
        const resource = allResources.find(
            (a) => a.alias?.toLowerCase() === alias.toLowerCase()
        );

        if (!resource) {
            return res.status(404).json({ error: 'Aplicación no encontrada', code: 'APP_NOT_FOUND' });
        }

        let rdpContent;
        if (resource.rdpPath === null) {
            // Es un escritorio remoto
            rdpContent = generateDesktopRdp(resource, req.user);
        } else {
            // Es una RemoteApp
            rdpContent = generateRemoteAppRdp(resource, req.user, isPrivate);
        }

        const fileName = `${resource.alias || 'launch'}.rdp`;
        res.setHeader('Content-Type', 'application/x-rdp');
        res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
        res.setHeader('Cache-Control', 'no-store');
        return res.send(rdpContent);
    } catch (err) {
        console.error('[launch/:alias]', err.message);
        return res.status(500).json({ error: 'Error generando el archivo RDP', code: 'RDP_ERROR' });
    }
});

module.exports = router;
