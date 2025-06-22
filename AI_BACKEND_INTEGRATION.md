# AI Price Analysis - Backend Integration

## Tổng quan

Đã chuyển toàn bộ logic AI Price Analysis từ Flutter frontend sang FastAPI backend để:
- ✅ Tận dụng sức mạnh xử lý của server
- ✅ Tích hợp dễ dàng với Groq/OpenAI APIs
- ✅ Caching và optimization tốt hơn
- ✅ Bảo mật API keys
- ✅ Scalability cao hơn

## Backend Architecture

### 1. Models (models.py)
```python
# Request Models
- PriceTrendAnalysisRequest
- PricePredictionRequest
- GroceryOptimizationRequest
- SeasonalAnalysisRequest
- MarketInsightsRequest

# Response Models
- PriceTrendAnalysisResponse
- PricePredictionResponse
- GroceryOptimizationResponse
- SeasonalAnalysisResponse
- MarketInsightsResponse
```

### 2. Service (services/ai_price_analysis_service.py)
```python
class AIPriceAnalysisService:
    - analyze_price_trends()
    - predict_future_prices()
    - analyze_seasonal_trends()
    - optimize_grocery_list()
    - generate_market_insights()
```

### 3. Router (routers/ai_price_router.py)
```python
# Endpoints
POST /ai-price/analyze-trends
POST /ai-price/predict-price
POST /ai-price/analyze-seasonal
POST /ai-price/optimize-grocery
POST /ai-price/market-insights

# GET alternatives
GET /ai-price/analyze-trends?category=...&days_back=30
GET /ai-price/predict-price?food_name=...&days_ahead=7
GET /ai-price/analyze-seasonal?category=...
GET /ai-price/market-insights?region=...

# Health check
GET /ai-price/health
```

## Frontend Changes

### 1. Service Update (lib/services/price_ai_analysis_service.dart)
```dart
class PriceAIAnalysisService {
  static const String baseUrl = 'http://localhost:8000';
  
  // Chỉ gọi HTTP requests đến backend
  Future<Map<String, dynamic>> analyzePriceTrends({...}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ai-price/analyze-trends'),
      headers: _headers,
      body: jsonEncode(requestBody),
    );
    return jsonDecode(response.body);
  }
  
  // Fallback methods khi backend offline
  Map<String, dynamic> _getFallbackTrendAnalysis() {...}
}
```

### 2. Connection Testing
```dart
Future<bool> testConnection() async {
  final response = await http.get(
    Uri.parse('$baseUrl/ai-price/health'),
  );
  return response.statusCode == 200;
}
```

## API Endpoints

### 1. Analyze Price Trends
```http
POST /ai-price/analyze-trends
Content-Type: application/json

{
  "category": "🥬 Rau củ quả",
  "days_back": 30
}
```

**Response:**
```json
{
  "analysis_date": "2024-01-15T10:30:00Z",
  "category": "🥬 Rau củ quả",
  "period_days": 30,
  "trend": "stable",
  "insights": [
    {
      "title": "Xu hướng ổn định",
      "description": "Giá rau củ quả duy trì ổn định...",
      "confidence": 0.85,
      "category": "trend"
    }
  ],
  "recommendations": ["Mua rau củ trong tuần này"],
  "price_alerts": []
}
```

### 2. Predict Future Prices
```http
POST /ai-price/predict-price
Content-Type: application/json

{
  "food_name": "thịt bò",
  "days_ahead": 7
}
```

**Response:**
```json
{
  "food_name": "thịt bò",
  "current_price": 350000,
  "predicted_price": 360000,
  "prediction_days": 7,
  "confidence": 78,
  "trend": "increasing",
  "factors": ["Nhu cầu cao", "Cung cấp hạn chế"],
  "recommendation": "Nên mua ngay trước khi giá tăng",
  "price_range": {"min": 340000, "max": 380000},
  "generated_at": "2024-01-15T10:30:00Z"
}
```

### 3. Optimize Grocery List
```http
POST /ai-price/optimize-grocery
Content-Type: application/json

{
  "grocery_items": [
    {
      "name": "thịt bò",
      "amount": "1",
      "unit": "kg",
      "category": "🥩 Thịt tươi sống",
      "estimated_cost": 350000,
      "price_per_unit": 350000
    }
  ],
  "budget_limit": 500000
}
```

**Response:**
```json
{
  "total_items": 1,
  "optimization_suggestions": ["Thay thịt bò bằng thịt heo tiết kiệm 40%"],
  "substitution_recommendations": {"thịt bò": "thịt heo"},
  "timing_advice": "Mua sáng sớm để có giá tốt",
  "budget_optimization": "Có thể tiết kiệm 20%",
  "health_insights": "Cân bằng protein và vitamin",
  "sustainability_tips": "Ưu tiên thực phẩm địa phương",
  "generated_at": "2024-01-15T10:30:00Z"
}
```

## Setup và Testing

### 1. Backend Setup
```bash
cd c:\Users\LENOVO\backend

# Install dependencies
pip install -r requirements.txt

# Run server
python main.py
```

### 2. Test Endpoints
```bash
# Run test script
python test_ai_endpoints.py
```

### 3. Flutter Integration
```dart
// Update baseUrl in service
static const String baseUrl = 'https://your-production-url.com';

// Test connection
final aiService = PriceAIAnalysisService();
final isConnected = await aiService.testConnection();
```

## Error Handling

### 1. Backend Offline
- Frontend tự động fallback về mock data
- Hiển thị warning cho user
- Retry mechanism

### 2. API Errors
- Proper error messages
- Logging for debugging
- Graceful degradation

### 3. Network Issues
- Timeout handling
- Connection retry
- Offline mode support

## Performance Optimization

### 1. Backend Caching
```python
# Cache AI responses
@lru_cache(maxsize=100)
async def analyze_price_trends_cached(category, days_back):
    return await analyze_price_trends(category, days_back)
```

### 2. Request Batching
```dart
// Batch multiple requests
Future<List<Map<String, dynamic>>> batchAnalysis() async {
  return await Future.wait([
    analyzePriceTrends(),
    analyzeSeasonalTrends(),
    generateMarketInsights(),
  ]);
}
```

### 3. Response Compression
```python
# Enable gzip compression
from fastapi.middleware.gzip import GZipMiddleware
app.add_middleware(GZipMiddleware, minimum_size=1000)
```

## Security

### 1. API Key Protection
```python
# Store in environment variables
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
```

### 2. Rate Limiting
```python
from slowapi import Limiter
limiter = Limiter(key_func=get_remote_address)

@app.post("/ai-price/analyze-trends")
@limiter.limit("10/minute")
async def analyze_trends(...):
```

### 3. Input Validation
```python
# Pydantic models tự động validate
class PriceTrendAnalysisRequest(BaseModel):
    category: Optional[str] = None
    days_back: int = Field(30, ge=1, le=365)
```

## Deployment

### 1. Production URL
```dart
// Update in Flutter
static const String baseUrl = 'https://your-backend.render.com';
```

### 2. Environment Variables
```bash
# Backend .env
GROQ_API_KEY=your_groq_key
OPENAI_API_KEY=your_openai_key
ENVIRONMENT=production
```

### 3. Health Monitoring
```python
@router.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "ai_service_available": bool(groq_service),
        "timestamp": datetime.now().isoformat()
    }
```

## Benefits

### 1. Performance
- ⚡ Faster AI processing on server
- 🔄 Better caching strategies
- 📊 Reduced mobile battery usage

### 2. Security
- 🔐 API keys protected on server
- 🛡️ Input validation and sanitization
- 🚫 Rate limiting and abuse prevention

### 3. Scalability
- 📈 Easy horizontal scaling
- 🔧 Independent backend updates
- 🌐 Multi-platform support

### 4. Maintainability
- 🧹 Cleaner separation of concerns
- 🔄 Easier AI model updates
- 📝 Better logging and monitoring

## Next Steps

1. **Deploy backend** to production (Render/Heroku)
2. **Update Flutter baseUrl** to production URL
3. **Add authentication** for API endpoints
4. **Implement caching** for better performance
5. **Add monitoring** and analytics
6. **Scale AI models** based on usage

---

**Kết luận:** Việc chuyển AI logic sang backend giúp ứng dụng có hiệu suất tốt hơn, bảo mật cao hơn và dễ maintain hơn. Frontend chỉ cần gọi API và hiển thị kết quả, trong khi toàn bộ logic phức tạp được xử lý ở backend.
