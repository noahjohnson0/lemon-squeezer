import { useState, useEffect } from 'react'

export default function Home() {
  const [wifiData, setWifiData] = useState<any>({})
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const fetchWifiData = async () => {
      try {
        const res = await fetch('/api/wifi')
        const data = await res.json()
        setWifiData(data)
        setLoading(false)
      } catch (error) {
        console.error('Error fetching WiFi data:', error)
        setLoading(false)
      }
    }

    fetchWifiData()
    const interval = setInterval(fetchWifiData, 3000)
    return () => clearInterval(interval)
  }, [])

  if (loading) {
    return <div>Loading...</div>
  }

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold mb-6">WiFi Network Stats</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <div className="p-6 border rounded-lg">
          <h2 className="text-lg font-semibold mb-2">SSID</h2>
          <p>{wifiData.ssid || 'N/A'}</p>
        </div>
        <div className="p-6 border rounded-lg">
          <h2 className="text-lg font-semibold mb-2">BSSID</h2>
          <p>{wifiData.bssid || 'N/A'}</p>
        </div>
        <div className="p-6 border rounded-lg">
          <h2 className="text-lg font-semibold mb-2">Signal Strength</h2>
          <p>{wifiData.rssi || 'N/A'} dBm</p>
        </div>
        <div className="p-6 border rounded-lg">
          <h2 className="text-lg font-semibold mb-2">Channel</h2>
          <p>{wifiData.channel || 'N/A'}</p>
        </div>
        <div className="p-6 border rounded-lg">
          <h2 className="text-lg font-semibold mb-2">TX Rate</h2>
          <p>{wifiData.tx_rate || 'N/A'} Mbps</p>
        </div>
        <div className="p-6 border rounded-lg">
          <h2 className="text-lg font-semibold mb-2">Security</h2>
          <p>{wifiData.security || 'N/A'}</p>
        </div>
      </div>
    </div>
  )
}