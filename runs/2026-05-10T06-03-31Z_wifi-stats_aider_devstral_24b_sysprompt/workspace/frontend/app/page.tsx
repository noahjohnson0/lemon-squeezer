'use client';

import { useEffect, useState } from 'react';

interface WifiStats {
  ssid: string;
  bssid: string;
  rssi: number;
  channel: number;
  tx_rate: number;
  security: string;
}

const fetchWifiStats = async (): Promise<WifiStats> => {
  const response = await fetch('http://localhost:8000/api/wifi');
  if (!response.ok) {
    throw new Error('Network response was not ok');
  }
  return response.json();
};

export default function Home() {
  const [wifiStats, setWifiStats] = useState<WifiStats | null>(null);

  useEffect(() => {
    const intervalId = setInterval(async () => {
      try {
        const stats = await fetchWifiStats();
        setWifiStats(stats);
      } catch (error) {
        console.error('Failed to fetch Wi-Fi stats:', error);
      }
    }, 3000);

    return () => clearInterval(intervalId);
  }, []);

  if (!wifiStats) {
    return <div>Loading...</div>;
  }

  return (
    <div className="card">
      <h1>Wi-Fi Stats</h1>
      <p><strong>SSID:</strong> {wifiStats.ssid}</p>
      <p><strong>BSSID:</strong> {wifiStats.bssid}</p>
      <p><strong>RSSI:</strong> {wifiStats.rssi} dBm</p>
      <p><strong>Channel:</strong> {wifiStats.channel}</p>
      <p><strong>Tx Rate:</strong> {wifiStats.tx_rate} Mbps</p>
      <p><strong>Security:</strong> {wifiStats.security}</p>
    </div>
  );
}
