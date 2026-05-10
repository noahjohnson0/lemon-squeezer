import { useEffect, useState } from 'react'

export default function Home() {
  const [wifiData, setWifiData] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true)
        setError(null)
        const response = await fetch('http://localhost:8000/api/wifi')
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`)
        }
        const data = await response.json()
        setWifiData(data)
      } catch (err) {
        setError(err instanceof Error ? err.message : 'An unknown error occurred')
      } finally {
        setLoading(false)
      }
    }

    const interval = setInterval(fetchData, 3000)
    fetchData() // Initial fetch

    return () => clearInterval(interval)
  }, [])

  if (loading) {
    return <div className="p-8 text-center">Loading...</div>
  }

  if (error) {
    return <div className="p-8 text-center text-red-500">Error: {error}</div>
  }

  if (!wifiData || "error" in wifiData) {
    return <div className="p-8 text-center text-yellow-500">No Wi-Fi data available</div>
  }

  return (
    <div className="p-8 max-w-md mx-auto">
      <div className="bg-white shadow-md rounded-lg p-6">
        <h1 className="text-2xl font-bold mb-4">Wi-Fi Network Info</h1>
        
        <div className="space-y-4">
          <div>
            <span className="font-medium">SSID:</span> <span className="ml-2">{wifiData.ssid}</span>
          </div>
          <div>
            <span className="font-medium">BSSID:</span> <span className="ml-2">{wifiData.bssid}</span>
          </div>
          <div>
            <span className="font-medium">Signal Strength:</span> 
            <span className="ml-2">
              {wifiData.rssi} dBm
              {wifiData.rssi > -50 && <span className="ml-2 text-green-500">✅ Strong</span>}
              {wifiData.rssi <= -50 && wifiData.rssi > -70 && <span className="ml-2 text-yellow-500">⚠️ Moderate</span>}
              {wifiData.rssi <= -70 && <span className="ml-2 text-red-500">❌ Weak</span>}
            </span>
          </div>
          <div>
            <span className="font-medium">Channel:</span> <span className="ml-2">{wifiData.channel}</span>
          </div>
          <div>
            <span className="font-medium">Speed:</span> <span className="ml-2">{wifiData.tx_rate} Mbps</span>
          </div>
          <div>
            <span className="font-medium">Security:</span> <span className="ml-2">{wifiData.security}</span>
          </div>
        </div>
      </div>
    </div>
  )
}
