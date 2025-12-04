// ===== ADMIN SERVICE (Port 8007) =====
// admin-service/src/server.js
const express = require('express');
const cors = require('cors');
const axios = require('axios');
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

const AUTH_SERVICE_URL = process.env.AUTH_SERVICE_URL || 'http://localhost:8001';
const USER_SERVICE_URL = process.env.USER_SERVICE_URL || 'http://localhost:8002';
const BILLING_SERVICE_URL = process.env.BILLING_SERVICE_URL || 'http://localhost:8003';
const ANALYTICS_SERVICE_URL = process.env.ANALYTICS_SERVICE_URL || 'http://localhost:8006';

// Admin authentication middleware
async function authenticateAdmin(req, res, next) {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Access token required' });

  try {
    const response = await axios.post(`${AUTH_SERVICE_URL}/api/auth/validate`, {}, {
      headers: { Authorization: `Bearer ${token}` }
    });
    
    if (response.data.valid && response.data.user.role === 'admin') {
      req.user = response.data.user;
      next();
    } else {
      res.status(403).json({ error: 'Admin access required' });
    }
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
  }
}

app.get('/health', (req, res) => res.json({ status: 'healthy', service: 'admin-service' }));

// Get system statistics (dashboard overview)
app.get('/api/admin/stats', authenticateAdmin, async (req, res) => {
  try {
    // Fetch analytics data
    const analyticsResponse = await axios.get(`${ANALYTICS_SERVICE_URL}/api/analytics/stats`);
    
    const stats = {
      timestamp: new Date(),
      analytics: analyticsResponse.data.statistics,
      summary: {
        totalEvents: analyticsResponse.data.statistics.reduce((sum, stat) => sum + parseInt(stat.total_events), 0),
        activeUsers: new Set(analyticsResponse.data.statistics.map(s => s.unique_users)).size
      }
    };

    logger.info('System statistics retrieved', { admin: req.user.email });
    res.json({ stats });
  } catch (error) {
    logger.error('Error retrieving system stats', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// List all users (with pagination)
app.get('/api/admin/users', authenticateAdmin, async (req, res) => {
  const { page = 1, limit = 50 } = req.query;

  try {
    // In a real implementation, you would query the user service or a shared database
    // For now, we'll return a mock response
    const users = {
      page: parseInt(page),
      limit: parseInt(limit),
      total: 150, // mock total
      users: [
        { id: 1, email: 'user1@example.com', role: 'user', status: 'active' },
        { id: 2, email: 'user2@example.com', role: 'user', status: 'active' }
      ]
    };

    logger.info('User list retrieved', { admin: req.user.email });
    res.json(users);
  } catch (error) {
    logger.error('Error retrieving users', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update user status (enable/disable)
app.put('/api/admin/users/:id/status', authenticateAdmin, async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;

  try {
    // In production, this would update the user in the auth service database
    logger.info('User status updated', { admin: req.user.email, userId: id, status });
    
    res.json({ 
      message: 'User status updated successfully',
      user: { id, status }
    });
  } catch (error) {
    logger.error('Error updating user status', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get revenue report
app.get('/api/admin/reports/revenue', authenticateAdmin, async (req, res) => {
  const { startDate, endDate } = req.query;

  try {
    // This would aggregate billing data across the date range
    const report = {
      startDate: startDate || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
      endDate: endDate || new Date(),
      totalRevenue: 125430.50, // mock data
      totalTransactions: 1234,
      avgTransactionValue: 101.64,
      byDay: [
        { date: '2024-01-01', revenue: 4200.00, transactions: 42 },
        { date: '2024-01-02', revenue: 3800.00, transactions: 38 }
      ]
    };

    logger.info('Revenue report generated', { admin: req.user.email });
    res.json({ report });
  } catch (error) {
    logger.error('Error generating revenue report', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get service health status
app.get('/api/admin/health/services', authenticateAdmin, async (req, res) => {
  const services = [
    { name: 'auth-service', url: AUTH_SERVICE_URL },
    { name: 'user-service', url: USER_SERVICE_URL },
    { name: 'billing-service', url: BILLING_SERVICE_URL },
    { name: 'analytics-service', url: ANALYTICS_SERVICE_URL }
  ];

  const healthChecks = await Promise.all(
    services.map(async (service) => {
      try {
        const response = await axios.get(`${service.url}/health`, { timeout: 3000 });
        return {
          name: service.name,
          status: 'healthy',
          responseTime: response.headers['x-response-time'] || 'N/A'
        };
      } catch (error) {
        return {
          name: service.name,
          status: 'unhealthy',
          error: error.message
        };
      }
    })
  );

  res.json({ services: healthChecks });
});

const PORT = process.env.PORT || 8007;
app.listen(PORT, () => {
  logger.info(`Admin Service running on port ${PORT}`);
});