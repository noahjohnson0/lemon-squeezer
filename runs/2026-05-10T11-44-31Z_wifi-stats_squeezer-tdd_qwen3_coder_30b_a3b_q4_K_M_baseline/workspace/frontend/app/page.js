'use client';

import { useState, useEffect } from 'react';
import './globals.css';

export default function Home() {
  const [wifiData, setWifiData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchWifiData = async () => {
    try {
      const response = await fetch('http://localhost:8000/api/wifi');
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      const data = await response.json();
      setWifiData(data);
      setLoading(false);
    } catch (err) {
      setError(err.message);
      setLoading(false);
    }
  };

  useEffect(() => {
    // Fetch data immediately
    fetchWifiData();
    
    // Set up interval to fetch data every 3 seconds
    const interval = setInterval(fetchWifiData, 3000);
    
    // Clean up interval on unmount
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading Wi-Fi stats...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative max-w-md text-center" role="alert">
          <strong className="font-bold">Error! </strong>
          <span className="block sm:inline">{error}</span>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-100 p-4 md:p-8">
      <div className="max-w-4xl mx-auto">
        <header className="text-center mb-8">
          <h1 className="text-3xl font-bold text-gray-800">Wi-Fi Network Stats</h1>
          <p className="text-gray-600">Real-time network information</p>
        </header>

        <div className="bg-white rounded-xl shadow-lg overflow-hidden">
          <div className="p-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="space-y-4">
                <div className="flex justify-between border-b pb-2">
                  <span className="font-medium text-gray-600">SSID:</span>
                  <span className="font-semibold">{wifiData.ssid}</span>
                </div>
                <div className="flex justify-between border-b pb-2">
                  <span className="font-medium text-gray-600">BSSID:</span>
                  <span className="font-semibold">{wifiData.bssid}</span>
                </div>
                <div className="flex justify-between border-b pb-2">
                  <span className="font-medium text-gray-600">Channel:</span>
                  <span className="font-semibold">{wifiData.channel}</span>
                </div>
                <div className="flex justify-between border-b pb-2">
                  <span className="font-medium text-gray-600">Security:</span>
                  <span className="font-semibold">{wifiData.security}</span>
                </div>
              </div>
              
              <div className="space-y-4">
                <div className="flex justify-between border-b pb-2">
                  <span className="font-medium text-gray-600">Signal Strength:</span>
                  <span className={`font-semibold ${parseInt(wifiData.rssi || 0) < -70 ? 'text-red-600' : parseInt(wifiData.rssi || 0) < -50 ? 'text-yellow-600' : 'text-green-600'}`}>
                    {wifiData.rssi} dBm
                  </span>
                </div>
                <div className="flex justify-between border-b pb-2">
                  <span className="font-medium text-gray-600">Tx Rate:</span>
                  <span className="font-semibold">{wifiData.tx_rate} Mbps</span>
                </div>
                <div className="flex justify-between border-b pb-2">
                  <span className="font-medium text-gray-600">Refresh:</span>
                  <span className="font-semibold">Every 3s</span>
                </div>
              </div>
            </div>

            <div className="mt-6 p-4 bg-gray-50 rounded-lg">
              <h3 className="font-medium text-gray-700 mb-2">Network Status</h3>
              <div className="flex items-center">
                <div className="w-3 h-3 rounded-full bg-green-500 mr-2"></div>
                <span className="text-sm text-gray-600">Connected to {wifiData.ssid}</span>
              </div>
            </div>
          </div>
        </div>

        <footer className="mt-8 text-center text-gray-500 text-sm">
          <p>Wi-Fi stats refresh every 3 seconds • Data from macOS network utilities</p>
        </footer>
      </div>
    </div>
  );
}