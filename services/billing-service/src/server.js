// ===== BILLING SERVICE (Port 8003) =====
// billing-service/src/server.js
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const axios = require('axios');
const winston = require('winston');

const app = express();

// Enable CORS
app.use(cors({
  origin: ['http://localhost:3000', 'http://localhost:8080'],
  credentials: true
}));

app.use(express.json());

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [new winston.transports.Console()]
});

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/billing_db'
});

const AUTH_SERVICE_URL = process.env.AUTH_SERVICE_URL || 'http://localhost:8001';
const PAYMENT_SERVICE_URL = process.env.PAYMENT_SERVICE_URL || 'http://localhost:8004';
const NOTIFICATION_SERVICE_URL = process.env.NOTIFICATION_SERVICE_URL || 'http://localhost:8005';

// Auth middleware
async function authenticateToken(req, res, next) {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Access token required' });

  try {
    const response = await axios.post(`${AUTH_SERVICE_URL}/api/auth/validate`, {}, {
      headers: { Authorization: `Bearer ${token}` }
    });
    if (response.data.valid) {
      req.user = response.data.user;
      next();
    } else {
      res.status(401).json({ error: 'Invalid token' });
    }
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
  }
}

app.get('/health', (req, res) => res.json({ status: 'healthy', service: 'billing-service' }));

// Create invoice
app.post('/api/billing/invoices', authenticateToken, async (req, res) => {
  const { userId, amount, items, description } = req.body;

  try {
    const result = await pool.query(
      `INSERT INTO invoices (user_id, amount, items, description, status, created_at) 
       VALUES ($1, $2, $3, $4, 'pending', NOW()) RETURNING *`,
      [userId, amount, JSON.stringify(items), description]
    );

    logger.info('Invoice created', { invoiceId: result.rows[0].id });
    res.status(201).json({ invoice: result.rows[0] });
  } catch (error) {
    logger.error('Error creating invoice', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get invoice by ID
app.get('/api/billing/invoices/:id', authenticateToken, async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query('SELECT * FROM invoices WHERE id = $1', [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Invoice not found' });
    }

    const invoice = result.rows[0];
    if (invoice.user_id !== req.user.userId && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Forbidden' });
    }

    res.json({ invoice });
  } catch (error) {
    logger.error('Error retrieving invoice', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get user invoices
app.get('/api/billing/invoices/user/:userId', authenticateToken, async (req, res) => {
  const { userId } = req.params;

  if (req.user.userId !== parseInt(userId) && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Forbidden' });
  }

  try {
    const result = await pool.query(
      'SELECT * FROM invoices WHERE user_id = $1 ORDER BY created_at DESC',
      [userId]
    );

    res.json({ invoices: result.rows });
  } catch (error) {
    logger.error('Error retrieving user invoices', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update invoice status
app.put('/api/billing/invoices/:id', authenticateToken, async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;

  try {
    const result = await pool.query(
      'UPDATE invoices SET status = $1, updated_at = NOW() WHERE id = $2 RETURNING *',
      [status, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Invoice not found' });
    }

    logger.info('Invoice status updated', { invoiceId: id, status });

    // Send notification if status is 'paid'
    if (status === 'paid') {
      try {
        await axios.post(`${NOTIFICATION_SERVICE_URL}/api/notifications/email`, {
          recipient: req.user.email,
          subject: 'Payment Received',
          content: `Your invoice #${id} has been paid successfully.`
        });
      } catch (error) {
        logger.error('Failed to send notification', { error: error.message });
      }
    }

    res.json({ invoice: result.rows[0] });
  } catch (error) {
    logger.error('Error updating invoice', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

async function initializeDatabase() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS invoices (
      id SERIAL PRIMARY KEY,
      user_id INTEGER NOT NULL,
      amount DECIMAL(10, 2) NOT NULL,
      items JSONB,
      description TEXT,
      status VARCHAR(50) DEFAULT 'pending',
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW()
    );
  `);
  logger.info('Billing database initialized');
}

const PORT = process.env.PORT || 8003;
app.listen(PORT, async () => {
  await initializeDatabase();
  logger.info(`Billing Service running on port ${PORT}`);
});