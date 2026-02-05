import requests
import json
from datetime import datetime
from typing import Optional, Dict, List, Any, Union

class HealthKitClient:
    """
    A Python client to interact with the HealthkitAPI Firebase Backend.
    """
    
    BASE_URL = "https://YOUR_DATABASE_URL.firebaseio.com"
    
    def __init__(self, user_id: str, auth_token: Optional[str] = None):
        """
        Initialize the HealthKit Client.
        
        Args:
            user_id (str): The unique User ID (UID) of the user to fetch data for.
            auth_token (str, optional): Firebase Auth ID Token. Required if database rules are secure.
        """
        self.user_id = user_id
        self.auth_token = auth_token
        self.session = requests.Session()
    
    def _get_params(self, params: Dict = None) -> Dict:
        """Helper to attach auth token to request params."""
        if params is None:
            params = {}
        if self.auth_token:
            params['auth'] = self.auth_token
        return params

    def get_realtime_metric(self, metric_type: str, limit: int = 1) -> List[Dict[str, Any]]:
        """
        Fetch the latest real-time metrics for a specific type.
        
        Args:
            metric_type (str): The type of metric (e.g., 'heartRate', 'hrv', 'stepCount').
            limit (int): Number of recent data points to fetch. Defaults to 1.
            
        Returns:
            List[Dict]: A list of data points sorted by timestamp (newest first).
        """
        path = f"users/{self.user_id}/healthData/realtime/{metric_type}.json"
        url = f"{self.BASE_URL}/{path}"
        
        # Optimize query to fetch only the last 'limit' items
        # Firebase Push IDs are chronologically sorted, so "$key" works.
        params = self._get_params({
            'orderBy': '"$key"',
            'limitToLast': limit
        })
        
        try:
            response = self.session.get(url, params=params)
            response.raise_for_status()
            data = response.json()
            
            if not data:
                return []
            
            # Convert dict of push-ids to list
            results = []
            for key, value in data.items():
                item = value.copy()
                item['id'] = key
                results.append(item)
            
            # Sort by timestamp descending (newest first)
            results.sort(key=lambda x: x.get('timestamp', 0), reverse=True)
            return results
            
        except requests.exceptions.RequestException as e:
            print(f"Error fetching realtime metric {metric_type}: {e}")
            return []

    def get_daily_summary(self, date_str: Optional[str] = None) -> Dict[str, Any]:
        """
        Fetch the aggregated daily summary for a specific date.
        
        Args:
            date_str (str, optional): Date in 'YYYY-MM-DD' format. Defaults to today.
            
        Returns:
            Dict: The aggregated data packet for that day.
        """
        if not date_str:
            date_str = datetime.now().strftime("%Y-%m-%d")
            
        path = f"users/{self.user_id}/healthData/aggregated/daily/{date_str}.json"
        url = f"{self.BASE_URL}/{path}"
        
        params = self._get_params()
        
        try:
            response = self.session.get(url, params=params)
            response.raise_for_status()
            return response.json() or {{}}
            
        except requests.exceptions.RequestException as e:
            print(f"Error fetching daily summary for {date_str}: {e}")
            return {{}}

    def get_all_aggregated_history(self) -> Dict[str, Any]:
        """
        Fetch all aggregated daily history available for the user.
        Warning: This might fetch a large amount of data.
        """
        path = f"users/{self.user_id}/healthData/aggregated/daily.json"
        url = f"{self.BASE_URL}/{path}"
        
        params = self._get_params()
        
        try:
            response = self.session.get(url, params=params)
            response.raise_for_status()
            return response.json() or {{}}
        except requests.exceptions.RequestException as e:
            print(f"Error fetching aggregated history: {e}")
            return {{}}

# Example Usage helper
if __name__ == "__main__":
    # Replace with a valid User ID from your Watch App logs
    TEST_USER_ID = "replace_with_actual_user_id" 
    client = HealthKitClient(user_id=TEST_USER_ID)
    
    print("--- Heart Rate (Last 5) ---")
    hr_data = client.get_realtime_metric("heartRate", limit=5)
    print(json.dumps(hr_data, indent=2))
    
    print("\n--- Today's Summary ---")
    summary = client.get_daily_summary()
    print(json.dumps(summary, indent=2))
