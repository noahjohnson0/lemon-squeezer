'use client';

import { useEffect, useState } from 'react';

interface WifiInfo {
  ssid: string;
  bssid: string;
  rssi: number;
  channel: number;
  tx_rate: number;
  security: string;
}

const Page = () => {
  const [wifiInfo, setWifiInfo] = useState<WifiInfo | null>(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const response = await fetch('/api/wifi');
        const data = await response.json();
        setWifiInfo(data);
      } catch (error) {
        console.error('Error fetching Wi-Fi info:', error);
      }
    };

    fetchData();

    const intervalId = setInterval(fetchData, 3000);

    return () => clearInterval(intervalId);
  }, []);

  if (!wifiInfo) {
    return <div>Loading...</div>;
  }

  return (
    <div className="card">
      <h1>Wi-Fi Stats</h1>
      <p><strong>SSID:</strong> {wifiInfo.ssid}</p>
      <p><strong>BSSID:</strong> {wifiInfo.bssid}</p>
      <p><strong>RSSI (dBm):</strong> {wifiInfo.rssi}</p>
      <p><strong>Channel:</strong> {wifiInfo.channel}</p>
      <p><strong>Tx Rate (Mbps):</strong> {wifiInfo.tx_rate}</p>
      <p><strong>Security:</strong> {wifiInfo.security}</p>
    </div>
  );
};

export default Page;
