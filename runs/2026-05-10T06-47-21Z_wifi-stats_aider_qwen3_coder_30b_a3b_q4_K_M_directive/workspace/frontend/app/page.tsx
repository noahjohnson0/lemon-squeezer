'use client';

import { useState, useEffect } from 'react';

interface WifiInfo {
  ssid: string;
  bssid: string;
  rssi: string;
  channel: string;
  tx_rate: string;
  security: string;
}

export default function Home() {
  const [wifiInfo, setWifiInfo] = useState<WifiInfo | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchWifiInfo = async () => {
    try {
      const response = await fetch('/api/wifi');
      const data = await response.json();
      
      if (data.error) {
        setError(data.error);
      } else {
        setWifiInfo(data);
        setError(null);
      }
    } catch (err) {
      setError('Failed to fetch Wi-Fi information');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchWifiInfo();
    const interval = setInterval(fetchWifiInfo, 3000);
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="text-xl">Loading Wi-Fi information...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="text-xl text-red-600">Error: {error}</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-100 p-4">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-3xl font-bold text-center mb-8">Wi-Fi Network Information</h1>
        
        {wifiInfo && (
          <div className="bg-white rounded-lg shadow-md p-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="bg-blue-50 p-4 rounded">
                <h2 className="text-lg font-semibold text-gray-700">Network Name (SSID)</h2>
                <p className="text-xl font-bold">{wifiInfo.ssid}</p>
              </div>
              
              <div className="bg-green-50 p-4 rounded">
                <h2 className="text-lg font-semibold text-gray-700">BSSID</h2>
                <p className="text-xl font-bold">{wifiInfo.bssid}</p>
              </div>
              
              <div className="bg-yellow-50 p-4 rounded">
                <h2 className="text-lg font-semibold text-gray-700">Signal Strength (dBm)</h2>
                <p className="text-xl font-bold">{wifiInfo.rssi}</p>
              </div>
              
              <div className="bg-purple-50 p-4 rounded">
                <h2 className="text-lg font-semibold text-gray-700">Channel</h2>
                <p className="text-xl font-bold">{wifiInfo.channel}</p>
              </div>
              
              <div className="bg-pink-50 p-4 rounded">
                <h2 className="text-lg font-semibold text-gray-700">Transmit Rate (Mbps)</h2>
                <p className="text-xl font-bold">{wifiInfo.tx_rate}</p>
              </div>
              
              <div className="bg-indigo-50 p-4 rounded">
                <h2 className="text-lg font-semibold text-gray-700">Security</h2>
                <p className="text-xl font-bold">{wifiInfo.security}</p>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
