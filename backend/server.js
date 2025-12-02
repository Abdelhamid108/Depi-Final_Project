/**
 * @file server.js
 * @description Entry point for the Amazona Backend Application.
 * This file configures the Express server, connects to MongoDB, sets up middleware,
 * and defines the main API routes.
 * 
 * @module Server
 */

import express from 'express';
import path from 'path';
import mongoose from 'mongoose';
import bodyParser from 'body-parser';
import cors from 'cors';
import config from './config';
import userRoute from './routes/userRoute';
import productRoute from './routes/productRoute';
import orderRoute from './routes/orderRoute';
import uploadRoute from './routes/uploadRoute';
import client from 'prom-client'; // Prometheus client for metrics

// ----------------------------------------------------------------------------
// Database Connection
// ----------------------------------------------------------------------------
const mongodbUrl = config.MONGODB_URL;
console.log('→ Connecting to MongoDB at:', mongodbUrl);

mongoose
  .connect(mongodbUrl, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  })
  .then(() => console.log('✅ Connected to MongoDB'))
  .catch((error) => console.log('❌ MongoDB connection error:', error.message));

// ----------------------------------------------------------------------------
// App Configuration
// ----------------------------------------------------------------------------
const app = express();

/**
 * CORS Configuration
 * Allows requests from any origin during development.
 * In production, this should be restricted to specific domains.
 */
const corsOptions = {
  origin: function (origin, callback) {
    if (!origin) return callback(null, true);
    return callback(null, true); // Allow all origins for dev/testing
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  credentials: true,
};

app.use(cors(corsOptions));
app.use(bodyParser.json());

// ----------------------------------------------------------------------------
// Monitoring & Observability (Prometheus)
// ----------------------------------------------------------------------------
const register = new client.Registry();
client.collectDefaultMetrics({ register });

// Define custom metric for HTTP requests
const httpRequestsTotal = new client.Counter({
  name: 'backend_http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'path', 'status'],
});
register.registerMetric(httpRequestsTotal);

/**
 * Middleware: Request Metrics
 * Tracks every HTTP request and increments the Prometheus counter.
 */
app.use((req, res, next) => {
  res.on('finish', () => {
    httpRequestsTotal.inc({
      method: req.method,
      path: req.route ? req.route.path : req.path,
      status: res.statusCode,
    });
  });
  next();
});

/**
 * Route: /metrics
 * Exposes Prometheus metrics for scraping.
 */
app.get('/metrics', async (req, res) => {
  res.setHeader('Content-Type', register.contentType);
  res.send(await register.metrics());
});

// ----------------------------------------------------------------------------
// Logging Middleware
// ----------------------------------------------------------------------------
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url} - Host: ${req.get('host')}`);
  next();
});

// ----------------------------------------------------------------------------
// Health Checks & Diagnostics
// ----------------------------------------------------------------------------
/**
 * Route: /api/health
 * Returns the health status of the application.
 */
app.get('/api/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
  });
});

app.get('/api/test', (req, res) => {
  res.status(200).json({
    message: 'API is working!',
    host: req.get('host'),
    ip: req.ip,
    headers: {
      'user-agent': req.get('user-agent'),
      'x-forwarded-for': req.get('x-forwarded-for'),
      'x-real-ip': req.get('x-real-ip'),
    },
  });
});

// ----------------------------------------------------------------------------
// API Routes
// ----------------------------------------------------------------------------
app.use('/api/uploads', uploadRoute);
app.use('/api/users', userRoute);
app.use('/api/products', productRoute);
app.use('/api/orders', orderRoute);

// Expose PayPal Client ID to frontend
app.get('/api/config/paypal', (req, res) => res.send(config.PAYPAL_CLIENT_ID));

// Static file serving
app.use('/uploads', express.static('uploads'));
app.use(express.static(path.join(__dirname, '/../frontend/build')));

// ----------------------------------------------------------------------------
// Error Handling
// ----------------------------------------------------------------------------
app.use((error, req, res, next) => {
  console.error('Error occurred:', error);
  res.status(error.status || 500).json({
    message: error.message,
    error: process.env.NODE_ENV === 'production' ? {} : error,
  });
});

// ----------------------------------------------------------------------------
// Frontend Fallback (SPA Support)
// ----------------------------------------------------------------------------
// For any request not handled by the API, serve the React frontend.
app.get('*', (req, res) => {
  res.sendFile(path.join(`${__dirname}/../frontend/build/index.html`));
});

// ----------------------------------------------------------------------------
// Server Initialization
// ----------------------------------------------------------------------------
app.listen(config.PORT, () => {
  console.log(`🚀 Server started at http://localhost:${config.PORT}`);
});

export default app;

