"""
Sample Weather Data Generator
Creates realistic weather observations for demo purposes.

Usage:
  python sample_data.py              # Generates JSON file
  python sample_data.py --insert     # Inserts directly into MongoDB
"""

import json
import random
from datetime import datetime, timedelta
from typing import List, Dict

# Weather stations around the world
STATIONS = [
    # India
    {"station": "VIDP", "name": "Delhi - Indira Gandhi International", "city": "New Delhi", "country": "India", "lat": 28.5665, "lon": 77.1031},
    {"station": "VABB", "name": "Mumbai - Chhatrapati Shivaji", "city": "Mumbai", "country": "India", "lat": 19.0896, "lon": 72.8656},
    {"station": "VOBL", "name": "Bangalore - Kempegowda International", "city": "Bangalore", "country": "India", "lat": 13.1986, "lon": 77.7066},
    {"station": "VOMM", "name": "Chennai International", "city": "Chennai", "country": "India", "lat": 12.9941, "lon": 80.1709},
    {"station": "VECC", "name": "Kolkata - Netaji Subhas Chandra Bose", "city": "Kolkata", "country": "India", "lat": 22.6547, "lon": 88.4467},
    
    # Asia Pacific
    {"station": "WSSS", "name": "Singapore Changi", "city": "Singapore", "country": "Singapore", "lat": 1.3644, "lon": 103.9915},
    {"station": "VHHH", "name": "Hong Kong International", "city": "Hong Kong", "country": "China", "lat": 22.3080, "lon": 113.9185},
    {"station": "RJTT", "name": "Tokyo Haneda", "city": "Tokyo", "country": "Japan", "lat": 35.5494, "lon": 139.7798},
    {"station": "YSSY", "name": "Sydney Kingsford Smith", "city": "Sydney", "country": "Australia", "lat": -33.9399, "lon": 151.1753},
    
    # Europe
    {"station": "EGLL", "name": "London Heathrow", "city": "London", "country": "United Kingdom", "lat": 51.4700, "lon": -0.4543},
    {"station": "LFPG", "name": "Paris Charles de Gaulle", "city": "Paris", "country": "France", "lat": 49.0097, "lon": 2.5479},
    {"station": "EDDF", "name": "Frankfurt am Main", "city": "Frankfurt", "country": "Germany", "lat": 50.0379, "lon": 8.5622},
    
    # Americas
    {"station": "KJFK", "name": "New York JFK", "city": "New York", "country": "USA", "lat": 40.6413, "lon": -73.7781},
    {"station": "KLAX", "name": "Los Angeles International", "city": "Los Angeles", "country": "USA", "lat": 33.9416, "lon": -118.4085},
    {"station": "CYYZ", "name": "Toronto Pearson", "city": "Toronto", "country": "Canada", "lat": 43.6777, "lon": -79.6248},
    
    # Middle East
    {"station": "OMDB", "name": "Dubai International", "city": "Dubai", "country": "UAE", "lat": 25.2532, "lon": 55.3657},
]

# Weather conditions
CONDITIONS = [
    {"code": "Clear", "description": "Clear skies", "weight": 30},
    {"code": "Partly Cloudy", "description": "Partly cloudy", "weight": 25},
    {"code": "Cloudy", "description": "Overcast", "weight": 15},
    {"code": "Light Rain", "description": "Light rain showers", "weight": 10},
    {"code": "Rain", "description": "Moderate rain", "weight": 5},
    {"code": "Heavy Rain", "description": "Heavy rain", "weight": 3},
    {"code": "Fog", "description": "Foggy conditions", "weight": 5},
    {"code": "Haze", "description": "Hazy", "weight": 7},
    {"code": "Thunderstorm", "description": "Thunderstorm activity", "weight": 2},
    {"code": "Snow", "description": "Snowfall", "weight": 3},
]


def get_random_condition() -> Dict:
    """Select a random weather condition based on weights."""
    total_weight = sum(c["weight"] for c in CONDITIONS)
    r = random.uniform(0, total_weight)
    cumulative = 0
    for condition in CONDITIONS:
        cumulative += condition["weight"]
        if r <= cumulative:
            return condition
    return CONDITIONS[0]


def get_seasonal_temp_range(lat: float, month: int) -> tuple:
    """Get temperature range based on latitude and month."""
    # Northern hemisphere: hot in Jun-Aug, cold in Dec-Feb
    # Southern hemisphere: opposite
    
    is_northern = lat > 0
    
    # Summer months (June-Aug for north, Dec-Feb for south)
    summer_months = [6, 7, 8] if is_northern else [12, 1, 2]
    winter_months = [12, 1, 2] if is_northern else [6, 7, 8]
    
    # Base temperature by latitude (tropical vs temperate)
    if abs(lat) < 25:  # Tropical
        base_temp = 28
        seasonal_variation = 5
    elif abs(lat) < 45:  # Subtropical/Temperate
        base_temp = 20
        seasonal_variation = 15
    else:  # Cold regions
        base_temp = 10
        seasonal_variation = 25
    
    if month in summer_months:
        min_temp = base_temp + seasonal_variation - 5
        max_temp = base_temp + seasonal_variation + 10
    elif month in winter_months:
        min_temp = base_temp - seasonal_variation - 5
        max_temp = base_temp - seasonal_variation + 10
    else:  # Spring/Fall
        min_temp = base_temp - 5
        max_temp = base_temp + 10
    
    return (min_temp, max_temp)


def generate_observation(station: Dict, timestamp: datetime) -> Dict:
    """Generate a single weather observation."""
    
    condition = get_random_condition()
    temp_range = get_seasonal_temp_range(station["lat"], timestamp.month)
    
    temperature = round(random.uniform(*temp_range), 1)
    
    # Humidity based on conditions
    if condition["code"] in ["Rain", "Heavy Rain", "Light Rain", "Thunderstorm"]:
        humidity = random.randint(70, 95)
    elif condition["code"] in ["Fog"]:
        humidity = random.randint(90, 100)
    elif condition["code"] in ["Clear"]:
        humidity = random.randint(30, 60)
    else:
        humidity = random.randint(40, 75)
    
    # Visibility based on conditions
    if condition["code"] == "Clear":
        visibility = random.randint(10000, 20000)
    elif condition["code"] in ["Partly Cloudy", "Cloudy"]:
        visibility = random.randint(8000, 15000)
    elif condition["code"] in ["Light Rain", "Haze"]:
        visibility = random.randint(4000, 8000)
    elif condition["code"] in ["Rain", "Heavy Rain"]:
        visibility = random.randint(1000, 4000)
    elif condition["code"] == "Fog":
        visibility = random.randint(100, 1000)
    elif condition["code"] == "Thunderstorm":
        visibility = random.randint(500, 3000)
    else:
        visibility = random.randint(5000, 10000)
    
    # Wind
    wind_speed = random.randint(0, 25)
    wind_direction = random.choice([0, 45, 90, 135, 180, 225, 270, 315])
    
    if condition["code"] == "Thunderstorm":
        wind_speed = random.randint(15, 40)
    
    # Pressure (normal range with some variation)
    pressure = round(random.uniform(1005, 1025), 1)
    
    # Dewpoint (related to temperature and humidity)
    dewpoint = round(temperature - ((100 - humidity) / 5), 1)
    
    return {
        "station": station["station"],
        "station_name": station["name"],
        "city": station["city"],
        "country": station["country"],
        "location": {
            "lat": station["lat"],
            "lon": station["lon"]
        },
        "timestamp": timestamp.isoformat() + "Z",
        "observed_at": timestamp,
        "temperature": temperature,
        "dewpoint": dewpoint,
        "humidity": humidity,
        "wind_speed": wind_speed,
        "wind_direction": wind_direction,
        "wind_description": f"{wind_speed} m/s from {wind_direction}°",
        "visibility": visibility,
        "pressure": pressure,
        "conditions": condition["code"],
        "conditions_description": condition["description"],
        "source": "demo-data-generator"
    }


def generate_sample_data(hours_back: int = 48, interval_minutes: int = 60) -> List[Dict]:
    """Generate sample weather data for all stations."""
    
    observations = []
    now = datetime.utcnow()
    
    for station in STATIONS:
        current_time = now
        for _ in range(hours_back * 60 // interval_minutes):
            obs = generate_observation(station, current_time)
            observations.append(obs)
            current_time -= timedelta(minutes=interval_minutes)
    
    # Sort by timestamp descending
    observations.sort(key=lambda x: x["timestamp"], reverse=True)
    
    return observations


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="Generate sample weather data")
    parser.add_argument("--insert", action="store_true", help="Insert directly into MongoDB")
    parser.add_argument("--mongodb-url", default="mongodb://localhost:27017", help="MongoDB URL")
    parser.add_argument("--database", default="weather", help="Database name")
    parser.add_argument("--collection", default="observations", help="Collection name")
    parser.add_argument("--hours", type=int, default=48, help="Hours of data to generate")
    parser.add_argument("--output", default="sample_weather_data.json", help="Output JSON file")
    
    args = parser.parse_args()
    
    print(f"🌤️  Generating weather data for {len(STATIONS)} stations over {args.hours} hours...")
    data = generate_sample_data(hours_back=args.hours)
    print(f"✅ Generated {len(data)} observations")
    
    if args.insert:
        from pymongo import MongoClient
        
        print(f"📡 Connecting to MongoDB: {args.mongodb_url}")
        client = MongoClient(args.mongodb_url)
        db = client[args.database]
        collection = db[args.collection]
        
        # Clear existing data
        deleted = collection.delete_many({})
        print(f"🗑️  Deleted {deleted.deleted_count} existing documents")
        
        # Insert new data
        result = collection.insert_many(data)
        print(f"✅ Inserted {len(result.inserted_ids)} documents")
        
        # Create indexes
        collection.create_index("station")
        collection.create_index("timestamp")
        collection.create_index("city")
        collection.create_index("country")
        collection.create_index("conditions")
        print("📇 Created indexes")
        
        print(f"\n🎉 Done! Data available in {args.database}.{args.collection}")
        
    else:
        # Convert datetime objects to strings for JSON serialization
        for obs in data:
            if "observed_at" in obs:
                del obs["observed_at"]  # Remove datetime object, keep ISO string
        
        with open(args.output, "w") as f:
            json.dump(data, f, indent=2, default=str)
        print(f"💾 Saved to {args.output}")
        print(f"\nTo insert into MongoDB, run:")
        print(f"  python sample_data.py --insert --mongodb-url {args.mongodb_url}")


if __name__ == "__main__":
    main()

