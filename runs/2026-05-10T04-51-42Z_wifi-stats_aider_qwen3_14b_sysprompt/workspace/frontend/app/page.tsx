import { useEffect, useState } from 'react'

export default function Home() {
  const [wifiStats, setWifiStats] = useState(null)
  const [error, setError] = useState(null)

  useEffect(() => {
    const fetchWifiStats = async () => {
      try {
        const response = await fetch('http://localhost:8000/api/wifi')
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`)
        }
        const data = await response.json()
        setWifiStats(data)
        setError(null)
      } catch (err) {
        setError(err.message)
        setWifiStats(null)
      }
    }

    // Initial fetch
    fetchWifiStats()

    // Poll every 3 seconds
    const interval = setInterval(fetchWifiStats, 3000)

    // Cleanup interval on unmount
    return () => clearInterval(interval)
  }, [])

  if (error) {
    return (
      <div className="p-8 text-center text-red-500">
        Error: {error}
      </div>
    )
  }

  if (!wifiStats) {
    return (
      <div className="p-8 text-center">
        <p>Loading Wi-Fi stats...</p>
      </div>
    )
  }

  return (
    <div className="p-8 max-w-md mx-auto">
      <div className="bg-white shadow-md rounded-lg p-6">
        <h1 className="text-2xl font-bold mb-4">Wi-Fi Stats</h1>
        
        <div className="space-y-3">
          <div>
            <span className="font-medium">SSID:</span> {wifiStats.ssid}
          </div>
          <div>
            <span className="font-medium">BSSID:</span> {wifiStats.bssid}
          </div>
          <div>
            <span className="font-medium">Signal Strength:</span> {wifiStats.rssi} dBm
          </div>
          <div>
            <span className="font-medium">Channel:</span> {wifiStats.channel}
          </div>
          <div>
            <span className="font-medium">Tx Rate:</span> {wifiStats.tx_rate} Mbps
          </div>
          <div>
            <span className="font-medium">Security:</span> {wifiStats.security}
          </div>
        </div>
      </div>
    </div>
  )
}
