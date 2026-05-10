import { useState, useEffect } from 'react';

export default function Home() {
  const [wifiData, setWifiData] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchWifiData = async () => {
      try {
        const response = await fetch('/api/wifi');
        if (!response.ok) {
          throw new Error('Failed to fetch Wi-Fi data');
        }
        const data = await response.json();
        setWifiData(data);
        setError(null);
      } catch (err) {
        setError(err.message);
        setWifiData(null);
      }
    };

    fetchWifiData();
    const interval = setInterval(fetchWifiData, 3000);
    return () => clearInterval(interval);
  }, []);

  if (error) {
    return (
      <div className="p-4 text-red-500">
        Error: {error}
      </div>
    );
  }

  if (!wifiData) {
    return <div className="p-4">Loading Wi-Fi data...</div>;
  }

  return (
    <div className="p-6 max-w-md mx-auto bg-white rounded-lg shadow-lg">
      <h1 className="text-2xl font-bold mb-6">Wi-Fi Network Info</h1>
      
      <div className="grid grid-cols-2 gap-4">
        <div className="p-3 bg-gray-100 rounded">
          <div className="font-semibold">SSID</div>
          <div>{wifiData.ssid}</div>
        </div>
        <div className="p-3 bg-gray-100 rounded">
          <div className="font-semibold">BSSID</div>
          <div>{wifiData.bssid}</div>
        </div>
        <div className="p-3 bg-gray-100 rounded">
          <div className="font-semibold">Signal Strength</div>
          <div>{wifiData.rssi} dBm</div>
        </div>
        <div className="p-3 bg-gray-100 rounded">
          <div className="font-semibold">Channel</div>
          <div>{wifiData.channel}</div>
        </div>
        <div className="p-3 bg-gray-100 rounded">
          <div className="font-semibold">Tx Rate</div>
          <div>{wifiData.tx_rate} Mbps</div>
        </div>
        <div className="p-3 bg-gray-100 rounded">
          <div className="font-semibold">Security</div>
          <div>{wifiData.security}</div>
        </div>
      </div>
    </div>
  );
