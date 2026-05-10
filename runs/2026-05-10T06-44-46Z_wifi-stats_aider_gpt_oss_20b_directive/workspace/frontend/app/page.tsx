'use client';

import { useEffect, useState } from 'react';

interface WifiStats {
  ssid: string | null;
  bssid: string | null;
  rssi: number | null;
  channel: number | null;
  tx_rate: number | null;
  security: string | null;
}

export default function Home() {
  const [stats, setStats] = useState<WifiStats | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const res = await fetch('http://localhost:8000/api/wifi');
        if (!res.ok) {
          throw new Error(`HTTP error! status: ${res.status}`);
        }
        const data: WifiStats = await res.json();
        setStats(data);
        setError(null);
      } catch (err: any) {
        setError(err.message);
        setStats(null);
      }
    };

    fetchStats(); // initial fetch
    const interval = setInterval(fetchStats, 3000); // poll every 3 seconds

    return () => clearInterval(interval);
  }, []);

  return (
    <main className="min-h-screen flex flex-col items-center justify-center bg-gray-100 p-4">
      <h1 className="text-3xl font-bold mb-6">Current Wi‑Fi Network</h1>
      {error && (
        <div className="bg-red-100 text-red-800 p-4 rounded mb-4">
          Error: {error}
        </div>
      )}
      {stats ? (
        <div className="bg-white shadow-md rounded p-6 w-full max-w-md">
          <p><strong>SSID:</strong> {stats.ssid ?? 'N/A'}</p>
          <p><strong>BSSID:</strong> {stats.bssid ?? 'N/A'}</p>
          <p><strong>Signal (dBm):</strong> {stats.rssi ?? 'N/A'}</p>
          <p><strong>Channel:</strong> {stats.channel ?? 'N/A'}</p>
          <p><strong>TX Rate (Mbps):</strong> {stats.tx_rate ?? 'N/A'}</p>
          <p><strong>Security:</strong> {stats.security ?? 'N/A'}</p>
        </div>
      ) : (
        <p className="text-gray-500">Loading...</p>
      )}
    </main>
  );
}
