// user-service/src/server.js
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const axios = require('axios');
const winston = require('winston');

const app = express();
// Enable CORS for all routes
app.use(cors({
  origin: ['http://localhost:3000', 'http://localhost:8080'],
  credentials: true
}));
app.use(express.json());

// Logger setup
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.json(),
  transports: [new winston.transports.Console()]
});

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/user_db'
});

// Service URLs
const AUTH_SERVICE_URL = process.env.AUTH_SERVICE_URL || 'http://localhost:8001';
const BILLING_SERVICE_URL = process.env.BILLING_SERVICE_URL || 'http://localhost:8003';

// Middleware to verify JWT token
async function authenticateToken(req, res, next) {
  const token = req.headers.authorization?.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  try {
    // Validate token with auth service
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

// Health check endpoints
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', service: 'user-service' });
});

app.get('/ready', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({ status: 'ready', database: 'connected' });
  } catch (error) {
    logger.error('Database connection failed', { error: error.message });
    res.status(503).json({ status: 'not ready', database: 'disconnected' });
  }
});

// Get user profile
app.get('/api/users/:id', authenticateToken, async (req, res) => {
  const { id } = req.params;

  // Check if user is accessing their own profile or is admin
  if (req.user.userId !== parseInt(id) && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Forbidden' });
  }

  try {
    const result = await pool.query(
      'SELECT user_id, first_name, last_name, phone, address, avatar_url, created_at FROM profiles WHERE user_id = $1',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User profile not found' });
    }

    logger.info('User profile retrieved', { userId: id });
    res.status(200).json({ profile: result.rows[0] });
  } catch (error) {
    logger.error('Error retrieving user profile', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create user profile (called after registration)
app.post('/api/users', authenticateToken, async (req, res) => {
  const { userId, firstName, lastName, phone, address } = req.body;

  try {
    const result = await pool.query(
      `INSERT INTO profiles (user_id, first_name, last_name, phone, address, created_at) 
       VALUES ($1, $2, $3, $4, $5, NOW()) 
       RETURNING *`,
      [userId, firstName, lastName, phone, JSON.stringify(address)]
    );

    logger.info('User profile created', { userId });
    res.status(201).json({ profile: result.rows[0] });
  } catch (error) {
    logger.error('Error creating user profile', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update user profile
app.put('/api/users/:id', authenticateToken, async (req, res) => {
  const { id } = req.params;
  const { firstName, lastName, phone, address, avatarUrl } = req.body;

  // Check authorization
  if (req.user.userId !== parseInt(id) && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Forbidden' });
  }

  try {
    const result = await pool.query(
      `UPDATE profiles 
       SET first_name = COALESCE($1, first_name),
           last_name = COALESCE($2, last_name),
           phone = COALESCE($3, phone),
           address = COALESCE($4, address),
           avatar_url = COALESCE($5, avatar_url),
           updated_at = NOW()
       WHERE user_id = $6
       RETURNING *`,
      [firstName, lastName, phone, address ? JSON.stringify(address) : null, avatarUrl, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User profile not found' });
    }

    logger.info('User profile updated', { userId: id });
    res.status(200).json({ profile: result.rows[0] });
  } catch (error) {
    logger.error('Error updating user profile', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete user profile
app.delete('/api/users/:id', authenticateToken, async (req, res) => {
  const { id } = req.params;

  // Only user themselves or admin can delete
  if (req.user.userId !== parseInt(id) && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Forbidden' });
  }

  try {
    const result = await pool.query('DELETE FROM profiles WHERE user_id = $1 RETURNING user_id', [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User profile not found' });
    }

    logger.info('User profile deleted', { userId: id });
    res.status(200).json({ message: 'User profile deleted successfully' });
  } catch (error) {
    logger.error('Error deleting user profile', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get user orders (calls billing service)
app.get('/api/users/:id/orders', authenticateToken, async (req, res) => {
  const { id } = req.params;

  // Check authorization
  if (req.user.userId !== parseInt(id) && req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Forbidden' });
  }

  try {
    // Call billing service to get user invoices
    const response = await axios.get(
      `${BILLING_SERVICE_URL}/api/billing/invoices/user/${id}`,
      { headers: { Authorization: req.headers.authorization } }
    );

    logger.info('User orders retrieved', { userId: id });
    res.status(200).json({ orders: response.data.invoices });
  } catch (error) {
    logger.error('Error retrieving user orders', { error: error.message });
    
    if (error.response) {
      res.status(error.response.status).json({ error: error.response.data.error });
    } else {
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

// Initialize database tables
async function initializeDatabase() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS profiles (
        id SERIAL PRIMARY KEY,
        user_id INTEGER UNIQUE NOT NULL,
        first_name VARCHAR(100),
        last_name VARCHAR(100),
        phone VARCHAR(20),
        address JSONB,
        avatar_url TEXT,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );
    `);

    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
    `);

    logger.info('Database tables initialized successfully');
  } catch (error) {
    logger.error('Database initialization error', { error: error.message });
  }
}

// Start server
const PORT = process.env.PORT || 8002;
app.listen(PORT, async () => {
  await initializeDatabase();
  logger.info(`User Service running on port ${PORT}`);
});