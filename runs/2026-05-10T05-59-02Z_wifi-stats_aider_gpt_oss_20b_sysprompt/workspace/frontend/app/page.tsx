'use client';

import { useEffect, useState } from 'react';
import WifiCard from '../components/WifiCard';

interface WifiInfo {
  ssid: string;
  bssid: string;
  rssi: number;
  channel: string;
  tx_rate: string;
  security: string;
}

export default function Home() {
  const [wifi, setWifi] = useState<WifiInfo | null>(null);
  const [error, setError] = useState<string | null>(null);

  const fetchWifi = async () => {
    try {
      const res = await fetch('http://localhost:8000/api/wifi');
      if (!res.ok) {
        throw new Error(`HTTP error! status: ${res.status}`);
      }
      const data: WifiInfo = await res.json();
      setWifi(data);
      setError(null);
    } catch (err: any) {
      setError(err.message);
    }
  };

  useEffect(() => {
    fetchWifi();
    const interval = setInterval(fetchWifi, 3000);
    return () => clearInterval(interval);
  }, []);

  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-gray-100 p-4">
      <h1 className="mb-6 text-3xl font-bold">Wi‑Fi Stats</h1>
      {error && <p className="text-red-500">{error}</p>}
      {wifi ? <WifiCard info={wifi} /> : <p>Loading...</p>}
    </main>
  );
}
