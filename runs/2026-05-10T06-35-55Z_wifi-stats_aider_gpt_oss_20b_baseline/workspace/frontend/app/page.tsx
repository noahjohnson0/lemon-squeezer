import { useEffect, useState } from "react";

interface WifiInfo {
  ssid?: string;
  bssid?: string;
  rssi?: number;
  channel?: string;
  tx_rate?: string;
  security?: string;
  error?: string;
}

export default function Page() {
  const [wifi, setWifi] = useState<WifiInfo>({});

  const fetchWifi = async () => {
    try {
      const res = await fetch("/api/wifi");
      const data = await res.json();
      setWifi(data);
    } catch (err) {
      setWifi({ error: "Failed to fetch Wi‑Fi data" });
    }
  };

  useEffect(() => {
    fetchWifi();
    const interval = setInterval(fetchWifi, 3000);
    return () => clearInterval(interval);
  }, []);

  if (wifi.error) {
    return <div>{wifi.error}</div>;
  }

  return (
    <div className="container">
      <h1>Wi‑Fi Stats</h1>
      <div className="card">
        <p>
          <strong>SSID:</strong> {wifi.ssid ?? "N/A"}
        </p>
        <p>
          <strong>BSSID:</strong> {wifi.bssid ?? "N/A"}
        </p>
        <p>
          <strong>Signal (dBm):</strong> {wifi.rssi ?? "N/A"}
        </p>
        <p>
          <strong>Channel:</strong> {wifi.channel ?? "N/A"}
        </p>
        <p>
          <strong>TX Rate (Mbps):</strong> {wifi.tx_rate ?? "N/A"}
        </p>
        <p>
          <strong>Security:</strong> {wifi.security ?? "N/A"}
        </p>
      </div>
      <style jsx>{`
        .container {
          max-width: 600px;
          margin: 2rem auto;
          font-family: Arial, sans-serif;
        }
        .card {
          padding: 1rem;
          border: 1px solid #ccc;
          border-radius: 8px;
          background: #f9f9f9;
        }
        h1 {
          text-align: center;
        }
      `}</style>
    </div>
  );
}
