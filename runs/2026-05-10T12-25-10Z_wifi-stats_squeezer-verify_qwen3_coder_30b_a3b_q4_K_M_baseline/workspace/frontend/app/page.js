'use client';

import { useState, useEffect } from 'react';
import './globals.css';

export default function Home() {
  const [wifiStats, setWifiStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchWifiStats = async () => {
    try {
      const response = await fetch('/api/wifi');
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      const data = await response.json();
      setWifiStats(data);
      setLoading(false);
      setError(null);
    } catch (err) {
      setError(err.message);
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchWifiStats();
    const interval = setInterval(fetchWifiStats, 3000);
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto"></div>
          <p className="mt-4 text-gray-600">Fetching Wi-Fi stats...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="text-center bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative" role="alert">
          <strong className="font-bold">Error! </strong>
          <span className="block sm:inline">{error}</span>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-100 p-4">
      <div className="max-w-4xl mx-auto">
        <header className="text-center py-8">
          <h1 className="text-3xl font-bold text-gray-800">Wi-Fi Network Stats</h1>
          <p className="text-gray-600 mt-2">Current network information</p>
        </header>

        <div className="bg-white shadow-lg rounded-lg overflow-hidden">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 p-6">
            <div className="space-y-4">
              <div>
                <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wider">Network Name</h2>
                <p className="text-2xl font-bold text-gray-900">{wifiStats.ssid}</p>
              </div>
              
              <div>
                <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wider">BSSID</h2>
                <p className="text-lg font-mono text-gray-900">{wifiStats.bssid}</p>
              </div>
              
              <div>
                <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wider">Channel</h2>
                <p className="text-2xl font-bold text-gray-900">{wifiStats.channel}</p>
              </div>
            </div>
            
            <div className="space-y-4">
              <div>
                <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wider">Signal Strength</h2>
                <div className="flex items-center">
                  <div className="text-2xl font-bold text-gray-900 mr-3">{wifiStats.rssi} dBm</div>
                  <div className="flex-1 bg-gray-200 rounded-full h-2.5">
                    <div 
                      className="bg-blue-600 h-2.5 rounded-full" 
                      style={{ width: `${Math.max(0, Math.min(100, (wifiStats.rssi + 100) * 100 / 100))}%` }}
                    ></div>
                  </div>
                </div>
              </div>
              
              <div>
                <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wider">Transmission Rate</h2>
                <p className="text-2xl font-bold text-gray-900">{wifiStats.tx_rate} Mbps</p>
              </div>
              
              <div>
                <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wider">Security</h2>
                <p className="text-lg font-bold text-gray-900">{wifiStats.security}</p>
              </div>
            </div>
          </div>
          
          <div className="bg-gray-50 px-6 py-4 border-t border-gray-200">
            <p className="text-sm text-gray-500 text-center">
              Updated every 3 seconds
            </p>
          </div>
        </div>
        
        <div className="mt-8 text-center text-gray-500 text-sm">
          <p>Wi-Fi stats for macOS</p>
        </div>
      </div>
    </div>
  );
}