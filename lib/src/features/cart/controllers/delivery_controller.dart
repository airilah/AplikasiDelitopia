import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/delivery_quote.dart';
import '../services/grab_delivery_service.dart';

final grabDeliveryServiceProvider = Provider<GrabDeliveryService>((ref) {
  return GrabDeliveryService();
});

final deliveryQuotesProvider = FutureProvider.family<List<DeliveryQuote>, DeliveryQuoteRequest>(
  (ref, request) async {
    final service = ref.read(grabDeliveryServiceProvider);
    
    // Call real backend API (with fallback to mock if it fails)
    return service.getDeliveryQuote(
      origin: request.origin,
      destination: request.destination,
      branchId: request.branchId,
      userId: request.userId);
  });

class DeliveryQuoteRequest {
  final DeliveryAddress origin;
  final DeliveryAddress destination;
  final int? branchId;
  final int? userId;

  DeliveryQuoteRequest({
    required this.origin,
    required this.destination,
    this.branchId,
    this.userId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeliveryQuoteRequest &&
        other.origin.latitude == origin.latitude &&
        other.origin.longitude == origin.longitude &&
        other.destination.latitude == destination.latitude &&
        other.destination.longitude == destination.longitude &&
        other.branchId == branchId &&
        other.userId == userId;
  }

  @override
  int get hashCode {
    return Object.hash(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
      branchId,
      userId);
  }
}
