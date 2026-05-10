import { useEffect, useState } from 'react';

export default function Home() {
  const [wifiStats, setWifiStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchWifiStats = async () => {
      try {
        const response = await fetch('/api/wifi');
        if (!response.ok) throw new Error('API request failed');
        const data = await response.json();
        setWifiStats(data);
        setLoading(false);
      } catch (err) {
        setError(err.message);
        setLoading(false);
      }
    };

    const interval = setInterval(fetchWifiStats, 3000);
    fetchWifiStats(); // Initial fetch

    return () => clearInterval(interval);
  }, []);

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error}</div>;

  return (
    <div className="p-8 max-w-lg mx-auto">
      <div className="bg-white shadow rounded-lg p-6">
        <h1 className="text-2xl font-bold mb-4">Wi-Fi Network Stats</h1>
        <div className="grid grid-cols-2 gap-4">
          <div><span className="font-semibold">SSID:</span> {wifiStats.ssid}</div>
          <div><span className="font-semibold">BSSID:</span> {wifiStats.bssid}</div>
          <div><span className="font-semibold">Signal Strength:</span> {wifiStats.rssi} dBm</div>
          <div><span className="font-semibold">Channel:</span> {wifiStats.channel}</div>
          <div><span className="font-semibold">Tx Rate:</span> {wifiStats.tx_rate} Mbps</div>
          <div><span className="font-semibold">Security:</span> {wifiStats.security}</div>
        </div>
      </div>
    </div>
  );
}