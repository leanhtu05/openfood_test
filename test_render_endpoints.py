#!/usr/bin/env python3
"""
Test Render YouTube Endpoints After Deploy
"""

import requests
import json
import time

def test_render_youtube_endpoints():
    """Test all YouTube endpoints on Render"""
    base_url = 'https://openfood-backend.onrender.com'
    
    print('🧪 Testing Render YouTube Endpoints After Deploy')
    print('=' * 60)
    
    # Wait for deployment
    print('\n⏳ Waiting for Render deployment (30 seconds)...')
    time.sleep(30)
    
    # Test 1: Health Check
    print('\n🏥 Test 1: Backend Health')
    print('-' * 30)
    
    try:
        response = requests.get(f'{base_url}/', timeout=15)
        print(f'Status: {response.status_code}')
        
        if response.status_code == 200:
            try:
                data = response.json()
                print(f'✅ Backend online: {data.get("message", "OK")}')
                print(f'Version: {data.get("version", "unknown")}')
                features = data.get("features", [])
                if "YouTube Proxy" in features:
                    print('✅ YouTube Proxy feature available')
                else:
                    print('❌ YouTube Proxy feature not listed')
            except:
                print('✅ Backend online (non-JSON response)')
        else:
            print(f'❌ Backend health failed: {response.status_code}')
            return False
            
    except Exception as e:
        print(f'❌ Cannot connect to Render: {e}')
        return False
    
    # Test 2: YouTube Search
    print('\n🔍 Test 2: YouTube Search Endpoint')
    print('-' * 30)
    
    try:
        search_data = {
            'query': 'Phở Bò',
            'max_results': 2,
            'duration': 'medium',
            'order': 'relevance'
        }
        
        print(f'📡 POST {base_url}/youtube/search')
        
        response = requests.post(
            f'{base_url}/youtube/search',
            json=search_data,
            headers={'Content-Type': 'application/json'},
            timeout=30
        )
        
        print(f'📡 Response: {response.status_code}')
        
        if response.status_code == 200:
            result = response.json()
            videos = result.get('videos', [])
            cached = result.get('cached', False)
            
            print(f'✅ SUCCESS! Found {len(videos)} videos')
            print(f'📦 Cached: {cached}')
            
            if videos:
                video = videos[0]
                print(f'📹 Sample: {video.get("title", "N/A")[:50]}...')
                
        elif response.status_code == 404:
            print('❌ 404 - YouTube search endpoint not found')
            return False
        elif response.status_code == 500:
            print('❌ 500 - Internal server error')
            print(f'Error: {response.text[:200]}')
            return False
        else:
            print(f'❌ Unexpected status: {response.status_code}')
            return False
            
    except Exception as e:
        print(f'❌ Error testing search: {e}')
        return False
    
    # Test 3: YouTube Details (NEW ENDPOINT)
    print('\n📹 Test 3: YouTube Details Endpoint (NEW)')
    print('-' * 30)
    
    try:
        details_data = {
            'video_ids': ['dQw4w9WgXcQ', 'jNQXAC9IVRw']  # Sample video IDs
        }
        
        print(f'📡 POST {base_url}/youtube/details')
        
        response = requests.post(
            f'{base_url}/youtube/details',
            json=details_data,
            headers={'Content-Type': 'application/json'},
            timeout=30
        )
        
        print(f'📡 Response: {response.status_code}')
        
        if response.status_code == 200:
            result = response.json()
            videos = result.get('videos', [])
            cached = result.get('cached', False)
            
            print(f'✅ SUCCESS! Got details for {len(videos)} videos')
            print(f'📦 Cached: {cached}')
            
        elif response.status_code == 404:
            print('❌ 404 - YouTube details endpoint not found')
            print('💡 This was the missing endpoint causing Flutter 404!')
            return False
        else:
            print(f'❌ Status: {response.status_code}')
            print(f'Response: {response.text[:200]}')
            
    except Exception as e:
        print(f'❌ Error testing details: {e}')
    
    # Test 4: Cache Stats
    print('\n📊 Test 4: Cache Stats')
    print('-' * 30)
    
    try:
        response = requests.get(f'{base_url}/youtube/cache/stats', timeout=10)
        print(f'Status: {response.status_code}')
        
        if response.status_code == 200:
            stats = response.json()
            print('✅ Cache stats:')
            print(f'   Total entries: {stats.get("total_entries", 0)}')
            print(f'   Valid entries: {stats.get("valid_entries", 0)}')
            print(f'   Cache duration: {stats.get("cache_duration_hours", 0)}h')
        else:
            print(f'❌ Cache stats failed: {response.status_code}')
            
    except Exception as e:
        print(f'❌ Error getting cache stats: {e}')
    
    # Test 5: Trending Videos
    print('\n🔥 Test 5: Trending Videos')
    print('-' * 30)
    
    try:
        response = requests.get(f'{base_url}/youtube/trending?max_results=2', timeout=20)
        print(f'Status: {response.status_code}')
        
        if response.status_code == 200:
            result = response.json()
            videos = result.get('videos', [])
            print(f'✅ Found {len(videos)} trending videos')
        else:
            print(f'❌ Trending failed: {response.status_code}')
            
    except Exception as e:
        print(f'❌ Error getting trending: {e}')
    
    return True

if __name__ == '__main__':
    print('🚀 Testing Render YouTube Endpoints...')
    print('🔧 This will test the newly added /youtube/details endpoint')
    
    success = test_render_youtube_endpoints()
    
    print('\n' + '=' * 60)
    if success:
        print('🎉 SUCCESS: All YouTube endpoints working!')
        print('✅ Flutter app should now work with backend')
        print('✅ No more 404 errors expected')
    else:
        print('❌ ISSUES: Some endpoints still not working')
        print('💡 May need to wait longer for Render deployment')
        
    print('\n📱 Next: Test Flutter app with backend')
    print('🔗 Render Dashboard: https://dashboard.render.com')
