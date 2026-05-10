import React, { useEffect, useState } from 'react';
import axios from 'axios';

const IndexPage = () => {
  const [wifiInfo, setWifiInfo] = useState({});

  useEffect(() => {
    const fetchWiFiStats = async () => {
      try {
        const response = await axios.get('/api/wifi');
        setWifiInfo(response.data);
      } catch (error) {
        console.error('Error fetching WiFi stats:', error.message);
      }
    };

    // Fetch WiFi stats every 3 seconds
    const intervalId = setInterval(fetchWiFiStats, 3000);

    fetchWiFiStats(); // Initial fetch

    return () => clearInterval(intervalId); // Cleanup on unmount
  }, []);

  return (
    <div className="card">
      {Object.entries(wifiInfo).map(([key, value]) => (
        <p key={key}>
          <strong>{key}:</strong> {value}
        </p>
      ))}
    </div>
  );
};

export default IndexPage;
