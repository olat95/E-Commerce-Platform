// ===== ANALYTICS SERVICE (Port 8006) =====
// analytics-service/src/server.js
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const winston = require('winston');

const app = express();

// Enable CORS for all routes
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
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/analytics_db'
});

app.get('/health', (req, res) => res.json({ status: 'healthy', service: 'analytics-service' }));

// Track event
app.post('/api/analytics/events', async (req, res) => {
  const { eventType, userId, metadata } = req.body;

  try {
    const result = await pool.query(
      `INSERT INTO events (event_type, user_id, metadata, timestamp) 
       VALUES ($1, $2, $3, NOW()) RETURNING *`,
      [eventType, userId, JSON.stringify(metadata)]
    );

    logger.info('Event tracked', { eventType, userId });
    res.status(201).json({ event: result.rows[0] });
  } catch (error) {
    logger.error('Error tracking event', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get daily report
app.get('/api/analytics/reports/daily', async (req, res) => {
  const { date } = req.query;

  try {
    const targetDate = date || new Date().toISOString().split('T')[0];
    
    const result = await pool.query(
      `SELECT 
        event_type,
        COUNT(*) as count,
        DATE(timestamp) as date
       FROM events 
       WHERE DATE(timestamp) = $1
       GROUP BY event_type, DATE(timestamp)
       ORDER BY count DESC`,
      [targetDate]
    );

    res.json({ report: result.rows, date: targetDate });
  } catch (error) {
    logger.error('Error generating daily report', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get user activity
app.get('/api/analytics/reports/user/:userId', async (req, res) => {
  const { userId } = req.params;
  const { limit = 50 } = req.query;

  try {
    const result = await pool.query(
      `SELECT event_type, metadata, timestamp 
       FROM events 
       WHERE user_id = $1 
       ORDER BY timestamp DESC 
       LIMIT $2`,
      [userId, limit]
    );

    res.json({ activity: result.rows });
  } catch (error) {
    logger.error('Error retrieving user activity', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get event statistics
app.get('/api/analytics/stats', async (req, res) => {
  const { startDate, endDate } = req.query;

  try {
    const query = `
      SELECT 
        event_type,
        COUNT(*) as total_events,
        COUNT(DISTINCT user_id) as unique_users,
        DATE_TRUNC('day', timestamp) as date
      FROM events 
      WHERE timestamp >= $1 AND timestamp <= $2
      GROUP BY event_type, DATE_TRUNC('day', timestamp)
      ORDER BY date DESC, total_events DESC
    `;

    const result = await pool.query(query, [
      startDate || new Date(Date.now() - 7 * 24 * 60 * 60 * 1000), // 7 days ago
      endDate || new Date()
    ]);

    res.json({ statistics: result.rows });
  } catch (error) {
    logger.error('Error retrieving statistics', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

async function initializeDatabase() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS events (
      id SERIAL PRIMARY KEY,
      event_type VARCHAR(100) NOT NULL,
      user_id INTEGER,
      metadata JSONB,
      timestamp TIMESTAMP DEFAULT NOW()
    );
  `);

  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp);
    CREATE INDEX IF NOT EXISTS idx_events_user_id ON events(user_id);
    CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type);
  `);

  logger.info('Analytics database initialized');
}

const PORT = process.env.PORT || 8006;
app.listen(PORT, async () => {
  await initializeDatabase();
  logger.info(`Analytics Service running on port ${PORT}`);
});