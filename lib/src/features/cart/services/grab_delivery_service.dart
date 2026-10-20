import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../models/delivery_quote.dart';

import '../../../core/constants/api_constants.dart';

class GrabDeliveryService {
  // Backend API Configuration (handles Grab API integration)
  static String get _baseUrl => ApiConstants.baseUrl;
  
  // Note: The backend handles Grab OAuth authentication
  // We just need to call our backend endpoint

  /// Build package data from order items
  List<Map<String, dynamic>> _buildPackages(DeliveryAddress origin, DeliveryAddress destination) {
    // Default package for food delivery
    return [
      {
        'name': 'Food Order',
        'description': 'Delitopia food delivery',
        'quantity': 1,
        'price': 0, // Will be set from cart total
        'dimensions': {
          'height': 0,
          'width': 0,
          'depth': 0,
          'weight': 0,
        },
      },
    ];
  }

  /// Get delivery quote from backend API (which calls Grab API)
  /// 
  /// Parameters:
  /// - [origin]: Pickup location (restaurant/branch)
  /// - [destination]: Customer delivery address
  /// - [branchId]: ID of the restaurant branch
  /// - [userId]: ID of the user placing the order
  /// 
  /// Returns a list of available delivery quotes with different service types
  Future<List<DeliveryQuote>> getDeliveryQuote({
    required DeliveryAddress origin,
    required DeliveryAddress destination,
    int? branchId,
    int? userId,
  }) async {
    try {
      final requestBody = {
        'branch_id': branchId ?? 1,
        'user_id': userId ?? 1,
        'destination': {
          'address': destination.address,
          'lat': destination.latitude,
          'lng': destination.longitude,
        },
        'packages': _buildPackages(origin, destination),
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/postData/grab-quotes'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          // Add authorization header if needed
          // 'Authorization': 'Bearer YOUR_TOKEN',
        },
        body: jsonEncode(requestBody));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final quotes = data['quotes'] as List;
        return quotes.map((q) => DeliveryQuote.fromJson(q)).toList();
      } else if (response.statusCode == 404) {
        throw Exception('Delivery service not available for this location');
      } else {
        throw Exception('Failed to get delivery quote: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback to mock data if API fails
      return getMockDeliveryQuote(origin: origin, destination: destination);
    }
  }

  /// Calculate distance between two coordinates (Haversine formula)
  /// Returns distance in kilometers
  double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const double earthRadius = 6371; // km

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  /// Mock delivery quote for testing (when Grab API is not configured)
  /// This calculates a simple distance-based price
  Future<List<DeliveryQuote>> getMockDeliveryQuote({
    required DeliveryAddress origin,
    required DeliveryAddress destination,
  }) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));

    final distance = calculateDistance(
      lat1: origin.latitude,
      lon1: origin.longitude,
      lat2: destination.latitude,
      lon2: destination.longitude);

    // Base price + distance-based pricing
    const basePrice = 5000.0; // Rp 5,000
    const pricePerKm = 2000.0; // Rp 2,000 per km
    
    final motorcyclePrice = basePrice + (distance * pricePerKm);
    final carPrice = motorcyclePrice * 1.5;

    return [
      DeliveryQuote(
        serviceType: 'GrabExpress (Motorcycle)',
        amount: motorcyclePrice,
        currency: 'IDR',
        estimatedTimeMinutes: (15 + (distance * 3)).toInt(),
        vehicleType: 'MOTORCYCLE',
        quoteId: 'mock_quote_motorcycle_${DateTime.now().millisecondsSinceEpoch}',
        distanceInKm: distance * 1.55,
      ),
      DeliveryQuote(
        serviceType: 'GrabExpress (Car)',
        amount: carPrice,
        currency: 'IDR',
        estimatedTimeMinutes: (20 + (distance * 2.5)).toInt(),
        vehicleType: 'CAR',
        quoteId: 'mock_quote_car_${DateTime.now().millisecondsSinceEpoch}',
        distanceInKm: distance * 1.55,
      ),
    ];
  }
}
