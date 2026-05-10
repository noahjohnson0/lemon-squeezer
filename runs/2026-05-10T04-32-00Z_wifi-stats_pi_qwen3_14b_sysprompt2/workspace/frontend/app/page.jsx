import { useState, useEffect } from 'react';

export default function Home() {
  const [wifiStats, setWifiStats] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const response = await fetch('http://localhost:8000/api/wifi');
        const data = await response.json();
        setWifiStats(data);
        setLoading(false);
      } catch (error) {
        console.error('Error fetching Wi-Fi stats:', error);
        setLoading(false);
      }
    };

    const interval = setInterval(fetchData, 3000);
    fetchData(); // Initial fetch

    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return <div>Loading Wi-Fi stats...</div>;
  }

  if (!wifiStats) {
    return <div>Failed to retrieve Wi-Fi stats.</div>;
  }

  return (
    <div className="p-6 max-w-md mx-auto">
      <div className="bg-white shadow rounded-lg p-4">
        <h2 className="text-xl font-bold mb-4">Wi-Fi Network</h2>
        <div className="space-y-3">
          <div>
            <span className="font-semibold">SSID:</span> {wifiStats.ssid}
          </div>
          <div>
            <span className="font-semibold">BSSID:</span> {wifiStats.bssid}
          </div>
          <div>
            <span className="font-semibold">Signal Strength:</span> {wifiStats.rssi} dBm
          </div>
          <div>
            <span className="font-semibold">Channel:</span> {wifiStats.channel}
          </div>
          <div>
            <span className="font-semibold">TX Rate:</span> {wifiStats.tx_rate} Mbps
          </div>
          <div>
            <span className="font-semibold">Security:</span> {wifiStats.security}
          </div>
        </div>
      </div>
    </div>
  );
}