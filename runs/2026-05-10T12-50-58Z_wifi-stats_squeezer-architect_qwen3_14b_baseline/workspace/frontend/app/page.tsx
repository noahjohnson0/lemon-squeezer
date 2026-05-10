import { WifiInfo } from "../models/WifiInfo";
import styles from "../styles/globals.css";

export default function WifiPage() {
  const { data, error, loading } = useWifi(3000);

  if (loading) {
    return <div className={styles.loading}>Fetching...</div>;
  }

  if (error) {
    return <div className={styles.error}>Error: {error.message}</div>;
  }

  if (!data) {
    return <div className={styles.empty}>No data available</div>;
  }

  return (
    <div className={styles.card}>
      <h1>Wi-Fi Stats</h1>
      <p><strong>SSID:</strong> {data.ssid}</p>
      <p><strong>BSSID:</strong> {data.bssid}</p>
      <p><strong>Signal:</strong> {data.rssi} dBm</p>
      <p><strong>Channel:</strong> {data.channel}</p>
      <p><strong>Speed:</strong> {data.tx_rate}</p>
      <p><strong>Security:</strong> {data.security}</p>
    </div>
  );
}