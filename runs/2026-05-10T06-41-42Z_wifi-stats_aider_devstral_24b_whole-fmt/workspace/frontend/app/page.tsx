// This file contains the main page component that fetches and displays Wi-Fi stats

'use client';

import { useEffect, useState } from 'react';

const WifiStats = () => {
  const [wifiData, setWifiData] = useState(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const response = await fetch('http://localhost:8000/api/wifi');
        const data = await response.json();
        setWifiData(data);
      } catch (error) {
        console.error('Error fetching Wi-Fi data:', error);
      }
    };

    fetchData();

    const intervalId = setInterval(fetchData, 3000);

    return () => clearInterval(intervalId);
  }, []);

  if (!wifiData) {
    return <div>Loading...</div>;
  }

  return (
    <div style={styles.card}>
      <h1 style={styles.heading}>Wi-Fi Stats</h1>
      <p><strong>SSID:</strong> {wifiData.ssid}</p>
      <p><strong>BSSID:</strong> {wifiData.bssid}</p>
      <p><strong>RSSI (dBm):</strong> {wifiData.rssi}</p>
      <p><strong>Channel:</strong> {wifiData.channel}</p>
      <p><strong>Tx Rate (Mbps):</strong> {wifiData.tx_rate}</p>
      <p><strong>Security:</strong> {wifiData.security}</p>
    </div>
  );
};

const styles = {
  card: {
    border: '1px solid #ccc',
    padding: '20px',
    maxWidth: '400px',
    margin: 'auto',
    borderRadius: '8px',
    boxShadow: '0 2px 4px rgba(0, 0, 0, 0.1)',
  },
  heading: {
    fontSize: '24px',
    marginBottom: '16px',
  },
};

export default WifiStats;
