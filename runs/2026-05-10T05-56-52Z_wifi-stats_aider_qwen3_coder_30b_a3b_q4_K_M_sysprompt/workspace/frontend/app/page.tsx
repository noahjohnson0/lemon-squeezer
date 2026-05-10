'use client';

import { useState, useEffect } from 'react';
import './page.css';

interface WifiInfo {
  ssid: string;
  bssid: string;
  rssi: number;
  channel: number;
  tx_rate: number;
  security: string;
}

export default function Home() {
  const [wifiInfo, setWifiInfo] = useState<WifiInfo | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchWifiInfo = async () => {
    try {
      const response = await fetch('/api/wifi');
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      const data = await response.json();
      setWifiInfo(data);
      setError(null);
    } catch (err) {
      setError('Failed to fetch Wi-Fi information');
      console.error('Error fetching Wi-Fi info:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchWifiInfo();
    const interval = setInterval(fetchWifiInfo, 3000);
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div className="container">
        <h1>Wi-Fi Stats</h1>
        <div className="loading">Loading...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="container">
        <h1>Wi-Fi Stats</h1>
        <div className="error">{error}</div>
      </div>
    );
  }

  return (
    <div className="container">
      <h1>Wi-Fi Stats</h1>
      {wifiInfo && (
        <div className="card">
          <div className="card-header">
            <h2>{wifiInfo.ssid}</h2>
          </div>
          <div className="card-body">
            <div className="info-row">
              <span className="label">BSSID:</span>
              <span className="value">{wifiInfo.bssid}</span>
            </div>
            <div className="info-row">
              <span className="label">Signal Strength:</span>
              <span className="value">{wifiInfo.rssi} dBm</span>
            </div>
            <div className="info-row">
              <span className="label">Channel:</span>
              <span className="value">{wifiInfo.channel}</span>
            </div>
            <div className="info-row">
              <span className="label">TX Rate:</span>
              <span className="value">{wifiInfo.tx_rate} Mbps</span>
            </div>
            <div className="info-row">
              <span className="label">Security:</span>
              <span className="value">{wifiInfo.security}</span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
