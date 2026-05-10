"use client";

import { useEffect, useState } from 'react';

export default function Home() {
  const [wifiStats, setWifiStats] = useState(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const response = await fetch('/api/wifi');
        const data = await response.json();
        setWifiStats(data);
      } catch (error) {
        console.error('Error fetching Wi-Fi stats:', error);
      }
    };

    const interval = setInterval(fetchData, 3000);

    return () => clearInterval(interval);
  }, []);

  if (!wifiStats) {
    return <div>Loading...</div>;
  }

  return (
    <div className="flex items-center justify-center min-h-screen bg-gray-100">
      <div className="bg-white p-6 rounded-lg shadow-md w-full max-w-sm">
        <h2 className="text-xl font-bold mb-4">Wi-Fi Stats</h2>
        <p><strong>SSID:</strong> {wifiStats.ssid}</p>
        <p><strong>BSSID:</strong> {wifiStats.bssid}</p>
        <p><strong>RSSI:</strong> {wifiStats.rssi} dBm</p>
        <p><strong>Channel:</strong> {wifiStats.channel}</p>
        <p><strong>TX Rate:</strong> {wifiStats.tx_rate} Mbps</p>
        <p><strong>Security:</strong> {wifiStats.security}</p>
      </div>
    </div>
  );
}
