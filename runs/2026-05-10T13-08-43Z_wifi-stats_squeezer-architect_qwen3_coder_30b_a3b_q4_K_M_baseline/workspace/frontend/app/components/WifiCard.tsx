'use client';

interface WifiCardProps {
  ssid: string | null;
  bssid: string | null;
  rssi: number | null;
  channel: number | null;
  tx_rate: number | null;
  security: string;
}

const WifiCard: React.FC<WifiCardProps> = (props) => {
  const { ssid, bssid, rssi, channel, tx_rate, security } = props;

  const getRssiColor = (rssi: number | null) => {
    if (rssi === null) return 'text-gray-500';
    if (rssi >= -50) return 'text-green-500';
    if (rssi >= -65) return 'text-yellow-500';
    return 'text-red-500';
  };

  const getRssiStrength = (rssi: number | null) => {
    if (rssi === null) return 'Not connected';
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -65) return 'Good';
    if (rssi >= -75) return 'Fair';
    return 'Weak';
  };

  return (
    <div className="bg-white rounded-xl shadow-lg p-6 max-w-md w-full">
      <h2 className="text-2xl font-bold text-gray-800 mb-4">Wi-Fi Information</h2>
      
      <div className="space-y-3">
        <div className="flex justify-between items-center">
          <span className="text-gray-600 font-medium">Network Name:</span>
          <span className="font-semibold">{ssid || 'N/A'}</span>
        </div>
        
        <div className="flex justify-between items-center">
          <span className="text-gray-600 font-medium">BSSID:</span>
          <span className="font-mono text-sm">{bssid || 'N/A'}</span>
        </div>
        
        <div className="flex justify-between items-center">
          <span className="text-gray-600 font-medium">Signal Strength:</span>
          <div className="flex items-center">
            <span className={`font-semibold ${getRssiColor(rssi)}`}>
              {rssi !== null ? `${rssi} dBm` : 'N/A'}
            </span>
            <span className="ml-2 text-sm text-gray-500">
              ({getRssiStrength(rssi)})
            </span>
          </div>
        </div>
        
        <div className="flex justify-between items-center">
          <span className="text-gray-600 font-medium">Channel:</span>
          <span className="font-semibold">{channel !== null ? channel : 'N/A'}</span>
        </div>
        
        <div className="flex justify-between items-center">
          <span className="text-gray-600 font-medium">TX Rate:</span>
          <span className="font-semibold">{tx_rate !== null ? `${tx_rate} Mbps` : 'N/A'}</span>
        </div>
        
        <div className="flex justify-between items-center">
          <span className="text-gray-600 font-medium">Security:</span>
          <span className="font-semibold">{security}</span>
        </div>
      </div>
    </div>
  );
};

export default WifiCard;