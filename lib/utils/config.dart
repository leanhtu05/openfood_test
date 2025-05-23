// Base API URL configuration
const String apiBaseUrl = 'https://openfood-api.onrender.com'; // Production API

// API timeouts (in seconds)
const int apiRequestTimeout = 30;
const int apiConnectionTimeout = 10;

// Feature flags
const bool useFirebaseByDefault = true;
const bool useMockDataWhenOffline = true;
const bool enableAIFeatures = true;

// User preferences defaults
const double defaultCaloriesTarget = 2000.0;
const double defaultProteinTarget = 120.0;
const double defaultFatTarget = 65.0;
const double defaultCarbsTarget = 250.0; 