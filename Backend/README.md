# PlaneTracker Backend

Python backend server for the PlaneTracker iOS application, providing flight data processing, caching, and API endpoints.

## Overview

The backend serves as a data processing layer between the iOS app and the OpenSky Network API, providing:

- **Flight data aggregation** from OpenSky API
- **Intelligent caching** to reduce API rate limits
- **CORS support** for iOS app connectivity
- **Trajectory prediction** using Kalman filtering
- **Altitude estimation** with confidence scoring

## Quick Start

```bash
# Navigate to backend directory
cd Backend

# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Start server
python main.py
```

## Installation

### Prerequisites

- **Python 3.8+** (recommended: Python 3.11+)
- **macOS, Linux, or Windows** with Python support

### Environment Setup

1. **Create virtual environment**:
   ```bash
   python3 -m venv venv
   ```

2. **Activate virtual environment**:
   ```bash
   # macOS/Linux
   source venv/bin/activate
   
   # Windows
   venv\Scripts\activate
   ```

3. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

### Dependencies

The backend requires these Python packages:

- **aiohttp**: Async HTTP server framework
- **numpy**: Numerical computing for Kalman filtering
- **python-dateutil**: Date/time utilities
- **asyncio**: Asynchronous programming support

## Configuration

### Environment Variables

Create a `.env` file for configuration:

```bash
# Backend configuration
BACKEND_HOST=0.0.0.0
BACKEND_PORT=8000

# OpenSky API configuration
OPENSKY_API_BASE_URL=https://opensky-network.org/api
OPENSKY_RATE_LIMIT=10  # requests per minute

# Caching configuration
CACHE_DURATION=8  # seconds
MAX_CACHE_SIZE=1000  # flights

# Development settings
DEBUG=True
LOG_LEVEL=INFO
```

### Network Configuration

The backend binds to `0.0.0.0:8000` by default to allow connections from:

- **Local iOS Simulator**: `localhost:8000`
- **Physical iPhone**: `[Mac-IP-Address]:8000`
- **Network devices**: Any device on the same network

## API Endpoints

### Health Check

```http
GET /api/health
```

**Response**:
```json
{
  "status": "healthy",
  "timestamp": "2025-10-14T17:30:00.000Z"
}
```

### Get All Flights

```http
GET /api/flights
```

**Response**:
```json
{
  "success": true,
  "flights": [
    {
      "icao24": "abc123",
      "callsign": "UAL123",
      "originCountry": "United States",
      "longitude": -122.4194,
      "latitude": 37.7749,
      "baroAltitude": 35000,
      "velocity": 450,
      "trueTrack": 90,
      "verticalRate": 0,
      "onGround": false,
      "predictedAltitude": 35000,
      "altitudeConfidence": 0.95,
      "hasPredictedAltitude": true,
      "predictedTrajectory": [
        {"latitude": 37.8, "longitude": -122.3, "altitude": 35000, "time_offset": 60}
      ]
    }
  ],
  "count": 1,
  "timestamp": "2025-10-14T17:30:00.000Z"
}
```

### Get Specific Flight

```http
GET /api/flights/{flight_id}
```

**Parameters**:
- `flight_id`: ICAO24 aircraft identifier

### Get Flight Trajectory

```http
GET /api/flights/{flight_id}/trajectory?time=60
```

**Parameters**:
- `flight_id`: ICAO24 aircraft identifier
- `time`: Prediction time in seconds (default: 60)

### Get Altitude Prediction

```http
GET /api/flights/{flight_id}/altitude
```

**Parameters**:
- `flight_id`: ICAO24 aircraft identifier

## Rate Limiting

The OpenSky API has strict rate limits:

- **Free tier**: 10 requests per minute
- **Paid tier**: 100+ requests per minute

### Caching Strategy

The backend implements intelligent caching:

1. **8-second cache duration** for flight data
2. **Automatic cache refresh** in background
3. **Rate limit detection** and graceful degradation
4. **Cached data fallback** when API limits hit

### Rate Limit Handling

When rate limits are exceeded:

1. **Return cached data** if available
2. **Log rate limit warnings** for monitoring
3. **Continue background refresh** when limits reset
4. **Maintain service availability** for iOS app

## Development

### Running in Development

```bash
# Start with debug logging
python main.py --debug

# Start with custom port
python main.py --port 9000

# Start with custom host
python main.py --host 127.0.0.1
```

### Testing

```bash
# Run backend tests
python -m pytest test_enhanced_api.py

# Test specific endpoints
python test_api.py

# Test optimized performance
python test_optimized_api.py
```

### Logging

The backend provides detailed logging:

```bash
# View logs in real-time
tail -f backend.log

# Filter for specific events
grep "Rate limit" backend.log
grep "Cache" backend.log
```

## Production Deployment

### Cloud Deployment

For production use:

1. **Deploy to cloud platform** (AWS, GCP, Azure)
2. **Configure domain and SSL** for HTTPS
3. **Update iOS app** to use production URL
4. **Set up monitoring** and alerting
5. **Configure backup** and disaster recovery

### Docker Deployment

```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
EXPOSE 8000

CMD ["python", "main.py"]
```

### Environment Configuration

Production environment variables:

```bash
# Production settings
DEBUG=False
LOG_LEVEL=WARNING
BACKEND_HOST=0.0.0.0
BACKEND_PORT=8000

# Security
CORS_ORIGINS=https://your-ios-app.com
API_KEY=your-secure-api-key

# Monitoring
SENTRY_DSN=your-sentry-dsn
```

## Monitoring

### Health Monitoring

```bash
# Check server health
curl http://localhost:8000/api/health

# Check rate limit status
curl http://localhost:8000/api/rate-limit

# Check server status
curl http://localhost:8000/api/status
```

### Performance Metrics

The backend tracks:

- **Request count** and response times
- **Cache hit/miss ratios**
- **Rate limit usage**
- **Error rates** and types
- **Memory usage** and CPU load

### Log Analysis

```bash
# Analyze request patterns
grep "GET /api/flights" backend.log | wc -l

# Check error rates
grep "ERROR" backend.log | wc -l

# Monitor rate limits
grep "Rate limit" backend.log
```

## Troubleshooting

### Common Issues

**Problem**: "Address already in use"

**Solution**:
```bash
# Find process using port 8000
lsof -i :8000

# Kill the process
kill -9 <PID>
```

**Problem**: "Module not found" errors

**Solution**:
```bash
# Ensure virtual environment is activated
source venv/bin/activate

# Reinstall dependencies
pip install -r requirements.txt
```

**Problem**: iOS app can't connect

**Solution**:
1. **Check firewall settings**: Allow Python through firewall
2. **Verify network**: Ensure iPhone and Mac on same network
3. **Test connectivity**: `curl http://[Mac-IP]:8000/api/health`
4. **Check CORS headers**: Verify CORS middleware is working

### Debug Mode

Enable debug logging:

```bash
# Start with debug mode
python main.py --debug

# Or set environment variable
export DEBUG=True
python main.py
```

### Network Testing

Test backend connectivity:

```bash
# Test health endpoint
curl -v http://localhost:8000/api/health

# Test CORS headers
curl -v -X OPTIONS http://localhost:8000/api/flights

# Test from different machine
curl -v http://[Mac-IP-Address]:8000/api/health
```

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   iOS App       │    │   Python Backend │    │   OpenSky API   │
│                 │    │                  │    │                 │
│ ┌─────────────┐ │    │ ┌──────────────┐ │    │ ┌─────────────┐ │
│ │BackendService│ │◄───┤ │ FlightService│ │◄───┤ │ Flight Data  │ │
│ │             │ │    │ │              │ │    │ │             │ │
│ └─────────────┘ │    │ └──────────────┘ │    │ └─────────────┘ │
│                 │    │                  │    │                 │
│                 │    │ ┌──────────────┐ │    │                 │
│                 │    │ │ KalmanFilter │ │    │                 │
│                 │    │ │              │ │    │                 │
│                 │    │ └──────────────┘ │    │                 │
│                 │    │                  │    │                 │
│                 │    │ ┌──────────────┐ │    │                 │
│                 │    │ │ Cache Layer  │ │    │                 │
│                 │    │ │              │ │    │                 │
│                 │    │ └──────────────┘ │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Performance Optimization

### Caching Strategy

- **In-memory caching** for fast access
- **8-second cache duration** balances freshness vs. API limits
- **Background refresh** prevents cache misses
- **Intelligent invalidation** based on data age

### Rate Limit Management

- **Request queuing** during rate limit periods
- **Exponential backoff** for retry logic
- **Graceful degradation** with cached data
- **Proactive refresh** before cache expiration

### Memory Management

- **Efficient data structures** for flight storage
- **Automatic cleanup** of old flight data
- **Memory monitoring** and garbage collection
- **Resource pooling** for HTTP connections

## Security Considerations

### CORS Configuration

The backend includes proper CORS headers:

```python
# CORS headers for iOS app
'Access-Control-Allow-Origin': '*'
'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
'Access-Control-Allow-Headers': 'Content-Type, Authorization'
```

### Input Validation

- **Flight ID validation** for API endpoints
- **Parameter sanitization** for query strings
- **Error handling** for malformed requests
- **Rate limiting** per client IP

### Production Security

For production deployment:

1. **HTTPS only** for all communications
2. **API key authentication** for iOS app
3. **Request rate limiting** per client
4. **Input validation** and sanitization
5. **Security headers** and CORS restrictions

## Contributing

### Development Setup

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/new-feature`
3. **Make changes** and test thoroughly
4. **Run tests**: `python -m pytest`
5. **Submit pull request** with description

### Code Style

- **Follow PEP 8** for Python code
- **Use type hints** for function parameters
- **Document functions** with docstrings
- **Write tests** for new features

### Testing Requirements

- **Unit tests** for all new functions
- **Integration tests** for API endpoints
- **Performance tests** for caching logic
- **Error handling tests** for edge cases

## License

This backend is part of the PlaneTracker project. See the main repository for license information.

## Support

For issues and questions:

1. **Check this documentation** first
2. **Review error logs** for specific issues
3. **Test with curl** to isolate problems
4. **Check network connectivity** between devices
5. **Verify Python environment** and dependencies

The backend is designed to be robust and self-healing, with comprehensive error handling and graceful degradation when external services are unavailable.
