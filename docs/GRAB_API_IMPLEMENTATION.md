# Grab API Implementation Guide for Delitopia V2

## 📋 Overview

The original Delitopia app uses Grab's delivery service API to calculate delivery fees for food orders. This guide explains how it works and how to implement it in your new Delitopia V2 project.

## 🔑 What You Need

### 1. Backend API Endpoint
Your backend needs to handle Grab API integration. The old app uses:
```
POST https://delitopia.softindopp.com/api/postData/grab-quotes
```

### 2. Grab API Credentials
You'll need Grab Express API credentials:
- **Client ID**: From Grab Developer Console
- **Client Secret**: From Grab Developer Console
- **Merchant ID**: Your business identifier
- **Environment**: Staging or Production

**How to get credentials:**
1. Go to https://developer.grab.com/
2. Register/Login
3. Create an app in the Grab Developer Console
4. Get your Client ID and Secret from the app settings
5. Apply for GrabExpress API access

## 📍 How It Works

### Flow Overview:
```
User selects delivery → App sends request to your backend → Backend calls Grab API → Returns delivery fee → App displays fee
```

### Data Flow:

1. **User Input** (Flutter App):
   - Branch location (latitude, longitude, address)
   - Delivery destination (user's address, lat, lng)
   - Order items (for package details)
   
2. **App sends to Backend** (Your API):
   ```json
   {
     "branch_id": 1,
     "destination": {
       "address": "Jl. Example No. 123, Jakarta",
       "lat": -6.200000,
       "lng": 106.816666
     },
     "user_id": 42,
     "packages": [{
       "name": "Nasi Goreng",
       "description": "Extra pedas",
       "quantity": 2,
       "price": 25000,
       "dimensions": {
         "height": 0,
         "width": 0,
         "depth": 0,
         "weight": 0
       }
     }]
   }
   ```

3. **Backend calls Grab API**:
   Your backend should call Grab's Quote API endpoint
   
4. **Grab returns delivery fee**:
   ```json
   {
     "quotes": [{
       "amount": 15000,
       "currency": "IDR",
       "estimatedTimeline": "30-45 mins",
       "distance": 5.2
     }]
   }
   ```

5. **App receives and displays**:
   The delivery fee is added to the order total

## 💻 Implementation in Delitopia V2

### Step 1: Create the Model

Create `lib/src/features/order/models/delivery_model.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'delivery_model.freezed.dart';
part 'delivery_model.g.dart';

@freezed
class DeliveryQuoteRequest with _$DeliveryQuoteRequest {
  const factory DeliveryQuoteRequest({
    required int branchId,
    required int userId,
    required DeliveryDestination destination,
    required List<DeliveryPackage> packages,
  }) = _DeliveryQuoteRequest;

  factory DeliveryQuoteRequest.fromJson(Map<String, dynamic> json) =>
      _$DeliveryQuoteRequestFromJson(json);
}

@freezed
class DeliveryDestination with _$DeliveryDestination {
  const factory DeliveryDestination({
    required String address,
    required double lat,
    required double lng,
  }) = _DeliveryDestination;

  factory DeliveryDestination.fromJson(Map<String, dynamic> json) =>
      _$DeliveryDestinationFromJson(json);
}

@freezed
class DeliveryPackage with _$DeliveryPackage {
  const factory DeliveryPackage({
    required String name,
    required String description,
    required int quantity,
    required double price,
    required PackageDimensions dimensions,
  }) = _DeliveryPackage;

  factory DeliveryPackage.fromJson(Map<String, dynamic> json) =>
      _$DeliveryPackageFromJson(json);
}

@freezed
class PackageDimensions with _$PackageDimensions {
  const factory PackageDimensions({
    @Default(0) int height,
    @Default(0) int width,
    @Default(0) int depth,
    @Default(0) int weight,
  }) = _PackageDimensions;

  factory PackageDimensions.fromJson(Map<String, dynamic> json) =>
      _$PackageDimensionsFromJson(json);
}

@freezed
class DeliveryQuoteResponse with _$DeliveryQuoteResponse {
  const factory DeliveryQuoteResponse({
    required List<DeliveryQuote> quotes,
  }) = _DeliveryQuoteResponse;

  factory DeliveryQuoteResponse.fromJson(Map<String, dynamic> json) =>
      _$DeliveryQuoteResponseFromJson(json);
}

@freezed
class DeliveryQuote with _$DeliveryQuote {
  const factory DeliveryQuote({
    required double amount,
    required String currency,
    String? estimatedTimeline,
    double? distance,
  }) = _DeliveryQuote;

  factory DeliveryQuote.fromJson(Map<String, dynamic> json) =>
      _$DeliveryQuoteFromJson(json);
}
```

### Step 2: Create the Service

Create `lib/src/features/order/services/delivery_service.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/delivery_model.dart';
import '../../../core/constants/api_constants.dart';

part 'delivery_service.g.dart';

@riverpod
DeliveryService deliveryService(DeliveryServiceRef ref) {
  return DeliveryService(dio: Dio());
}

class DeliveryService {
  final Dio dio;

  DeliveryService({required this.dio});

  /// Get delivery fee quote from Grab
  Future<double> getDeliveryFee(DeliveryQuoteRequest request) async {
    try {
      final response = await dio.post(
        '${ApiConstants.baseUrl}/postData/grab-quotes',
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer YOUR_TOKEN', // Add auth token
          },
        ),
      );

      if (response.statusCode == 200) {
        final quoteResponse = DeliveryQuoteResponse.fromJson(response.data);
        
        if (quoteResponse.quotes.isNotEmpty) {
          return quoteResponse.quotes.first.amount;
        } else {
          throw Exception('No delivery quotes available');
        }
      } else {
        throw Exception('Failed to get delivery fee: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Delivery service not available for this location');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to calculate delivery fee: $e');
    }
  }

  /// Calculate distance between two coordinates (in meters)
  double calculateDistance({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    // Use Geolocator for accurate distance calculation
    // This is a helper method for local calculations
    const double earthRadius = 6371000; // meters
    
    final dLat = _toRadians(endLat - startLat);
    final dLng = _toRadians(endLng - startLng);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(startLat)) *
            cos(_toRadians(endLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }
}
```

### Step 3: Create the Controller

Create `lib/src/features/order/controllers/delivery_controller.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/delivery_model.dart';
import '../models/order_model.dart';
import '../services/delivery_service.dart';

part 'delivery_controller.g.dart';

@riverpod
class DeliveryFee extends _$DeliveryFee {
  @override
  double build() => 0.0;

  Future<void> calculateFee(Order order) async {
    if (order.orderType != OrderType.delivery) {
      state = 0.0;
      return;
    }

    try {
      // Build the request
      final request = DeliveryQuoteRequest(
        branchId: order.branchId,
        userId: order.userId,
        destination: DeliveryDestination(
          address: order.deliveryAddress ?? '',
          lat: order.deliveryLatitude ?? 0.0,
          lng: order.deliveryLongitude ?? 0.0,
        ),
        packages: order.items.map((item) {
          return DeliveryPackage(
            name: item.name,
            description: item.notes ?? '',
            quantity: item.quantity,
            price: item.price,
            dimensions: const PackageDimensions(),
          );
        }).toList(),
      );

      // Call the service
      final fee = await ref.read(deliveryServiceProvider).getDeliveryFee(request);
      state = fee;
    } catch (e) {
      // Handle error
      throw Exception('Failed to calculate delivery fee: $e');
    }
  }

  void reset() {
    state = 0.0;
  }
}
```

### Step 4: Use in UI

In your checkout/payment screen (`lib/src/features/order/views/checkout_view.dart`):

```dart
class CheckoutView extends ConsumerWidget {
  const CheckoutView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(currentOrderProvider);
    final deliveryFee = ref.watch(deliveryFeeProvider);
    
    return Scaffold(
      body: Column(
        children: [
          // ... other UI elements
          
          // Delivery Type Selection
          OrderTypeSelector(
            selected: order.orderType,
            onChanged: (type) async {
              ref.read(currentOrderProvider.notifier).setOrderType(type);
              
              if (type == OrderType.delivery) {
                // Show address picker
                final address = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddressPickerView(),
                  ),
                );
                
                if (address != null) {
                  ref.read(currentOrderProvider.notifier).setDeliveryAddress(address);
                  
                  // Calculate delivery fee
                  await ref.read(deliveryFeeProvider.notifier).calculateFee(order);
                }
              } else {
                // Reset delivery fee for pickup/dine-in
                ref.read(deliveryFeeProvider.notifier).reset();
              }
            },
          ),
          
          // Show delivery address if delivery type
          if (order.orderType == OrderType.delivery) ...[
            DeliveryAddressCard(
              address: order.deliveryAddress ?? '',
              onEdit: () async {
                // Allow editing address
                final newAddress = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddressPickerView(),
                  ),
                );
                
                if (newAddress != null) {
                  ref.read(currentOrderProvider.notifier).setDeliveryAddress(newAddress);
                  await ref.read(deliveryFeeProvider.notifier).calculateFee(order);
                }
              },
            ),
          ],
          
          const Spacer(),
          
          // Order Summary
          OrderSummaryCard(
            subtotal: order.subtotal,
            tax: order.tax,
            service: order.service,
            deliveryFee: deliveryFee,
            total: order.subtotal + order.tax + order.service + deliveryFee,
          ),
          
          // Place Order Button
          ElevatedButton(
            onPressed: () {
              // Place order with delivery fee
              ref.read(currentOrderProvider.notifier).setDeliveryFee(deliveryFee);
              // Submit order...
            },
            child: const Text('Place Order'),
          ),
        ],
      ),
    );
  }
}
```

## 🔧 Backend Implementation (PHP/Laravel Example)

Your backend API endpoint should look like this:

```php
// routes/api.php
Route::post('/postData/grab-quotes', [GrabController::class, 'getQuotes']);

// app/Http/Controllers/GrabController.php
class GrabController extends Controller
{
    public function getQuotes(Request $request)
    {
        $validated = $request->validate([
            'branch_id' => 'required|integer',
            'user_id' => 'required|integer',
            'destination' => 'required|array',
            'destination.address' => 'required|string',
            'destination.lat' => 'required|numeric',
            'destination.lng' => 'required|numeric',
            'packages' => 'required|array',
        ]);

        // Get branch location
        $branch = Branch::findOrFail($validated['branch_id']);
        
        // Prepare Grab API request
        $grabRequest = [
            'origin' => [
                'address' => $branch->address,
                'coordinates' => [
                    'latitude' => $branch->latitude,
                    'longitude' => $branch->longitude,
                ],
            ],
            'destination' => [
                'address' => $validated['destination']['address'],
                'coordinates' => [
                    'latitude' => $validated['destination']['lat'],
                    'longitude' => $validated['destination']['lng'],
                ],
            ],
            'packages' => $validated['packages'],
            'serviceType' => 'INSTANT', // or 'SAME_DAY'
        ];

        // Call Grab API
        $grabResponse = $this->callGrabApi($grabRequest);
        
        return response()->json($grabResponse);
    }

    private function callGrabApi($request)
    {
        $client = new \GuzzleHttp\Client();
        
        // Get OAuth token first
        $tokenResponse = $client->post('https://partner-api.grab.com/grabid/v1/oauth2/token', [
            'form_params' => [
                'client_id' => env('GRAB_CLIENT_ID'),
                'client_secret' => env('GRAB_CLIENT_SECRET'),
                'grant_type' => 'client_credentials',
                'scope' => 'grab_express.partner_deliveries',
            ],
        ]);
        
        $token = json_decode($tokenResponse->getBody())->access_token;
        
        // Call quote API
        $response = $client->post('https://partner-api.grab.com/grab-express/v1/deliveries/quotes', [
            'headers' => [
                'Authorization' => 'Bearer ' . $token,
                'Content-Type' => 'application/json',
            ],
            'json' => $request,
        ]);
        
        return json_decode($response->getBody(), true);
    }
}
```

## 📝 Environment Variables

Add to your `.env` file:

```env
# Grab API Credentials
GRAB_CLIENT_ID=your_client_id_here
GRAB_CLIENT_SECRET=your_client_secret_here
GRAB_MERCHANT_ID=your_merchant_id_here
GRAB_ENV=staging  # or production
```

## 🧪 Testing

### 1. Test with Staging Environment
```dart
// Use Grab's staging endpoint for testing
final testRequest = DeliveryQuoteRequest(
  branchId: 1,
  userId: 1,
  destination: DeliveryDestination(
    address: 'Test Address, Jakarta',
    lat: -6.200000,
    lng: 106.816666,
  ),
  packages: [
    DeliveryPackage(
      name: 'Test Order',
      description: 'Testing delivery',
      quantity: 1,
      price: 50000,
      dimensions: const PackageDimensions(),
    ),
  ],
);

final fee = await deliveryService.getDeliveryFee(testRequest);
print('Delivery fee: Rp ${fee.toStringAsFixed(0)}');
```

### 2. Mock for Development
```dart
// For local testing without hitting the real API
class MockDeliveryService extends DeliveryService {
  MockDeliveryService() : super(dio: Dio());

  @override
  Future<double> getDeliveryFee(DeliveryQuoteRequest request) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    // Calculate mock fee based on distance
    // Assume Rp 2,000 per km + base fee Rp 5,000
    final distance = calculateDistance(
      startLat: -6.175110,  // Branch location
      startLng: 106.865036,
      endLat: request.destination.lat,
      endLng: request.destination.lng,
    );
    
    final distanceKm = distance / 1000;
    final baseFee = 5000.0;
    final perKm = 2000.0;
    
    return baseFee + (distanceKm * perKm);
  }
}
```

## 🚨 Error Handling

```dart
try {
  final fee = await ref.read(deliveryServiceProvider).getDeliveryFee(request);
  ref.read(deliveryFeeProvider.notifier).state = fee;
} on DioException catch (e) {
  if (e.response?.statusCode == 404) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Delivery not available for this location'),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.message}'),
      ),
    );
  }
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Failed to calculate delivery fee. Please try again.'),
    ),
  );
}
```

## 📊 Key Points

1. **Distance Calculation**: The app calculates distance locally using `Geolocator.distanceBetween()` for display purposes, but the actual delivery fee comes from Grab API.

2. **Fee Caching**: Consider caching delivery fees for the same address to avoid repeated API calls:
   ```dart
   final cachedFees = <String, double>{};
   final key = '${lat}_${lng}';
   if (cachedFees.containsKey(key)) {
     return cachedFees[key]!;
   }
   ```

3. **Minimum Order**: Grab may have minimum order values or distance restrictions.

4. **Real-time Updates**: If the user changes their delivery address, recalculate the fee immediately.

5. **Fallback**: Have a fallback delivery fee calculation in case Grab API is down.

## 🔗 Useful Resources

- **Grab Developer Docs**: https://developer.grab.com/docs/
- **GrabExpress API**: https://developer.grab.com/docs/merchant-api/grab-express
- **Grab Partner Dashboard**: https://partner.grab.com/

## 💡 Next Steps

1. Register for Grab Developer account
2. Get API credentials
3. Implement backend endpoint
4. Test in staging environment
5. Integrate in Flutter app
6. Test end-to-end flow
7. Deploy to production

---

**Questions? Check your backend API logs and Grab Developer Console for debugging.**
