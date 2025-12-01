const express = require('express');
const router = express.Router();
const scanController = require('../controllers/scanController');

// POST /api/scan-results
router.post('/scan-results', scanController.processScanResults);

module.exports = router;
