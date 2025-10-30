#!/usr/bin/env python3
"""
FitSync Google Places API Proxy Server
CORS問題を回避するためのプロキシサーバー
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import httpx
import os

app = FastAPI(title="FitSync Places API Proxy")

# CORS設定（全オリジンを許可）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Google Places API設定
GOOGLE_PLACES_API_KEY = "AIzaSyA9XmQSHA1llGg7gihqjmOOIaLA856fkLc"
PLACES_API_BASE_URL = "https://maps.googleapis.com/maps/api/place"

@app.get("/")
async def root():
    """ヘルスチェック"""
    return {
        "status": "healthy",
        "service": "FitSync Places API Proxy",
        "version": "1.0.0"
    }

@app.get("/api/places/nearbysearch")
async def nearby_search(
    location: str,
    radius: int = 5000,
    type: str = "gym",
    keyword: str = "フィットネス|トレーニング|ジム|スポーツクラブ",
    language: str = "ja"
):
    """
    GPS位置ベースでジムを検索（Nearby Search API）
    
    Parameters:
    - location: 緯度,経度（例: "35.6812,139.7671"）
    - radius: 検索半径（メートル、デフォルト5000）
    - type: 場所タイプ（デフォルト "gym"）
    - keyword: 検索キーワード
    - language: 言語（デフォルト "ja"）
    """
    try:
        url = f"{PLACES_API_BASE_URL}/nearbysearch/json"
        params = {
            "location": location,
            "radius": radius,
            "type": type,
            "keyword": keyword,
            "language": language,
            "key": GOOGLE_PLACES_API_KEY
        }
        
        print(f"🔍 Nearby Search: {location}, radius={radius}m")
        
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(url, params=params)
            data = response.json()
            
            print(f"   Status: {data.get('status')}")
            if data.get('status') == 'OK':
                print(f"   ✅ Found {len(data.get('results', []))} places")
            elif data.get('error_message'):
                print(f"   ⚠️ Error: {data.get('error_message')}")
            
            return data
            
    except Exception as e:
        print(f"❌ Proxy Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/places/textsearch")
async def text_search(
    query: str,
    type: str = "gym",
    language: str = "ja",
    region: str = "jp"
):
    """
    テキストベースでジムを検索（Text Search API）
    
    Parameters:
    - query: 検索クエリ（例: "渋谷 ジム", "福岡県"）
    - type: 場所タイプ（デフォルト "gym"）
    - language: 言語（デフォルト "ja"）
    - region: 地域（デフォルト "jp"）
    """
    try:
        url = f"{PLACES_API_BASE_URL}/textsearch/json"
        # クエリに「ジム」を自動追加
        search_query = f"{query} ジム"
        params = {
            "query": search_query,
            "type": type,
            "language": language,
            "region": region,
            "key": GOOGLE_PLACES_API_KEY
        }
        
        print(f"🔍 Text Search: \"{search_query}\"")
        
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(url, params=params)
            data = response.json()
            
            print(f"   Status: {data.get('status')}")
            if data.get('status') == 'OK':
                print(f"   ✅ Found {len(data.get('results', []))} places")
            elif data.get('status') == 'ZERO_RESULTS':
                print(f"   ℹ️ No results found")
            elif data.get('error_message'):
                print(f"   ⚠️ Error: {data.get('error_message')}")
            
            return data
            
    except Exception as e:
        print(f"❌ Proxy Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/places/details")
async def place_details(
    place_id: str,
    language: str = "ja"
):
    """
    ジムの詳細情報を取得（Place Details API）
    
    Parameters:
    - place_id: Google Places ID
    - language: 言語（デフォルト "ja"）
    """
    try:
        url = f"{PLACES_API_BASE_URL}/details/json"
        params = {
            "place_id": place_id,
            "fields": "name,formatted_address,formatted_phone_number,opening_hours,website,rating,user_ratings_total,photos,price_level",
            "language": language,
            "key": GOOGLE_PLACES_API_KEY
        }
        
        print(f"🔍 Place Details: {place_id}")
        
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(url, params=params)
            data = response.json()
            
            print(f"   Status: {data.get('status')}")
            
            return data
            
    except Exception as e:
        print(f"❌ Proxy Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    print("🚀 FitSync Places API Proxy Server Starting...")
    print("   Listening on http://0.0.0.0:8080")
    print("   API Key configured: ✅")
    uvicorn.run(app, host="0.0.0.0", port=8080, log_level="info")
