// ===== BILLING PAGE =====
// services/frontend/src/pages/Billing.js
import React, { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { billingAPI, paymentAPI } from '../services/api';

const Billing = () => {
  const { user } = useAuth();
  const [invoices, setInvoices] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showCreateInvoice, setShowCreateInvoice] = useState(false);
  const [showPaymentModal, setShowPaymentModal] = useState(false);
  const [selectedInvoice, setSelectedInvoice] = useState(null);
  const [message, setMessage] = useState('');

  const [invoiceForm, setInvoiceForm] = useState({
    amount: '',
    description: '',
    itemName: '',
    itemQuantity: 1,
    itemPrice: ''
  });

  const [paymentForm, setPaymentForm] = useState({
    method: 'credit_card',
    cardNumber: '',
    cvv: '',
    expiry: ''
  });

  useEffect(() => {
    fetchInvoices();
  }, [user]);

  const fetchInvoices = async () => {
    try {
      const response = await billingAPI.getUserInvoices(user.userId);
      setInvoices(response.data.invoices || []);
    } catch (error) {
      console.error('Error fetching invoices:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleCreateInvoice = async (e) => {
    e.preventDefault();
    setMessage('');

    try {
      await billingAPI.createInvoice({
        userId: user.userId,
        amount: parseFloat(invoiceForm.amount),
        items: [{
          name: invoiceForm.itemName,
          quantity: parseInt(invoiceForm.itemQuantity),
          price: parseFloat(invoiceForm.itemPrice)
        }],
        description: invoiceForm.description
      });

      setMessage('Invoice created successfully!');
      setShowCreateInvoice(false);
      setInvoiceForm({
        amount: '',
        description: '',
        itemName: '',
        itemQuantity: 1,
        itemPrice: ''
      });
      fetchInvoices();
    } catch (error) {
      setMessage('Error creating invoice');
    }
  };

  const handlePayInvoice = async (e) => {
    e.preventDefault();
    setMessage('');

    try {
      const response = await paymentAPI.processPayment({
        invoiceId: selectedInvoice.id,
        method: paymentForm.method,
        cardDetails: {
          number: paymentForm.cardNumber,
          cvv: paymentForm.cvv,
          expiry: paymentForm.expiry
        }
      });

      if (response.data.payment.status === 'completed') {
        setMessage('Payment processed successfully!');
        fetchInvoices();
      } else {
        setMessage('Payment failed. Please try again.');
      }

      setShowPaymentModal(false);
      setPaymentForm({
        method: 'credit_card',
        cardNumber: '',
        cvv: '',
        expiry: ''
      });
    } catch (error) {
      setMessage('Error processing payment');
    }
  };

  if (loading) {
    return <div className="flex justify-center items-center min-h-screen">Loading...</div>;
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold text-gray-800">Billing</h1>
        <button
          onClick={() => setShowCreateInvoice(true)}
          className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded"
        >
          Create Invoice
        </button>
      </div>

      {message && (
        <div className={`mb-4 p-4 rounded ${
          message.includes('success') ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'
        }`}>
          {message}
        </div>
      )}

      {/* Create Invoice Modal */}
      {showCreateInvoice && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-8 max-w-md w-full">
            <h2 className="text-2xl font-bold mb-4">Create New Invoice</h2>
            <form onSubmit={handleCreateInvoice} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">Item Name</label>
                <input
                  type="text"
                  required
                  className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"
                  value={invoiceForm.itemName}
                  onChange={(e) => setInvoiceForm({...invoiceForm, itemName: e.target.value})}
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700">Quantity</label>
                  <input
                    type="number"
                    required
                    min="1"
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"
                    value={invoiceForm.itemQuantity}
                    onChange={(e) => setInvoiceForm({...invoiceForm, itemQuantity: e.target.value})}
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700">Price</label>
                  <input
                    type="number"
                    required
                    step="0.01"
                    min="0"
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"
                    value={invoiceForm.itemPrice}
                    onChange={(e) => setInvoiceForm({...invoiceForm, itemPrice: e.target.value})}
                  />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Total Amount</label>
                <input
                  type="number"
                  required
                  step="0.01"
                  min="0"
                  className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"
                  value={invoiceForm.amount}
                  onChange={(e) => setInvoiceForm({...invoiceForm, amount: e.target.value})}
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Description</label>
                <textarea
                  className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"
                  rows="3"
                  value={invoiceForm.description}
                  onChange={(e) => setInvoiceForm({...invoiceForm, description: e.target.value})}
                />
              </div>
              <div className="flex space-x-2">
                <button
                  type="submit"
                  className="flex-1 bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded"
                >
                  Create
                </button>
                <button
                  type="button"
                  onClick={() => setShowCreateInvoice(false)}
                  className="flex-1 bg-gray-300 hover:bg-gray-400 text-gray-800 px-4 py-2 rounded"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Payment Modal */}
      {showPaymentModal && selectedInvoice && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-8 max-w-md w-full">
            <h2 className="text-2xl font-bold mb-4">Pay Invoice #{selectedInvoice.id}</h2>
            <div className="mb-4 p-4 bg-gray-100 rounded">
              <p className="text-lg font-semibold">Amount: ${parseFloat(selectedInvoice.amount).toFixed(2)}</p>
              <p className="text-sm text-gray-600">{selectedInvoice.description}</p>
            </div>
            <form onSubmit={handlePayInvoice} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">Payment Method</label>
                <select
                  className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"
                  value={paymentForm.method}
                  onChange={(e) => setPaymentForm({...paymentForm, method: e.target.value})}
                >
                  <option value="credit_card">Credit Card</option>
                  <option value="debit_card">Debit Card</option>
                  <option value="paypal">PayPal</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Card Number</label>
                <input
                  type="text"
                  required
                  placeholder="4111 1111 1111 1111"
                  className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"
                  value={paymentForm.cardNumber}
                  onChange={(e) => setPaymentForm({...paymentForm, cardNumber: e.target.value})}
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700">CVV</label>
                  <input
                    type="text"
                    required
                    placeholder="123"
                    maxLength="4"
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"
                    value={paymentForm.cvv}
                    onChange={(e) => setPaymentForm({...paymentForm, cvv: e.target.value})}
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700">Expiry</label>
                  <input
                    type="text"
                    required
                    placeholder="MM/YY"
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"
                    value={paymentForm.expiry}
                    onChange={(e) => setPaymentForm({...paymentForm, expiry: e.target.value})}
                  />
                </div>
              </div>
              <div className="flex space-x-2">
                <button
                  type="submit"
                  className="flex-1 bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded font-medium"
                >
                  Pay Now
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setShowPaymentModal(false);
                    setSelectedInvoice(null);
                  }}
                  className="flex-1 bg-gray-300 hover:bg-gray-400 text-gray-800 px-4 py-2 rounded"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Invoices Table */}
      <div className="bg-white rounded-lg shadow">
        <div className="px-6 py-4 border-b">
          <h2 className="text-xl font-semibold text-gray-800">All Invoices</h2>
        </div>
        <div className="p-6">
          {invoices.length === 0 ? (
            <p className="text-gray-500 text-center py-8">No invoices found</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Invoice ID</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Description</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Amount</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Date</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {invoices.map((invoice) => (
                    <tr key={invoice.id}>
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                        #{invoice.id}
                      </td>
                      <td className="px-6 py-4 text-sm text-gray-900">
                        {invoice.description || 'N/A'}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        ${parseFloat(invoice.amount).toFixed(2)}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                          invoice.status === 'paid' 
                            ? 'bg-green-100 text-green-800' 
                            : invoice.status === 'pending'
                            ? 'bg-yellow-100 text-yellow-800'
                            : 'bg-red-100 text-red-800'
                        }`}>
                          {invoice.status}
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {new Date(invoice.created_at).toLocaleDateString()}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm">
                        {invoice.status === 'pending' && (
                          <button
                            onClick={() => {
                              setSelectedInvoice(invoice);
                              setShowPaymentModal(true);
                            }}
                            className="text-blue-600 hover:text-blue-900 font-medium"
                          >
                            Pay Now
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default Billing;