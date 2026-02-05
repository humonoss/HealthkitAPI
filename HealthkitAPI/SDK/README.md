# HealthKit Data Access SDK

This directory contains resources to programmatically access your health data stored in your cloud database.

## Base URL
`https://YOUR_DATABASE_URL.firebaseio.com`

## Data Structure

*   **Real-time Metrics:** `users/{USER_ID}/healthData/realtime/{METRIC_TYPE}`
    *   Supported Types: `heartRate`, `hrv`, `bloodOxygen`, `respiratoryRate`
*   **Daily Aggregates:** `users/{USER_ID}/healthData/aggregated/daily/{YYYY-MM-DD}`

---

## 🐍 Python SDK

A full Python client is provided in `healthkit_api.py`.

### Installation
```bash
pip install -r Python/requirements.txt
```

### Usage
```python
from healthkit_api import HealthKitClient

# Initialize with your User ID (found in Watch App console logs)
client = HealthKitClient(user_id="YOUR_USER_ID")

# Get latest Heart Rate
latest_hr = client.get_realtime_metric("heartRate", limit=1)
print(f"Current Heart Rate: {latest_hr[0]['value']} bpm")

# Get Today\'s Summary
summary = client.get_daily_summary()
print(f"Total Steps: {summary.get('steps', {}).get('total', 0)}")
```

---

## 🌐 HTTP / cURL

You can access data directly using standard HTTP requests.

### Get Latest Heart Rate
Fetch the last 5 heart rate readings.

```bash
curl "https://YOUR_DATABASE_URL.firebaseio.com/users/YOUR_USER_ID/healthData/realtime/heartRate.json?orderBy=\"$\"
```

### Get Daily Summary
Fetch data for a specific date (e.g., 2026-02-04).

```bash
curl "https://YOUR_DATABASE_URL.firebaseio.com/users/YOUR_USER_ID/healthData/aggregated/daily/2026-02-04.json"
```

---

## 🟢 Node.js Example

Using the native `https` module or `axios`.

```javascript
const https = require('https');

const USER_ID = 'YOUR_USER_ID';
const BASE_URL = 'https://YOUR_DATABASE_URL.firebaseio.com';

// Function to get latest metric
function getLatestMetric(type, limit = 1) {
  const url = `${BASE_URL}/users/${USER_ID}/healthData/realtime/${type}.json?orderBy="$"&limitToLast=${limit}`;
  
  https.get(url, (res) => {
    let data = '';
    res.on('data', (chunk) => data += chunk);
    res.on('end', () => {
      const json = JSON.parse(data);
      console.log(`Latest ${type}:`, json);
    });
  }).on('error', (err) => {
    console.error('Error:', err.message);
  });
}

getLatestMetric('heartRate', 1);
```

---

## 🐹 Go Example

```go
package main

import (
	"fmt"
	"io/ioutil"
	"net/http"
)

func main() {
	userID := "YOUR_USER_ID"
	metric := "heartRate"
	url := fmt.Sprintf("https://YOUR_DATABASE_URL.firebaseio.com/users/%s/healthData/realtime/%s.json?orderBy=\"$\"&limitToLast=1", userID, metric)

	resp, err := http.Get(url)
	if err != nil {
		fmt.Printf("Error: %s\n", err)
		return
	}
	defer resp.Body.Close()

	body, _ := ioutil.ReadAll(resp.Body)
	fmt.Println("Response:", string(body))
}
```

## Authentication
If your database rules require authentication, append `?auth=YOUR_ID_TOKEN` to all URL requests or pass it to the Python SDK constructor.

```
