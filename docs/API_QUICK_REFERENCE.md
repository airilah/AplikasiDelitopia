# API Quick Reference for Delitopia V2

## 🚀 Quick Start

### Your Backend API Base URL
```
https://delitopia.softindopp.com/api
```

## 📍 Main API Endpoints

### Authentication
```
POST /auth/register          - Register new user
POST /auth/login             - Login with email/password
POST /auth/loginWithGoogle   - Login with Google
GET  /auth/me                - Get current user profile
POST /auth/token-validation  - Validate token
POST /auth/refresh           - Refresh token
```

### Menu & Products
```
GET  /getData/menu           - Get all menu items
GET  /getData/category       - Get categories
GET  /getData/brand          - Get brands
GET  /getData/branch         - Get branches
```

### Orders
```
POST /postData/order         - Create new order
GET  /getData/history-order  - Get order history
GET  /getData/order-detail   - Get order details
POST /postData/grab-quotes   - Get delivery fee quote (Grab API)
```

### Vouchers
```
GET  /getData/voucher        - Get available vouchers
POST /postData/use-voucher   - Apply voucher to order
```

### Notifications
```
POST /postData/fcm-token     - Update FCM token
GET  /getData/notifications  - Get notifications
```

### Profile
```
POST /postData/update-profile - Update user profile
POST /postData/update-email   - Update email
POST /postData/update-password - Update password
```

## 🔑 Headers Required

### For Authenticated Requests
```dart
{
  'Authorization': 'Bearer YOUR_TOKEN_HERE',
  'Content-Type': 'application/json',
  'Accept': 'application/json',
}
```

### For Form Data
```dart
{
  'Authorization': 'Bearer YOUR_TOKEN_HERE',
  'Content-Type': 'application/x-www-form-urlencoded',
}
```

## 📊 Key Data Models

### Order Request
```json
{
  "date": "2025-11-20",
  "grand_total": 150000,
  "discount": 10000,
  "final_total": 140000,
  "service": 5000,
  "tax": 15000,
  "order_type": "delivery",
  "pickup_time": "2025-11-20 14:00:00",
  "notes": "Extra spicy",
  "payment": "qris",
  "user_id": 1,
  "branch_id": 1,
  "delivery_fee": 15000,
  "deliver_address": "Jl. Example No. 123",
  "deliver_lat": -6.200000,
  "deliver_long": 106.816666,
  "details[0][menu_id]": 1,
  "details[0][qty]": 2,
  "details[0][total]": 50000
}
```

### Delivery Quote Request (Grab API)
```json
{
  "branch_id": 1,
  "destination": {
    "address": "Jl. Example No. 123",
    "lat": -6.200000,
    "lng": 106.816666
  },
  "user_id": 1,
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

## 🎯 Response Formats

### Success Response
```json
{
  "success": true,
  "message": "Operation successful",
  "data": { /* your data here */ }
}
```

### Error Response
```json
{
  "success": false,
  "message": "Error message here",
  "errors": { /* validation errors */ }
}
```

### Auth Response (Login/Register)
```json
{
  "token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "expired": "2025-12-20 10:00:00",
  "user": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com"
  }
}
```

## 📱 Firebase Configuration

### FCM (Push Notifications)
```dart
// Firebase Cloud Messaging
// Server Key: Found in Firebase Console → Project Settings → Cloud Messaging
// Send notifications via:
POST https://fcm.googleapis.com/fcm/send
Headers: {
  'Authorization': 'key=YOUR_SERVER_KEY',
  'Content-Type': 'application/json'
}
```

### Topics
```dart
// Subscribe to topics
'all'      - All users
'login'    - Logged in users
'promo'    - Promotional notifications
'order'    - Order updates
```

## 🗺️ Google Maps API

### Your API Key
```
GMAP_KEY=YOUR_GOOGLE_MAPS_API_KEY
```

### Usage
- Geocoding (address to coordinates)
- Reverse geocoding (coordinates to address)
- Distance calculation
- Map display

## 💳 Payment Methods

### Supported Types
```dart
{
  'qris': 'QRIS',
  'cash': 'Tunai / Cash',
  'ovo': 'OVO',
  'gopay': 'GoPay',
  'dana': 'DANA',
  'visa': 'Visa',
  'mastercard': 'Mastercard'
}
```

### Payment Flow
1. User selects payment method
2. For QRIS: Generate QR code via payment gateway
3. For Cash: Order goes to pending, paid at pickup/delivery
4. Order status updated after payment confirmation

## 📦 Order Status Flow

```
pending → paid → on_process → completed
                            ↓ (if delivery)
                  PENDING_PICKUP → PICKING_UP → 
                  PENDING_DROP_OFF → IN_DELIVERY → COMPLETED
```

### Status Codes
```dart
'pending'            - Waiting for payment
'paid'              - Payment confirmed
'on_process'        - Being prepared
'complete'          - Completed (pickup/dine-in)
'PENDING_PICKUP'    - Waiting for courier
'PICKING_UP'        - Courier going to restaurant
'PENDING_DROP_OFF'  - Ready for delivery
'IN_DELIVERY'       - On the way to customer
'COMPLETED'         - Delivered
```

## 🧮 Pricing Calculation

### Formula
```dart
// Step 1: Calculate subtotal
subtotal = sum of (item.price × item.quantity)

// Step 2: Calculate tax
tax = (subtotal × tax_percentage) / 100
// Example: (100000 × 11) / 100 = 11000

// Step 3: Calculate service (only for dine-in)
service = ((subtotal + tax) × service_percentage) / 100
// Example: ((100000 + 11000) × 5) / 100 = 5550

// Step 4: Add delivery fee (only for delivery)
delivery_fee = from Grab API

// Step 5: Apply voucher discount
discount = voucher discount amount or percentage

// Step 6: Calculate final total
final_total = subtotal + tax + service + delivery_fee - discount
```

### Example
```dart
Subtotal:     Rp 100,000
Tax (11%):    Rp  11,000
Service (5%): Rp   5,550  (only dine-in)
Delivery:     Rp  15,000  (only delivery)
Discount:     Rp -10,000  (if voucher applied)
─────────────────────────
Final Total:  Rp 121,550
```

## 🔐 Authentication Flow

1. **Register**: POST /auth/register → Returns token
2. **Login**: POST /auth/login → Returns token + user data
3. **Store Token**: Save in SharedPreferences
4. **Use Token**: Include in Authorization header
5. **Refresh**: When token expires, call /auth/refresh
6. **Logout**: Clear local token

## 📲 When to Call APIs

### On App Start
1. Check if token exists and valid (`/auth/token-validation`)
2. If valid, get user profile (`/auth/me`)
3. Get banners, categories, brands
4. Subscribe to FCM topics

### After Login
1. Get user profile
2. Update FCM token
3. Get order history
4. Get vouchers

### During Order
1. Select branch → Calculate distance
2. Select delivery → Get delivery fee quote
3. Apply voucher → Validate and calculate discount
4. Submit order → Create order
5. Track order → Poll order status or listen to FCM

## 🚨 Common Error Handling

```dart
// 401 Unauthorized - Token invalid/expired
if (response.statusCode == 401) {
  // Refresh token or logout
  await refreshToken();
}

// 404 Not Found
if (response.statusCode == 404) {
  // Resource not found
  showError('Item not found');
}

// 422 Validation Error
if (response.statusCode == 422) {
  // Show validation errors
  final errors = response.data['errors'];
}

// 500 Server Error
if (response.statusCode == 500) {
  // Server error, retry later
  showError('Server error. Please try again.');
}
```

## 💡 Best Practices

1. **Always include error handling** for API calls
2. **Cache responses** where appropriate (menu, categories)
3. **Show loading states** during API calls
4. **Retry logic** for failed network requests
5. **Token refresh** before expiration
6. **Validate data** before sending to API
7. **Use Dio interceptors** for common headers/error handling

## 🔗 Quick Links

- Backend API: https://delitopia.softindopp.com/api
- Firebase Console: https://console.firebase.google.com
- Grab Developer: https://developer.grab.com
- Google Maps: https://console.cloud.google.com

---

**For detailed implementation, see:**
- `GRAB_API_IMPLEMENTATION.md` - Grab delivery integration
- `GETTING_STARTED.md` - Project setup guide
- `README.md` - Full project documentation
