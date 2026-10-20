# Grab Delivery Integration

This document explains how to integrate Grab delivery API for calculating delivery charges in the Delitopia app.

## Features

- ✅ Real-time delivery quote calculation via backend API
- ✅ Multiple delivery options (Motorcycle, Car)
- ✅ Distance-based pricing
- ✅ Estimated delivery time
- ✅ Mock data for testing (fallback when backend is unavailable)
- ✅ Beautiful UI with delivery option selection
- ✅ Automatic branch location detection from selected branch
- ✅ Backend handles Grab OAuth authentication

## Architecture

The app uses a **backend-first approach** where:
1. Flutter app → Your backend API → Grab API
2. Backend handles all Grab OAuth authentication
3. Backend manages API credentials securely
4. Flutter just sends delivery request and receives quotes

## Backend API Endpoint

**Endpoint**: `POST https://delitopia.softindopp.com/api/postData/grab-quotes`

**Request Format**:
```json
{
  "branch_id": 1,
  "user_id": 42,
  "destination": {
    "address": "Jl. Example No. 123, Jakarta",
    "lat": -6.200000,
    "lng": 106.816666
  },
  "packages": [{
    "name": "Food Order",
    "description": "Delitopia food delivery",
    "quantity": 1,
    "price": 0,
    "dimensions": {
      "height": 0,
      "width": 0,
      "depth": 0,
      "weight": 0
    }
  }]
}
```

**Response Format**:
```json
{
  "quotes": [{
    "service": {
      "id": "MOTORCYCLE",
      "name": "GrabExpress (Motorcycle)"
    },
    "amount": 15000,
    "currency": "IDR",
    "estimatedTimeline": 25,
    "quoteId": "quote_123456"
  }]
}
```

## How It Works

### 1. **User Flow**
1. User adds items to cart from menu
2. User navigates to cart page
3. User toggles "Delivery Options" switch
4. App gets selected branch location automatically
5. App sends request to backend with:
   - Branch ID (pickup location)
   - User ID
   - Destination address (customer location)
   - Package details
6. Backend calls Grab API with OAuth authentication
7. Backend returns delivery quotes
8. User selects delivery option
9. Delivery fee is added to order total

### 2. **Fallback Mode (Mock Quotes)**
If the backend API is unavailable or returns an error, the app automatically falls back to **mock delivery quotes**:
- Base price: Rp 5,000
- Price per kilometer: Rp 2,000
- Motorcycle delivery: Base + (distance × Rp 2,000)
- Car delivery: Motorcycle price × 1.5

This ensures the app continues to work even if:
- Backend is down
- Network issues occur
- Grab API is unavailable
- Testing without backend

### 3. **Branch Location Detection**
The app automatically uses the **selected branch** location:
- Gets branch from `selectedBranchProvider`
- Extracts latitude, longitude, and address
- Uses branch outlet name as contact name
- No need to hardcode restaurant locations

### 4. **Customer Location**
Currently uses a mock customer location in `cart_view.dart`:
```dart
final DeliveryAddress _customerLocation = DeliveryAddress(
  latitude: -6.1751,
  longitude: 106.8650,
  address: 'Customer Address, Jakarta',
);
```

**TODO**: Replace with user's saved delivery address from:
- User profile
- Saved addresses
- Location picker
- GPS location

The delivery integration is automatically shown in the cart page:

1. **Toggle Delivery**: Switch on "Delivery Options"
2. **Select Service**: Choose between Motorcycle or Car delivery
3. **View Price**: Delivery fee is automatically added to the total

## Backend Setup (Required)

Your backend needs to implement the Grab API integration. See `GRAB_API_IMPLEMENTATION.md` for complete backend setup guide.

### Backend Endpoint Requirements:
1. **Authentication**: Handle Grab OAuth token management
2. **API Calls**: Call Grab delivery quotes API
3. **Error Handling**: Return proper error codes
4. **Security**: Keep Grab credentials secure (never expose in Flutter app)

### Environment Variables (Backend):
```env
GRAB_CLIENT_ID=your_client_id
GRAB_CLIENT_SECRET=your_client_secret  
GRAB_MERCHANT_ID=your_merchant_id
GRAB_ENV=staging  # or production
```

## Usage in Cart Page

## Code Structure

```
lib/src/features/cart/
├── models/
│   └── delivery_quote.dart              # DeliveryQuote, DeliveryAddress models
├── services/
│   └── grab_delivery_service.dart       # Backend API integration (with mock fallback)
├── controllers/
│   └── delivery_controller.dart         # Riverpod providers
└── views/
    └── cart_view.dart                   # Cart page with delivery options UI
```

### Key Components

**1. DeliveryQuote Model** (`delivery_quote.dart`)
- `DeliveryQuote`: Contains amount, service type, estimated time, quote ID
- `DeliveryAddress`: Contains coordinates, address, contact info
- Helper methods for formatting price and time

**2. GrabDeliveryService** (`grab_delivery_service.dart`)
- `getDeliveryQuote()`: Calls backend API, falls back to mock on error
- `getMockDeliveryQuote()`: Distance-based mock calculation
- `calculateDistance()`: Haversine formula for distance calculation
- Automatically handles errors and fallbacks

**3. Delivery Controller** (`delivery_controller.dart`)
- `grabDeliveryServiceProvider`: Service instance provider
- `deliveryQuotesProvider`: FutureProvider for delivery quotes
- `DeliveryQuoteRequest`: Request model with origin, destination, branch ID, user ID

**4. Cart View** (`cart_view.dart`)
- Displays cart items
- Shows delivery toggle switch
- Fetches and displays delivery quotes
- Updates total price with delivery fee
- Uses selected branch automatically for pickup location

## Data Flow

```
┌─────────────────┐
│   Cart View     │
│  (User clicks   │
│   "Delivery")   │
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│ deliveryQuotesProvider  │
│ (Riverpod Provider)     │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│ GrabDeliveryService     │
│ getDeliveryQuote()      │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Backend API             │
│ POST /grab-quotes       │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Grab API                │
│ (Handled by backend)    │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Return quotes to user   │
│ (or mock if error)      │
└─────────────────────────┘
```

## Integration with Existing Code

### Branch Selection
The app automatically uses the selected branch:
```dart
final selectedBranch = ref.watch(selectedBranchProvider);
final restaurantLocation = DeliveryAddress(
  latitude: selectedBranch.latitude,
  longitude: selectedBranch.longitude,
  address: selectedBranch.address ?? selectedBranch.location,
  contactName: selectedBranch.outlet,
);
```

### Cart Total Calculation
Delivery fee is automatically included:
```dart
double get _deliveryFee => _selectedDeliveryQuote?.amount ?? 0;
double get _total => _subtotal + _tax + _service + _deliveryFee;
```

### Request Parameters
```dart
final deliveryRequest = DeliveryQuoteRequest(
  origin: restaurantLocation,      // From selected branch
  destination: _customerLocation,  // From user address (TODO)
  branchId: selectedBranch.id,    // Branch ID for backend
  userId: 1,                      // TODO: Get from auth
);
```

## Testing

### 1. **With Backend API**
1. Ensure backend is running at `https://delitopia.softindopp.com`
2. Backend must have Grab credentials configured
3. Open the app and add items to cart
4. Go to Cart page
5. Toggle "Delivery Options" switch
6. Wait for real delivery quotes from backend
7. Select a delivery option
8. Verify delivery fee is added to total

### 2. **Mock Data Testing (No Backend)**
1. If backend is unavailable, app automatically uses mock data
2. Open the app and add items to cart
3. Go to Cart page  
4. Toggle "Delivery Options" switch
5. See mock delivery quotes appear (calculated by distance)
6. Select a delivery option
7. Verify delivery fee is added to total

### 3. **Testing Different Scenarios**
- **No branch selected**: Should show "Please select a branch to enable delivery"
- **Backend unavailable**: Should fall back to mock quotes
- **No delivery quotes available**: Should show appropriate message
- **Network error**: Should display error and fall back to mock

## Troubleshooting

**Error: "Please select a branch to enable delivery"**
- Go to brand/branch selection page
- Select a brand and branch first
- Then go to cart and try delivery

**Error: "Failed to get delivery quote"**
- Backend API might be down
- Check network connection
- App will automatically fall back to mock quotes

**No delivery options shown**
- Toggle the "Delivery Options" switch
- Wait for API response (may take a few seconds)
- Check console for error messages

**Mock quotes showing instead of real quotes**
- Backend API is not responding
- Check backend endpoint is accessible
- Verify backend has Grab credentials configured

## Code Structure

## Future Enhancements

- [ ] Save customer delivery addresses
- [ ] Real-time delivery tracking
- [ ] Multiple pickup locations support
- [ ] Scheduled delivery times
- [ ] Delivery fee promotions
- [ ] Delivery instruction notes

## Documentation

- Grab API Docs: https://developer.grab.com/docs
- Support: https://developer.grab.com/support
