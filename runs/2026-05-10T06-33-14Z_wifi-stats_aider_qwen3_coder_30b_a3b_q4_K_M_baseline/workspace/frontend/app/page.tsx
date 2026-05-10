'use client';

import { useState, useEffect } from 'react';

interface WifiInfo {
  ssid: string;
  bssid: string;
  rssi: number | string;
  channel: string;
  tx_rate: number | string;
  security: string;
}

export default function Home() {
  const [wifiInfo, setWifiInfo] = useState<WifiInfo | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchWifiInfo = async () => {
      try {
        const response = await fetch('/api/wifi');
        const data = await response.json();
        
        if (data.error) {
          setError(data.error);
        } else {
          setWifiInfo(data);
        }
      } catch (err) {
        setError('Failed to fetch Wi-Fi information');
      } finally {
        setLoading(false);
      }
    };

    fetchWifiInfo();
    const interval = setInterval(fetchWifiInfo, 3000);
    
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
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative max-w-md" role="alert">
          <strong className="font-bold">Error! </strong>
          <span className="block sm:inline">{error}</span>
        </div>
      </div>
    );
  }

  if (!wifiInfo) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="text-center">
          <p className="text-gray-600">No Wi-Fi information available</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-100 p-4 md:p-8">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-3xl font-bold text-center text-gray-800 mb-8">Wi-Fi Network Stats</h1>
        
        <div className="bg-white rounded-xl shadow-lg overflow-hidden">
          <div className="p-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="bg-blue-50 rounded-lg p-4">
                <h2 className="text-lg font-semibold text-gray-700 mb-2">Network Information</h2>
                <div className="space-y-2">
                  <div className="flex justify-between">
                    <span className="text-gray-600">SSID:</span>
                    <span className="font-medium">{wifiInfo.ssid}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">BSSID:</span>
                    <span className="font-medium">{wifiInfo.bssid}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Channel:</span>
                    <span className="font-medium">{wifiInfo.channel}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Security:</span>
                    <span className="font-medium">{wifiInfo.security}</span>
                  </div>
                </div>
              </div>
              
              <div className="bg-green-50 rounded-lg p-4">
                <h2 className="text-lg font-semibold text-gray-700 mb-2">Signal & Performance</h2>
                <div className="space-y-2">
                  <div className="flex justify-between">
                    <span className="text-gray-600">Signal Strength:</span>
                    <span className={`font-medium ${typeof wifiInfo.rssi === 'number' && wifiInfo.rssi > -50 ? 'text-green-600' : 
                      typeof wifiInfo.rssi === 'number' && wifiInfo.rssi > -70 ? 'text-yellow-600' : 'text-red-600'}`}>
                      {typeof wifiInfo.rssi === 'number' ? `${wifiInfo.rssi} dBm` : wifiInfo.rssi}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">TX Rate:</span>
                    <span className="font-medium">
                      {typeof wifiInfo.tx_rate === 'number' ? `${wifiInfo.tx_rate} Mbps` : wifiInfo.tx_rate}
                    </span>
                  </div>
                </div>
              </div>
            </div>
            
            <div className="mt-6 pt-4 border-t border-gray-200">
              <div className="flex items-center justify-between">
                <div className="text-sm text-gray-500">
                  Last updated: {new Date().toLocaleTimeString()}
                </div>
                <div className="text-sm text-gray-500">
                  Auto-refreshing every 3 seconds
                </div>
              </div>
            </div>
          </div>
        </div>
        
        <div className="mt-8 text-center text-gray-500 text-sm">
          <p>Wi-Fi stats refresh automatically every 3 seconds</p>
        </div>
      </div>
    </div>
  );
}
