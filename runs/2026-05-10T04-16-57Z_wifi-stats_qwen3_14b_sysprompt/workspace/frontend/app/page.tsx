import { useEffect, useState } from 'react';

export default function Home() {
  const [wifiStats, setWifiStats] = useState(null);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const res = await fetch('/api/wifi');
        const data = await res.json();
        setWifiStats(data);
      } catch (error) {
        console.error('Error fetching Wi-Fi stats:', error);
      }
    };

    fetchStats();
    const interval = setInterval(fetchStats, 3000);
    return () => clearInterval(interval);
  }, []);

  if (!wifiStats) {
    return <div>Loading...</div>;
  }

  return (
    <div className="p-6 max-w-md mx-auto bg-white rounded shadow">
      <h1 className="text-2xl font-bold mb-4">Wi-Fi Stats</h1>
      <div className="grid grid-cols-1 gap-4">
        <div className="p-4 border rounded">
          <p className="text-sm text-gray-500">SSID</p>
          <p className="font-mono">{wifiStats.ssid}</p>
        </div>
        <div className="p-4 border rounded">
          <p className="text-sm text-gray-500">BSSID</p>
          <p className="font-mono">{wifiStats.bssid}</p>
        </div>
        <div className="p-4 border rounded">
          <p className="text-sm text-gray-500">Signal Strength (dBm)</p>
          <p className="font-mono">{wifiStats.rssi}</p>
        </div>
        <div className="p-4 border rounded">
          <p className="text-sm text-gray-500">Channel</p>
          <p className="font-mono">{wifiStats.channel}</p>
        </div>
        <div className="p-4 border rounded">
          <p className="text-sm text-gray-500">Tx Rate (Mbps)</p>
          <p className="font-mono">{wifiStats.tx_rate}</p>
        </div>
        <div className="p-4 border rounded">
          <p className="text-sm text-gray-500">Security</p>
          <p className="font-mono">{wifiStats.security}</p>
        </div>
      </div>
    </div>
  );
}