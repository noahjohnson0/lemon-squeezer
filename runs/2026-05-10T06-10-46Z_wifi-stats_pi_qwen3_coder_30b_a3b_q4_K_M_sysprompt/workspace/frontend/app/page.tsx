'use client';

import { useState, useEffect } from 'react';
import './globals.css';

interface WifiInfo {
  ssid: string;
  bssid: string;
  rssi: number;
  channel: number;
  tx_rate: number;
  security: string;
}

export default function Home() {
  const [wifiInfo, setWifiInfo] = useState<WifiInfo | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchWifiInfo = async () => {
      try {
        const response = await fetch('http://localhost:8000/api/wifi');
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        const data: WifiInfo = await response.json();
        setWifiInfo(data);
        setError(null);
      } catch (err) {
        setError('Failed to fetch Wi-Fi information');
        console.error('Error fetching Wi-Fi info:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchWifiInfo();
    const interval = setInterval(fetchWifiInfo, 3000); // Fetch every 3 seconds
    
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading Wi-Fi information...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="text-center p-6 bg-white rounded-lg shadow-md max-w-md">
          <h1 className="text-2xl font-bold text-red-600 mb-4">Error</h1>
          <p className="text-gray-700">{error}</p>
          <p className="text-gray-500 text-sm mt-4">Make sure the backend is running on http://localhost:8000</p>
        </div>
      </div>
    );
  }

  if (!wifiInfo) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="text-center p-6 bg-white rounded-lg shadow-md max-w-md">
          <h1 className="text-2xl font-bold text-gray-800 mb-4">No Wi-Fi Information</h1>
          <p className="text-gray-700">No Wi-Fi information available.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-100 p-4 md:p-8">
      <div className="max-w-4xl mx-auto">
        <header className="text-center mb-12">
          <h1 className="text-3xl font-bold text-gray-800">Wi-Fi Network Stats</h1>
          <p className="text-gray-600 mt-2">Current network information</p>
        </header>

        <div className="bg-white rounded-xl shadow-lg overflow-hidden">
          <div className="p-6 border-b border-gray-200">
            <h2 className="text-xl font-semibold text-gray-800">Network Details</h2>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 p-6">
            <div className="bg-gray-50 rounded-lg p-4">
              <h3 className="text-sm font-medium text-gray-500 uppercase tracking-wider">Network Name</h3>
              <p className="text-2xl font-bold mt-1 text-gray-900">{wifiInfo.ssid || 'N/A'}</p>
            </div>
            
            <div className="bg-gray-50 rounded-lg p-4">
              <h3 className="text-sm font-medium text-gray-500 uppercase tracking-wider">BSSID</h3>
              <p className="text-lg font-mono mt-1 text-gray-900">{wifiInfo.bssid || 'N/A'}</p>
            </div>
            
            <div className="bg-gray-50 rounded-lg p-4">
              <h3 className="text-sm font-medium text-gray-500 uppercase tracking-wider">Signal Strength</h3>
              <p className="text-2xl font-bold mt-1 text-gray-900">
                {wifiInfo.rssi !== null ? `${wifiInfo.rssi} dBm` : 'N/A'}
                <span className={`ml-2 text-sm ${wifiInfo.rssi !== null && wifiInfo.rssi > -50 ? 'text-green-600' : wifiInfo.rssi !== null && wifiInfo.rssi > -70 ? 'text-yellow-600' : 'text-red-600'}`}>
                  {wifiInfo.rssi !== null && wifiInfo.rssi > -50 ? 'Excellent' : 
                   wifiInfo.rssi !== null && wifiInfo.rssi > -70 ? 'Good' : 
                   wifiInfo.rssi !== null ? 'Poor' : ''}
                </span>
              </p>
            </div>
            
            <div className="bg-gray-50 rounded-lg p-4">
              <h3 className="text-sm font-medium text-gray-500 uppercase tracking-wider">Channel</h3>
              <p className="text-2xl font-bold mt-1 text-gray-900">{wifiInfo.channel || 'N/A'}</p>
            </div>
            
            <div className="bg-gray-50 rounded-lg p-4">
              <h3 className="text-sm font-medium text-gray-500 uppercase tracking-wider">Transmission Rate</h3>
              <p className="text-2xl font-bold mt-1 text-gray-900">{wifiInfo.tx_rate ? `${wifiInfo.tx_rate.toFixed(1)} Mbps` : 'N/A'}</p>
            </div>
            
            <div className="bg-gray-50 rounded-lg p-4">
              <h3 className="text-sm font-medium text-gray-500 uppercase tracking-wider">Security</h3>
              <p className="text-2xl font-bold mt-1 text-gray-900">{wifiInfo.security || 'N/A'}</p>
            </div>
          </div>
          
          <div className="p-4 bg-gray-50 text-sm text-gray-500 border-t border-gray-200">
            <p>Updated every 3 seconds</p>
          </div>
        </div>
      </div>
    </div>
  );
}