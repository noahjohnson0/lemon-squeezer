import React from 'react';

interface WifiInfo {
  ssid: string;
  bssid: string;
  rssi: number;
  channel: string;
  tx_rate: string;
  security: string;
}

interface Props {
  info: WifiInfo;
}

export default function WifiCard({ info }: Props) {
  return (
    <div className="rounded-lg bg-white p-6 shadow-md w-full max-w-md">
      <h2 className="mb-4 text-xl font-semibold">{info.ssid || 'Unknown SSID'}</h2>
      <ul className="space-y-2 text-sm">
        <li>
          <strong>BSSID:</strong> {info.bssid || 'N/A'}
        </li>
        <li>
          <strong>Signal:</strong> {info.rssi} dBm
        </li>
        <li>
          <strong>Channel:</strong> {info.channel || 'N/A'}
        </li>
        <li>
          <strong>TX Rate:</strong> {info.tx_rate || 'N/A'} Mbps
        </li>
        <li>
          <strong>Security:</strong> {info.security || 'N/A'}
        </li>
      </ul>
    </div>
  );
}
