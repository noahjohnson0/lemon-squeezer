import { useEffect, useState } from 'react';

export default function Home() {
  const [wifiStats, setWifiStats] = useState({
    ssid: '',
    bssid: '',
    rssi: 'N/A',
    channel: 'N/A',
    tx_rate: 'N/A',
    security: 'N/A'
  });

  useEffect(() => {
    const fetchWifiStats = async () => {
      try {
        const response = await fetch('/api/wifi');
        const data = await response.json();
        setWifiStats(data);
      } catch (error) {
        console.error('Failed to fetch Wi-Fi stats:', error);
      }
    };

    // Fetch initial data
    fetchWifiStats();

    // Fetch data every 3 seconds
    const interval = setInterval(fetchWifiStats, 3000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="min-h-screen bg-gray-100 flex items-center justify-center p-4">
      <div className="bg-white p-6 rounded-lg shadow-md w-full max-w-md">
        <h1 className="text-2xl font-bold mb-4 text-center">Wi-Fi Status</h1>
        <div className="space-y-3">
          <div className="flex justify-between items-center">
            <span className="font-medium">SSID:</span>
            <span>{wifiStats.ssid}</span>
          </div>
          <div className="flex justify-between items-center">
            <span className="font-medium">BSSID:</span>
            <span>{wifiStats.bSSID}</span>
          </div>
          <div className="flex justify-between items-center">
            <span className="font-medium">Signal Strength:</span>
            <span>{wifiStats.rssi} dBm</span>
          </div>
          <div className="flex justify-between items-center">
            <span className="font-medium">Channel:</span>
            <span>{wifiStats.channel}</span>
          </div>
          <div className="flex justify-between items-center">
            <span className="font-medium">TX Rate:</span>
            <span>{wifiStats.tx_rate} Mbps</span>
          </div>
          <div className="flex justify-between items-center">
            <span className="font-medium">Security:</span>
            <span>{wifiStats.security}</span>
          </div>
        </div>
      </div>
    </div>
  );
}
