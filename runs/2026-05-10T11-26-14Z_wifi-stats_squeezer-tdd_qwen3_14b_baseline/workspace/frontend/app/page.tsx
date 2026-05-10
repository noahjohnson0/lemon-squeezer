import { useEffect, useState } from 'react';

export default function Home() {
  const [wifiStats, setWifiStats] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const res = await fetch('/api/wifi');
        if (!res.ok) throw new Error('Failed to fetch Wi-Fi stats');
        const data = await res.json();
        setWifiStats(data);
        setError(null);
      } catch (err) {
        setError(err.message);
        setWifiStats(null);
      }
    };

    // Fetch every 3 seconds
    const interval = setInterval(fetchStats, 3000);
    fetchStats(); // Initial fetch

    return () => clearInterval(interval);
  }, []);

  if (error) {
    return (
      <div className="p-8 text-center text-red-500">
        <h1 className="text-2xl font-bold mb-4">Error</h1>
        <p>{error}</p>
      </div>
    );
  }

  if (!wifiStats) {
    return (
      <div className="p-8 text-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-blue-500 mx-auto"></div>
        <p className="mt-4">Loading Wi-Fi stats...</p>
      </div>
    );
  }

  return (
    <div className="p-8">
      <h1 className="text-3xl font-bold mb-6">Wi-Fi Network Stats</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="p-6 bg-white rounded-lg shadow">
          <h2 className="text-xl font-semibold mb-2">Network Info</h2>
          <div className="space-y-2">
            <p><span className="font-medium">SSID:</span> {wifiStats.ssid}</p>
            <p><span className="font-medium">BSSID:</span> {wifiStats.bssid}</p>
            <p><span className="font-medium">Security:</span> {wifiStats.security}</p>
          </div>
        </div>
        
        <div className="p-6 bg-white rounded-lg shadow">
          <h2 className="text-xl font-semibold mb-2">Signal Info</h2>
          <div className="space-y-2">
            <p><span className="font-medium">RSSI:</span> {wifiStats.rssi} dBm</p>
            <p><span className="font-medium">Channel:</span> {wifiStats.channel}</p>
            <p><span className="font-medium">TX Rate:</span> {wifiStats.tx_rate} Mbps</p>
          </div>
        </div>
      </div>
    </div>
  );
}