#!/usr/bin/env python3
"""
Test YouTube Backend Service
"""

import requests
import json
import time

def test_youtube_search():
    """Test YouTube search endpoint"""
    print("🔍 Testing YouTube search endpoint...")
    
    url = 'http://localhost:8000/youtube/search'
    data = {
        'query': 'Cá hồi nướng với khoai lang và rau củ',
        'max_results': 3,
        'duration': 'medium',
        'order': 'relevance'
    }
    
    try:
        print(f"📡 Making request to: {url}")
        print(f"📦 Request data: {json.dumps(data, indent=2)}")
        
        response = requests.post(url, json=data, timeout=30)
        print(f"📡 Response status: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            videos = result.get('videos', [])
            cached = result.get('cached', False)
            
            print(f"✅ Found {len(videos)} videos")
            print(f"📦 Cached: {cached}")
            
            for i, video in enumerate(videos[:3]):
                title = video.get('title', 'No title')
                duration = video.get('duration', 'N/A')
                views = video.get('views', 'N/A')
                channel = video.get('channel', 'Unknown')
                
                print(f"{i+1}. {title}")
                print(f"   Channel: {channel}")
                print(f"   Duration: {duration} | Views: {views}")
                print()
            
            return True
        else:
            print(f"❌ Error: {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except requests.exceptions.ConnectionError:
        print("❌ Connection error: Backend may not be running")
        print("💡 Start backend with: python main.py")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_youtube_trending():
    """Test YouTube trending endpoint"""
    print("🔥 Testing YouTube trending endpoint...")
    
    url = 'http://localhost:8000/youtube/trending?max_results=5'
    
    try:
        response = requests.get(url, timeout=30)
        print(f"📡 Response status: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            videos = result.get('videos', [])
            cached = result.get('cached', False)
            
            print(f"✅ Found {len(videos)} trending videos")
            print(f"📦 Cached: {cached}")
            
            for i, video in enumerate(videos[:3]):
                title = video.get('title', 'No title')
                duration = video.get('duration', 'N/A')
                views = video.get('views', 'N/A')
                
                print(f"{i+1}. {title}")
                print(f"   Duration: {duration} | Views: {views}")
                print()
            
            return True
        else:
            print(f"❌ Error: {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_cache_stats():
    """Test cache stats endpoint"""
    print("📊 Testing cache stats endpoint...")
    
    url = 'http://localhost:8000/youtube/cache/stats'
    
    try:
        response = requests.get(url, timeout=10)
        print(f"📡 Response status: {response.status_code}")
        
        if response.status_code == 200:
            stats = response.json()
            
            print("✅ Cache Statistics:")
            print(f"   Total entries: {stats.get('total_entries', 0)}")
            print(f"   Valid entries: {stats.get('valid_entries', 0)}")
            print(f"   Expired entries: {stats.get('expired_entries', 0)}")
            print(f"   Cache duration: {stats.get('cache_duration_hours', 0)} hours")
            print(f"   Max cache size: {stats.get('max_cache_size', 0)}")
            
            return True
        else:
            print(f"❌ Error: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_backend_health():
    """Test backend health"""
    print("🏥 Testing backend health...")
    
    url = 'http://localhost:8000/'
    
    try:
        response = requests.get(url, timeout=10)
        print(f"📡 Response status: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Backend is healthy: {result.get('message', 'OK')}")
            return True
        else:
            print(f"❌ Backend health check failed: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Backend not reachable: {e}")
        return False

def main():
    """Run all tests"""
    print("🧪 YouTube Backend Service Tests")
    print("=" * 50)
    
    tests = [
        ("Backend Health", test_backend_health),
        ("YouTube Search", test_youtube_search),
        ("YouTube Trending", test_youtube_trending),
        ("Cache Stats", test_cache_stats),
    ]
    
    results = []
    
    for test_name, test_func in tests:
        print(f"\n🧪 Running: {test_name}")
        print("-" * 30)
        
        start_time = time.time()
        success = test_func()
        end_time = time.time()
        
        duration = end_time - start_time
        results.append((test_name, success, duration))
        
        if success:
            print(f"✅ {test_name} passed ({duration:.2f}s)")
        else:
            print(f"❌ {test_name} failed ({duration:.2f}s)")
    
    # Summary
    print("\n" + "=" * 50)
    print("📊 Test Summary:")
    
    passed = sum(1 for _, success, _ in results if success)
    total = len(results)
    
    for test_name, success, duration in results:
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"   {status} {test_name} ({duration:.2f}s)")
    
    print(f"\n🎯 Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! YouTube backend is working correctly.")
    else:
        print("⚠️  Some tests failed. Check backend configuration.")
        
        if passed == 0:
            print("\n💡 Troubleshooting:")
            print("   1. Make sure backend is running: python main.py")
            print("   2. Check if port 8000 is available")
            print("   3. Verify YouTube API key is configured")

if __name__ == "__main__":
    main()
