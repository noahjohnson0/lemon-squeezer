"use client";

import { useState, useEffect } from "react";

export default function Page() {
  const [wifiData, setWifiData] = useState<Record<string, any> | null>(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const res = await fetch("/api/wifi");
        const data = await res.json();
        setWifiData(data);
      } catch (error) {
        console.error("Error fetching Wi-Fi data:", error);
      }
    };

    fetchData();
    const interval = setInterval(fetchData, 3000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="p-4">
      {wifiData ? (
        <div className="bg-white p-6 rounded shadow">
          <h1 className="text-xl font-bold mb-4">Wi-Fi Stats</h1>
          <p><span className="font-semibold">SSID:</span> {wifiData.ssid}</p>
          <p><span className="font-semibold">BSSID:</span> {wifiData.bssid}</p>
          <p><span className="font-semibold">RSSI:</span> {wifiData.rssi} dBm</p>
          <p><span className="font-semibold">Channel:</span> {wifiData.channel}</p>
          <p><span className="font-semibold">TX Rate:</span> {wifiData.tx_rate} Mbps</p>
          <p><span className="font-semibold">Security:</span> {wifiData.security}</p>
        </div>
      ) : (
        <p className="text-gray-500">Loading Wi-Fi data...</p>
      )}
    </div>
  );
}