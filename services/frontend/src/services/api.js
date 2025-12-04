// ===== API SERVICE =====
// services/frontend/src/services/api.js
import axios from 'axios';

const API_URL = process.env.REACT_APP_API_GATEWAY || 'http://localhost:8001';

const api = axios.create({
  baseURL: API_URL
});

// Add token to requests
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Handle errors
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export const userAPI = {
  getProfile: (userId) => api.get(`/api/users/${userId}`),
  updateProfile: (userId, data) => api.put(`/api/users/${userId}`, data),
  getUserOrders: (userId) => api.get(`/api/users/${userId}/orders`)
};

export const billingAPI = {
  createInvoice: (data) => api.post('/api/billing/invoices', data),
  getInvoice: (id) => api.get(`/api/billing/invoices/${id}`),
  getUserInvoices: (userId) => api.get(`/api/billing/invoices/user/${userId}`)
};

export const paymentAPI = {
  processPayment: (data) => api.post('/api/payments/process', data),
  getPayment: (id) => api.get(`/api/payments/${id}`)
};

export const analyticsAPI = {
  trackEvent: (data) => api.post('/api/analytics/events', data),
  getDailyReport: (date) => api.get('/api/analytics/reports/daily', { params: { date } }),
  getUserActivity: (userId) => api.get(`/api/analytics/reports/user/${userId}`)
};

export const adminAPI = {
  getStats: () => api.get('/api/admin/stats'),
  getUsers: (page = 1, limit = 50) => api.get('/api/admin/users', { params: { page, limit } }),
  updateUserStatus: (userId, status) => api.put(`/api/admin/users/${userId}/status`, { status }),
  getRevenueReport: (startDate, endDate) => api.get('/api/admin/reports/revenue', { 
    params: { startDate, endDate } 
  })
};

export default api;