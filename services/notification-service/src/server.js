// ===== NOTIFICATION SERVICE (Port 8005) =====
// notification-service/src/server.js
const express = require('express');
const cors = require('cors');
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

app.get('/health', (req, res) => res.json({ status: 'healthy', service: 'notification-service' }));

// Send email notification (mock implementation)
app.post('/api/notifications/email', async (req, res) => {
  const { recipient, subject, content } = req.body;

  try {
    // Simulate email sending (replace with SendGrid, AWS SES, etc.)
    logger.info('Email notification sent', { recipient, subject });
    
    // In production, you would call an actual email service here
    // await sendgrid.send({ to: recipient, subject, text: content });

    res.status(200).json({ 
      message: 'Email sent successfully',
      notification: { recipient, subject, sentAt: new Date() }
    });
  } catch (error) {
    logger.error('Error sending email', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Send SMS notification (mock implementation)
app.post('/api/notifications/sms', async (req, res) => {
  const { phone, message } = req.body;

  try {
    logger.info('SMS notification sent', { phone, message });
    
    // In production: await twilio.messages.create({ to: phone, body: message });

    res.status(200).json({ 
      message: 'SMS sent successfully',
      notification: { phone, sentAt: new Date() }
    });
  } catch (error) {
    logger.error('Error sending SMS', { error: error.message });
    res.status(500).json({ error: 'Internal server error' });
  }
});

const PORT = process.env.PORT || 8005;
app.listen(PORT, () => {
  logger.info(`Notification Service running on port ${PORT}`);
});