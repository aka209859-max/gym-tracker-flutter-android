#!/usr/bin/env python3
"""
Simple Google Places API Proxy - Flask version
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import requests

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

GOOGLE_API_KEY = "AIzaSyA9XmQSHA1llGg7gihqjmOOIaLA856fkLc"
PLACES_API_BASE = "https://maps.googleapis.com/maps/api/place"

@app.route('/')
def health():
    return jsonify({
        "status": "healthy",
        "service": "FitSync Places Proxy",
        "version": "2.0.0"
    })

@app.route('/api/places/textsearch')
def text_search():
    query = request.args.get('query', '')
    search_query = f"{query} ジム"
    
    url = f"{PLACES_API_BASE}/textsearch/json"
    params = {
        "query": search_query,
        "type": "gym",
        "language": "ja",
        "region": "jp",
        "key": GOOGLE_API_KEY
    }
    
    print(f"🔍 Text Search: \"{search_query}\"")
    # UTF-8エンコーディングを明示的に指定
    response = requests.get(url, params=params, headers={'Accept-Charset': 'utf-8'})
    response.encoding = 'utf-8'
    data = response.json()
    print(f"   Status: {data.get('status')}, Results: {len(data.get('results', []))}")
    
    return jsonify(data)

@app.route('/api/places/nearbysearch')
def nearby_search():
    location = request.args.get('location', '')
    radius = request.args.get('radius', 5000)
    
    url = f"{PLACES_API_BASE}/nearbysearch/json"
    params = {
        "location": location,
        "radius": radius,
        "type": "gym",
        "keyword": "フィットネス|トレーニング|ジム|スポーツクラブ",
        "language": "ja",
        "key": GOOGLE_API_KEY
    }
    
    print(f"🔍 Nearby Search: {location}, radius={radius}m")
    response = requests.get(url, params=params)
    data = response.json()
    print(f"   Status: {data.get('status')}, Results: {len(data.get('results', []))}")
    
    return jsonify(data)

if __name__ == '__main__':
    print("🚀 Simple Proxy Server Starting on port 8080...")
    app.run(host='0.0.0.0', port=8080, debug=False)
