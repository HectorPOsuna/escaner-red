const express = require('express');
const router = express.Router();
const scanController = require('../controllers/scanController');

// POST /api/scan-results
router.post('/scan-results', scanController.processScanResults);

// POST /api/capturas (Alias solicitado)
router.post('/capturas', scanController.processScanResults);

// GET /api/protocolos
router.get('/protocolos', scanController.getProtocols);

module.exports = router;
