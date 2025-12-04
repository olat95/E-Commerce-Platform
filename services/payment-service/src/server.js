// ===== PAYMENT SERVICE - FIXED VERSION (Port 8004) =====
// payment-service/src/server.js
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
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/payment_db'
});

const AUTH_SERVICE_URL = process.env.AUTH_SERVICE_URL || 'http://localhost:8001';
const BILLING_SERVICE_URL = process.env.BILLING_SERVICE_URL || 'http://localhost:8003';
const ANALYTICS_SERVICE_URL = process.env.ANALYTICS_SERVICE_URL || 'http://localhost:8006';

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
    logger.error('Token validation failed', { error: error.message });
    res.status(401).json({ error: 'Invalid token' });
  }
}

app.get('/health', (req, res) => res.json({ status: 'healthy', service: 'payment-service' }));

app.get('/ready', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({ status: 'ready', database: 'connected' });
  } catch (error) {
    logger.error('Database connection failed', { error: error.message });
    res.status(503).json({ status: 'not ready', database: 'disconnected' });
  }
});

// Process payment - FIXED VERSION
app.post('/api/payments/process', authenticateToken, async (req, res) => {
  const { invoiceId, method, cardDetails } = req.body;

  try {
    // Get invoice details from billing service
    let invoice;
    try {
      const invoiceResponse = await axios.get(
        `${BILLING_SERVICE_URL}/api/billing/invoices/${invoiceId}`,
        { 
          headers: { 
            Authorization: req.headers.authorization,
            'Content-Type': 'application/json'
          } 
        }
      );
      invoice = invoiceResponse.data.invoice;
    } catch (error) {
      logger.error('Failed to fetch invoice', { 
        error: error.message,
        status: error.response?.status,
        data: error.response?.data 
      });
      
      // If we get 403, it means user doesn't own this invoice
      if (error.response?.status === 403) {
        return res.status(403).json({ 
          error: 'You are not authorized to pay this invoice',
          details: 'This invoice belongs to another user'
        });
      }
      
      // If we get 404, invoice doesn't exist
      if (error.response?.status === 404) {
        return res.status(404).json({ error: 'Invoice not found' });
      }
      
      // Other errors from billing service
      return res.status(500).json({ 
        error: 'Failed to retrieve invoice details',
        details: error.response?.data?.error || error.message
      });
    }

    // Verify invoice is not already paid
    if (invoice.status === 'paid') {
      return res.status(400).json({ 
        error: 'Invoice already paid',
        invoice: invoice
      });
    }

    // Simulate payment processing (replace with real payment gateway)
    const transactionId = `txn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const isSuccessful = Math.random() > 0.1; // 90% success rate for simulation

    const status = isSuccessful ? 'completed' : 'failed';

    // Store payment record
    const result = await pool.query(
      `INSERT INTO payments (invoice_id, amount, method, status, transaction_id, created_at) 
       VALUES ($1, $2, $3, $4, $5, NOW()) RETURNING *`,
      [invoiceId, invoice.amount, method, status, transactionId]
    );

    const payment = result.rows[0];

    // Update invoice status if payment successful
    if (isSuccessful) {
      try {
        await axios.put(
          `${BILLING_SERVICE_URL}/api/billing/invoices/${invoiceId}`,
          { status: 'paid' },
          { headers: { Authorization: req.headers.authorization } }
        );
      } catch (error) {
        logger.error('Failed to update invoice status', { error: error.message });
        // Payment was successful but invoice update failed - log this for manual review
        logger.error('CRITICAL: Payment succeeded but invoice update failed', {
          paymentId: payment.id,
          invoiceId,
          transactionId
        });
      }

      // Track analytics event
      try {
        await axios.post(`${ANALYTICS_SERVICE_URL}/api/analytics/events`, {
          eventType: 'payment_completed',
          userId: req.user.userId,
          metadata: { invoiceId, amount: invoice.amount, method, transactionId }
        });
      } catch (error) {
        logger.error('Failed to track analytics', { error: error.message });
        // Non-critical, continue
      }
    }

    logger.info('Payment processed', { 
      paymentId: payment.id, 
      status,
      invoiceId,
      amount: invoice.amount
    });

    res.status(isSuccessful ? 200 : 400).json({ 
      payment,
      message: isSuccessful 
        ? 'Payment processed successfully' 
        : 'Payment failed. Please try again or use a different payment method.'
    });

  } catch (error) {
    logger.error('Error processing payment', { 
      error: error.message,
      stack: error.stack 
    });
    res.status(500).json({ 
      error: 'Internal server error',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// Get payment details
app.get('/api/payments/:id', authenticateToken, async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query('SELECT * FROM payments WHERE id = $1', [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Payment not found' });
    }

    res.json({ payment: result.rows[0] });
  } catch (error) {
    logger.error('Error retrieving payment', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get payments by invoice
app.get('/api/payments/invoice/:invoiceId', authenticateToken, async (req, res) => {
  const { invoiceId } = req.params;

  try {
    const result = await pool.query(
      'SELECT * FROM payments WHERE invoice_id = $1 ORDER BY created_at DESC',
      [invoiceId]
    );

    res.json({ payments: result.rows });
  } catch (error) {
    logger.error('Error retrieving payments', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

async function initializeDatabase() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS payments (
        id SERIAL PRIMARY KEY,
        invoice_id INTEGER NOT NULL,
        amount DECIMAL(10, 2) NOT NULL,
        method VARCHAR(50) NOT NULL,
        status VARCHAR(50) DEFAULT 'pending',
        transaction_id VARCHAR(255) UNIQUE,
        created_at TIMESTAMP DEFAULT NOW()
      );
    `);

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_payments_invoice_id ON payments(invoice_id);
      CREATE INDEX IF NOT EXISTS idx_payments_transaction_id ON payments(transaction_id);
    `);

    logger.info('Payment database initialized');
  } catch (error) {
    logger.error('Database initialization error', { error: error.message });
  }
}

const PORT = process.env.PORT || 8004;
app.listen(PORT, async () => {
  await initializeDatabase();
  logger.info(`Payment Service running on port ${PORT}`);
});