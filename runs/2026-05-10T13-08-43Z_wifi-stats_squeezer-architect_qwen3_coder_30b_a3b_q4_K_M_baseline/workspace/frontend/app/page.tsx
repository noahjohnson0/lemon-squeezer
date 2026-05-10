'use client';

import { useEffect, useState } from 'react';
import WifiCard from './components/WifiCard';

interface WifiData {
  ssid: string | null;
  bssid: string | null;
  rssi: number | null;
  channel: number | null;
  tx_rate: number | null;
  security: string;
}

export default function Home() {
  const [wifiData, setWifiData] = useState<WifiData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchWifiData = async () => {
      try {
        const response = await fetch('http://localhost:8000/api/wifi');
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        const data = await response.json();
        setWifiData(data);
      } catch (err) {
        setError('Failed to fetch Wi-Fi data');
        console.error('Error fetching Wi-Fi data:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchWifiData();
    
    // Refresh data every 5 seconds
    const interval = setInterval(fetchWifiData, 5000);
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading Wi-Fi information...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center">
        <div className="bg-white rounded-xl shadow-lg p-6 max-w-md w-full text-center">
          <div className="text-red-500 text-5xl mb-4">⚠️</div>
          <h2 className="text-2xl font-bold text-gray-800 mb-2">Error</h2>
          <p className="text-gray-600">{error}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <div className="flex flex-col items-center">
        <h1 className="text-3xl font-bold text-gray-800 mb-2">Wi-Fi Stats</h1>
        <p className="text-gray-600 mb-8">Real-time Wi-Fi network information</p>
        
        {wifiData && <WifiCard {...wifiData} />}
        
        <div className="mt-8 text-center text-gray-500 text-sm">
          <p>Data refreshes every 5 seconds</p>
        </div>
      </div>
    </div>
  );
}