#!/usr/bin/env python3
"""
Test Render Backend Direct
"""

import requests
import json
import time

def test_render_endpoints():
    """Test Render backend endpoints"""
    base_url = 'https://openfood-backend.onrender.com'
    
    print('🧪 Testing Render Backend Endpoints')
    print('=' * 50)
    
    # Test 1: Health Check
    print('\n🏥 Test 1: Health Check')
    print('-' * 30)
    
    try:
        response = requests.get(f'{base_url}/', timeout=10)
        print(f'Status: {response.status_code}')
        if response.status_code == 200:
            data = response.json()
            print(f'✅ Backend healthy: {data.get("message", "OK")}')
        else:
            print(f'❌ Health check failed: {response.status_code}')
            print(f'Response: {response.text}')
            return False
    except Exception as e:
        print(f'❌ Cannot connect to Render: {e}')
        return False
    
    # Test 2: Check available endpoints
    print('\n📋 Test 2: Available Endpoints')
    print('-' * 30)
    
    try:
        response = requests.get(f'{base_url}/docs', timeout=10)
        print(f'Docs status: {response.status_code}')
        if response.status_code == 200:
            print('✅ API docs available at /docs')
        
        # Try OpenAPI JSON
        response = requests.get(f'{base_url}/openapi.json', timeout=10)
        if response.status_code == 200:
            openapi_data = response.json()
            paths = openapi_data.get('paths', {})
            
            print('📋 Available endpoints:')
            for path in sorted(paths.keys()):
                methods = list(paths[path].keys())
                print(f'   {path} [{", ".join(methods).upper()}]')
                
            # Check if YouTube endpoints exist
            youtube_endpoints = [path for path in paths.keys() if 'youtube' in path]
            if youtube_endpoints:
                print(f'✅ Found YouTube endpoints: {youtube_endpoints}')
            else:
                print('❌ No YouTube endpoints found')
                
    except Exception as e:
        print(f'❌ Error checking endpoints: {e}')
    
    # Test 3: Direct YouTube endpoint test
    print('\n🎬 Test 3: YouTube Search Endpoint')
    print('-' * 30)
    
    try:
        search_data = {
            'query': 'Phở Bò',
            'max_results': 3,
            'duration': 'medium',
            'order': 'relevance'
        }
        
        print(f'📡 POST {base_url}/youtube/search')
        print(f'📦 Data: {json.dumps(search_data)}')
        
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
            
            print(f'✅ Success! Found {len(videos)} videos')
            print(f'📦 Cached: {cached}')
            
            if videos:
                video = videos[0]
                print(f'📹 Sample video:')
                print(f'   Title: {video.get("title", "N/A")}')
                print(f'   Channel: {video.get("channel", "N/A")}')
                print(f'   Duration: {video.get("duration", "N/A")}')
                print(f'   Views: {video.get("views", "N/A")}')
                
            return True
            
        elif response.status_code == 404:
            print('❌ 404 Not Found - YouTube router not deployed')
            print('💡 Possible causes:')
            print('   1. YouTube router not included in main.py')
            print('   2. Backend not redeployed after adding router')
            print('   3. Import error in youtube_router.py')
            
        elif response.status_code == 500:
            print('❌ 500 Internal Server Error')
            print(f'Response: {response.text}')
            print('💡 Possible causes:')
            print('   1. YOUTUBE_API_KEY not set in Render environment')
            print('   2. Missing dependencies (httpx, etc.)')
            print('   3. Code error in youtube_router.py')
            
        else:
            print(f'❌ Unexpected status: {response.status_code}')
            print(f'Response: {response.text}')
            
    except Exception as e:
        print(f'❌ Error testing YouTube endpoint: {e}')
    
    # Test 4: Cache stats
    print('\n📊 Test 4: Cache Stats')
    print('-' * 30)
    
    try:
        response = requests.get(f'{base_url}/youtube/cache/stats', timeout=10)
        print(f'Status: {response.status_code}')
        
        if response.status_code == 200:
            stats = response.json()
            print('✅ Cache stats:')
            for key, value in stats.items():
                print(f'   {key}: {value}')
        elif response.status_code == 404:
            print('❌ Cache stats endpoint not found')
        else:
            print(f'❌ Cache stats failed: {response.status_code}')
            
    except Exception as e:
        print(f'❌ Error getting cache stats: {e}')
    
    return False

if __name__ == '__main__':
    success = test_render_endpoints()
    
    print('\n' + '=' * 50)
    if success:
        print('🎉 Render backend YouTube integration working!')
    else:
        print('❌ Render backend YouTube integration needs fixing')
        print('\n💡 Next steps:')
        print('1. Check Render deployment logs')
        print('2. Verify YOUTUBE_API_KEY environment variable')
        print('3. Ensure all dependencies are installed')
        print('4. Check for import errors in logs')
