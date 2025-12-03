const express = require('express');
const router = express.Router();
const scanController = require('../controllers/scanController');

// POST /api/scan-results
router.post('/scan-results', scanController.processScanResults);

// POST /api/capturas (Alias solicitado)
router.post('/capturas', scanController.processScanResults);

// GET /api/protocolos
router.get('/protocolos', scanController.getProtocols);

// GET /api/equipos
router.get('/equipos', scanController.getEquipos);

// GET /api/protocolos/seguros
router.get('/protocolos/seguros', scanController.getProtocolosSeguros);

// GET /api/protocolos/inseguros
router.get('/protocolos/inseguros', scanController.getProtocolosInseguros);

module.exports = router;
