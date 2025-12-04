// ===== NAVIGATION COMPONENT =====
// services/frontend/src/components/Navigation.js
import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

const Navigation = () => {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  if (!user) {
    return null;
  }

  return (
    <nav className="bg-blue-600 text-white shadow-lg">
      <div className="container mx-auto px-4">
        <div className="flex justify-between items-center py-4">
          <div className="flex items-center space-x-8">
            <Link to="/dashboard" className="text-xl font-bold">
              Microservices Platform
            </Link>
            <div className="flex space-x-4">
              <Link to="/dashboard" className="hover:text-blue-200">Dashboard</Link>
              <Link to="/profile" className="hover:text-blue-200">Profile</Link>
              <Link to="/billing" className="hover:text-blue-200">Billing</Link>
              {user.role === 'admin' && (
                <Link to="/admin" className="hover:text-blue-200">Admin</Link>
              )}
            </div>
          </div>
          <div className="flex items-center space-x-4">
            <span className="text-sm">{user.email}</span>
            <button
              onClick={handleLogout}
              className="bg-blue-700 hover:bg-blue-800 px-4 py-2 rounded"
            >
              Logout
            </button>
          </div>
        </div>
      </div>
    </nav>
  );
};

export default Navigation;