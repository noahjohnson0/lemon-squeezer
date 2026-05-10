import { useEffect, useState } from 'react';
import styles from '../styles/Home.module.css';

interface WifiInfo {
  ssid: string | null;
  bssid: string | null;
  rssi: number | null;
  channel: number | null;
  tx_rate: number | null;
  security: string | null;
}

export default function Home() {
  const [wifi, setWifi] = useState<WifiInfo | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchWifi = async () => {
      try {
        const res = await fetch('/api/wifi');
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data: WifiInfo = await res.json();
        setWifi(data);
        setError(null);
      } catch (e) {
        setError((e as Error).message);
      }
    };

    fetchWifi();
    const interval = setInterval(fetchWifi, 3000);
    return () => clearInterval(interval);
  }, []);

  return (
    <main className={styles.main}>
      <div className={styles.cardContainer}>
        {error && <p className={styles.error}>{error}</p>}
        {!wifi && !error && <p>Loading Wi‑Fi info...</p>}
        {wifi && (
          <div className={styles.card}>
            <h2>{wifi.ssid || 'N/A'}</h2>
            <p>
              <strong>BSSID:</strong> {wifi.bssid || 'N/A'}
            </p>
            <p>
              <strong>Signal:</strong> {wifi.rssi !== null ? `${wifi.rssi} dBm` : 'N/A'}
            </p>
            <p>
              <strong>Channel:</strong> {wifi.channel !== null ? wifi.channel : 'N/A'}
            </p>
            <p>
              <strong>Tx Rate:</strong> {wifi.tx_rate !== null ? `${wifi.tx_rate} Mbps` : 'N/A'}
            </p>
            <p>
              <strong>Security:</strong> {wifi.security || 'N/A'}
            </p>
          </div>
        )}
      </div>
    </main>
  );
}
