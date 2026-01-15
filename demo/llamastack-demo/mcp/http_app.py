"""
Weather Data MCP Server
A generic Model Context Protocol server for querying weather data from MongoDB.

This server demonstrates how to:
1. Connect LLMs to real databases via MCP
2. Expose data as tools that AI agents can use
3. Handle various query patterns (search, list, statistics)

Author: Danny Yeo
"""

from typing import Any, List, Dict, Optional
import asyncio
from datetime import datetime, timedelta
from mcp.server.fastmcp import FastMCP
from mcp.server.transport_security import TransportSecuritySettings
from motor.motor_asyncio import AsyncIOMotorClient
import json
import os

# Server configuration from environment
SERVER_NAME = os.getenv("MCP_SERVER_NAME", "weather-data")
MONGODB_URL = os.getenv("MONGODB_URL", "mongodb://mongodb:27017")
DATABASE_NAME = os.getenv("DATABASE_NAME", "weather")
COLLECTION_NAME = os.getenv("COLLECTION_NAME", "observations")

# Disable DNS rebinding protection for Kubernetes deployments
# This is required when the server receives requests with K8s service hostnames
transport_security = TransportSecuritySettings(
    enable_dns_rebinding_protection=False
)

# Initialize FastMCP server
mcp = FastMCP(SERVER_NAME, transport_security=transport_security)

# Global MongoDB client
client = None
db = None


async def get_mongodb_client():
    """Get MongoDB client connection."""
    global client, db
    if client is None:
        client = AsyncIOMotorClient(MONGODB_URL)
        db = client[DATABASE_NAME]
    return client, db


def format_weather_observation(doc: Dict) -> str:
    """Format a weather observation into a readable string."""
    station = doc.get('station', doc.get('stationICAO', 'Unknown'))
    station_name = doc.get('station_name', doc.get('stationIATA', ''))
    timestamp = doc.get('timestamp', doc.get('observed_at', 'Unknown'))
    
    result = f"📍 Station: {station}"
    if station_name:
        result += f" ({station_name})"
    result += f"\n🕐 Observed: {timestamp}\n"
    
    # Handle various data formats - flat structure
    result += format_conditions(doc)
    
    return result


def format_conditions(obs: Dict) -> str:
    """Format weather conditions from observation data."""
    result = "\n🌡️ Conditions:\n"
    
    # Temperature
    temp = obs.get('temperature', obs.get('airTemperature', obs.get('temp')))
    if temp is not None:
        result += f"   Temperature: {temp}°C\n"
    
    # Humidity/Dewpoint
    dewpoint = obs.get('dewpoint', obs.get('dewpointTemperature', obs.get('dew_point')))
    if dewpoint is not None:
        result += f"   Dewpoint: {dewpoint}°C\n"
    
    humidity = obs.get('humidity', obs.get('relative_humidity'))
    if humidity is not None:
        result += f"   Humidity: {humidity}%\n"
    
    # Wind
    wind_speed = obs.get('wind_speed', obs.get('windSpeed'))
    wind_dir = obs.get('wind_direction', obs.get('windDirection'))
    if wind_speed is not None:
        wind_str = f"   Wind: {wind_speed}"
        if wind_dir is not None:
            wind_str += f" from {wind_dir}°"
        result += wind_str + "\n"
    
    # Visibility
    visibility = obs.get('visibility', obs.get('horizontalVisibility'))
    if visibility is not None:
        result += f"   Visibility: {visibility}m\n"
    
    # Pressure
    pressure = obs.get('pressure', obs.get('observedQNH', obs.get('sea_level_pressure')))
    if pressure is not None:
        result += f"   Pressure: {pressure} hPa\n"
    
    # Clouds
    clouds = obs.get('clouds', obs.get('cloudLayers', obs.get('cloud_cover')))
    if clouds:
        if isinstance(clouds, list):
            result += f"   Clouds: {', '.join(str(c) for c in clouds)}\n"
        else:
            result += f"   Clouds: {clouds}\n"
    
    # Weather conditions
    conditions = obs.get('conditions', obs.get('weatherConditions', obs.get('weather')))
    if conditions:
        result += f"   Weather: {conditions}\n"
    
    return result


@mcp.tool()
async def search_weather(
    station: str = None,
    location: str = None,
    min_temperature: float = None,
    max_temperature: float = None,
    min_visibility: int = None,
    max_visibility: int = None,
    conditions: str = None,
    hours_back: int = None,
    limit: int = 10
) -> str:
    """Search for weather observations with optional filters.

    Args:
        station: Station code (ICAO or local identifier)
        location: Location name or region to search
        min_temperature: Minimum temperature in Celsius
        max_temperature: Maximum temperature in Celsius
        min_visibility: Minimum visibility in meters
        max_visibility: Maximum visibility in meters
        conditions: Weather conditions to search for (e.g., 'rain', 'fog', 'clear')
        hours_back: Only include observations from the last N hours
        limit: Maximum results to return (default: 10, max: 50)
    
    Returns:
        Formatted weather observations matching the search criteria
    """
    try:
        _, db = await get_mongodb_client()
        
        # Build the query
        query = {}
        
        # Station filter - check multiple possible field names
        if station:
            station_upper = station.upper()
            query["$or"] = [
                {"station": station_upper},
                {"stationICAO": station_upper},
                {"station_id": station_upper}
            ]
        
        # Location filter - search in location-related fields
        if location:
            query["$or"] = query.get("$or", []) + [
                {"location": {"$regex": location, "$options": "i"}},
                {"station_name": {"$regex": location, "$options": "i"}},
                {"city": {"$regex": location, "$options": "i"}},
                {"region": {"$regex": location, "$options": "i"}}
            ]
        
        # Time filter
        if hours_back:
            time_threshold = datetime.utcnow() - timedelta(hours=hours_back)
            query["$or"] = [
                {"timestamp": {"$gte": time_threshold}},
                {"observed_at": {"$gte": time_threshold}}
            ]
        
        # Temperature filters
        if min_temperature is not None:
            query["$or"] = query.get("$or", []) + [
                {"temperature": {"$gte": min_temperature}}
            ]
        
        if max_temperature is not None:
            query["$or"] = query.get("$or", []) + [
                {"temperature": {"$lte": max_temperature}}
            ]
        
        # Visibility filters
        if min_visibility is not None:
            query["$or"] = query.get("$or", []) + [
                {"visibility": {"$gte": min_visibility}}
            ]
        
        # Conditions filter
        if conditions:
            query["$or"] = query.get("$or", []) + [
                {"conditions": {"$regex": conditions, "$options": "i"}},
                {"weather": {"$regex": conditions, "$options": "i"}}
            ]
        
        # Limit results
        limit = min(limit, 50)
        
        # Execute the query
        cursor = db[COLLECTION_NAME].find(query).sort([("timestamp", -1), ("observed_at", -1)]).limit(limit)
        results = await cursor.to_list(length=limit)
        
        if not results:
            filters_desc = []
            if station: filters_desc.append(f"station={station}")
            if location: filters_desc.append(f"location={location}")
            if min_temperature: filters_desc.append(f"temp≥{min_temperature}°C")
            if max_temperature: filters_desc.append(f"temp≤{max_temperature}°C")
            if conditions: filters_desc.append(f"conditions={conditions}")
            if hours_back: filters_desc.append(f"last {hours_back}h")
            
            return f"❌ No weather data found" + (f" with filters: {', '.join(filters_desc)}" if filters_desc else "")
        
        # Format results
        result = f"🔍 Weather Search Results ({len(results)} observations found)\n"
        result += "=" * 60 + "\n\n"
        
        for i, doc in enumerate(results, 1):
            result += f"--- Result {i} ---\n"
            result += format_weather_observation(doc)
            result += "\n"
        
        return result
        
    except Exception as e:
        return f"❌ Error executing search: {str(e)}"


@mcp.tool()
async def get_current_weather(station: str) -> str:
    """Get the most recent weather observation for a specific station.

    Args:
        station: Station code (ICAO code like 'VIDP' or local identifier)
    
    Returns:
        Current weather conditions at the station
    """
    try:
        _, db = await get_mongodb_client()
        
        station_upper = station.upper()
        
        # Find the most recent observation for this station
        query = {"$or": [
            {"station": station_upper},
            {"stationICAO": station_upper},
            {"station_id": station_upper}
        ]}
        
        doc = await db[COLLECTION_NAME].find_one(
            query, 
            sort=[("timestamp", -1), ("observed_at", -1)]
        )
        
        if not doc:
            return f"❌ No weather data found for station: {station}"
        
        result = f"🌤️ Current Weather at {station.upper()}\n"
        result += "=" * 40 + "\n\n"
        result += format_weather_observation(doc)
        
        return result
        
    except Exception as e:
        return f"❌ Error retrieving weather: {str(e)}"


@mcp.tool()
async def list_stations() -> str:
    """List all available weather stations.

    Returns:
        List of all station codes available in the database
    """
    try:
        _, db = await get_mongodb_client()
        
        # Try different field names for station codes
        stations = set()
        
        for field in ["station", "stationICAO", "station_id"]:
            codes = await db[COLLECTION_NAME].distinct(field)
            stations.update(code for code in codes if code)
        
        stations = sorted(stations)
        total_count = await db[COLLECTION_NAME].count_documents({})
        
        result = f"📡 Available Weather Stations\n"
        result += "=" * 40 + "\n\n"
        result += f"Total Observations: {total_count:,}\n"
        result += f"Unique Stations: {len(stations)}\n\n"
        
        result += "Station Codes:\n"
        for i, code in enumerate(stations, 1):
            result += f"  {i:3d}. {code}\n"
        
        return result
        
    except Exception as e:
        return f"❌ Error listing stations: {str(e)}"


@mcp.tool()
async def get_statistics() -> str:
    """Get statistics about the weather database.

    Returns:
        Database statistics including counts, date ranges, and coverage
    """
    try:
        _, db = await get_mongodb_client()
        
        # Get counts
        total_docs = await db[COLLECTION_NAME].count_documents({})
        
        # Get unique stations
        stations = set()
        for field in ["station", "stationICAO", "station_id"]:
            codes = await db[COLLECTION_NAME].distinct(field)
            stations.update(code for code in codes if code)
        
        # Get date range
        earliest = await db[COLLECTION_NAME].find_one(
            {}, 
            sort=[("timestamp", 1), ("observed_at", 1)]
        )
        latest = await db[COLLECTION_NAME].find_one(
            {}, 
            sort=[("timestamp", -1), ("observed_at", -1)]
        )
        
        result = f"📊 Weather Database Statistics\n"
        result += "=" * 40 + "\n\n"
        
        result += f"📈 Counts:\n"
        result += f"   Total Observations: {total_docs:,}\n"
        result += f"   Unique Stations: {len(stations)}\n\n"
        
        result += f"📅 Data Range:\n"
        if earliest:
            earliest_time = earliest.get('timestamp', earliest.get('observed_at', 'Unknown'))
            result += f"   Earliest: {earliest_time}\n"
        if latest:
            latest_time = latest.get('timestamp', latest.get('observed_at', 'Unknown'))
            result += f"   Latest: {latest_time}\n"
        
        result += f"\n💾 Database:\n"
        result += f"   Name: {DATABASE_NAME}\n"
        result += f"   Collection: {COLLECTION_NAME}\n"
        
        return result
        
    except Exception as e:
        return f"❌ Error retrieving statistics: {str(e)}"


@mcp.tool()
async def health_check() -> str:
    """Check if the MCP server and database connection are healthy.

    Returns:
        Health status of the server
    """
    try:
        _, db = await get_mongodb_client()
        
        # Test database connection
        await db.command('ping')
        count = await db[COLLECTION_NAME].count_documents({})
        
        return f"✅ Healthy - Database connected, {count:,} documents available"
        
    except Exception as e:
        return f"❌ Unhealthy - {str(e)}"


if __name__ == "__main__":
    import uvicorn
    
    print(f"""
╔══════════════════════════════════════════════════════════════╗
║           Weather Data MCP Server                            ║
╠══════════════════════════════════════════════════════════════╣
║  Server Name: {SERVER_NAME:<45} ║
║  MongoDB:     {MONGODB_URL:<45} ║
║  Database:    {DATABASE_NAME:<45} ║
║  Collection:  {COLLECTION_NAME:<45} ║
║  DNS Rebinding Protection: Disabled (K8s compatible)        ║
╚══════════════════════════════════════════════════════════════╝
    """)
    
    print("🚀 Starting server on 0.0.0.0:8000...")
    
    # Get the ASGI app from FastMCP and run with uvicorn
    app = mcp.streamable_http_app()
    uvicorn.run(app, host='0.0.0.0', port=8000)
