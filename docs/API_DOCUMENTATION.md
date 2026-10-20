# Delitopia API Documentation

Base URL: `https://delitopia.softindopp.com/api`

## Authentication
All authenticated endpoints require JWT token in the Authorization header:
```
Authorization: Bearer {your-jwt-token}
```

---

## Order Endpoints

### 1. Create Order (Method A)
Create a new order with payment processing.

**Endpoint:** `POST /orders`

**Headers:**
```json
{
  "Content-Type": "application/json",
  "Authorization": "Bearer {jwt-token}"
}
```

**Request Body:**
```json
{
  "date": "2025-11-18",
  "grand_total": 100000,
  "final_total": 77000,
  "discount": 0,
  "tax": 7000,
  "service": 10000,
  "order_type": "dine in",
  "notes": "Extra spicy",
  "pickup_time": "12:00",
  "payment": "qris",
  "user_id": 22,
  "branch_id": 89,
  "table_number": "A5",
  "promo_id": null,
  "user_voucher_id": null,
  "deliver_address": null,
  "deliver_lat": null,
  "deliver_long": null,
  "details": [
    {
      "menu_id": 1,
      "menu_code": "M001",
      "notes": "No onions",
      "qty": 2,
      "total": 50000
    },
    {
      "menu_id": 2,
      "menu_code": "M002",
      "notes": null,
      "qty": 1,
      "total": 27000
    }
  ]
}
```

**Field Descriptions:**
- `date` (required): Order date in YYYY-MM-DD format
- `grand_total` (required): Total before discount/tax/service
- `final_total` (required): Final amount to be paid
- `discount` (optional): Discount amount
- `tax` (required): Tax amount
- `service` (required): Service charge amount
- `order_type` (required): "dine in" or "take away" or "delivery"
- `notes` (optional): Order notes
- `pickup_time` (optional): Time for pickup (HH:MM format)
- `payment` (required): Payment method - "qris", "cash", or "qr" (case insensitive, will be converted to uppercase)
- `user_id` (required): User ID
- `branch_id` (required): Branch ID
- `table_number` (required): Table number
- `promo_id` (optional): Promo ID if applicable
- `user_voucher_id` (optional): User voucher ID if applicable
- `deliver_address` (optional): Delivery address
- `deliver_lat` (optional): Delivery latitude
- `deliver_long` (optional): Delivery longitude
- `details` (required): Array of order items
  - `menu_id` (required): Menu item ID
  - `menu_code` (optional): Menu item code
  - `notes` (optional): Item-specific notes
  - `qty` (required): Quantity
  - `total` (required): Total price for this item

**Success Response (QRIS Payment):**
```json
{
  "status": "success",
  "data": {
    "payment_method": "QRIS",
    "qr_string": "00020101021226670016COM.NOBUBANK.WWW01189360050300000902920214159484912761060303UBE51440014ID.CO.QRIS.WWW0215ID20253708798060303UBE5204581253033605405770005802ID5909Delitopia6008SURABAYA6105601886261011481027533708859062476141420_ORD-89-02-000080703A010804POSP6304E9DA",
    "expired_time": "2025-11-18T10:42:53.255+07:00",
    "transaction_id": "019a9501-2ba4-708d-b823-58eacce57730",
    "external_id": "D3L1T0P1A-251118-22-679",
    "order_id": "ORD-89-02-00008"
  },
  "message": "success create payment"
}
```

**Success Response (Cash Payment):**
```json
{
  "status": "success",
  "data": {
    "payment_method": "CASH",
    "order_id": "ORD-89-02-00008",
    "response": {
      "status": "success",
      "message": "Transaction recorded"
    }
  },
  "message": "Order has been created successfully."
}
```

**Error Response:**
```json
{
  "status": "failed",
  "message": "The user_id field is required."
}
```

**Status Codes:**
- `200`: Success
- `400`: Validation error or failed to create order
- `404`: Branch not found

---

### 2. Create Order (Method B - With Delivery)
Create a new order with delivery fee support.

**Endpoint:** `POST /orders/b`

**Request Body:**
```json
{
  "date": "2025-11-18",
  "grand_total": 100000,
  "final_total": 87000,
  "discount": 0,
  "tax": 7000,
  "delivery_fee": 10000,
  "service": 10000,
  "order_type": "delivery",
  "notes": "Please call when arrived",
  "pickup_time": null,
  "payment": "qris",
  "user_id": 22,
  "branch_id": 89,
  "table_number": "-",
  "promo_id": null,
  "user_voucher_id": null,
  "deliver_address": "Jl. Example No. 123, Surabaya",
  "deliver_lat": -7.250445,
  "deliver_long": 112.768845,
  "details": [
    {
      "menu_id": 1,
      "menu_code": "M001",
      "notes": "Extra sauce",
      "qty": 2,
      "total": 50000
    }
  ]
}
```

**Additional Field:**
- `delivery_fee` (optional): Delivery fee amount

**Success Response:** Same as Create Order Method A

---

### 3. Get Order Details
Retrieve order information by user ID and type.

**Endpoint:** `GET /orders/show`

**Query Parameters:**
```
user_id=22
type=status
status=pending
```

OR

```
user_id=22
type=order_id
order_id=ORD-89-02-00008
```

**Parameters:**
- `user_id` (required): User ID
- `type` (required): Query type - "status" or "order_id"
- `status` (optional): Order status - "pending" or "success"
- `order_id` (optional): Specific order ID (required if type=order_id)

**Success Response (Single Order):**
```json
{
  "status": "success",
  "data": [
    {
      "id": 123,
      "date": "2025-11-18",
      "order_id": "ORD-89-02-00008",
      "order_type": "dine in",
      "grand_total": 100000,
      "final_total": 77000,
      "service": 10000,
      "tax": 7000,
      "delivery_fee": 0,
      "notes": "Extra spicy",
      "pickup_time": "12:00",
      "payment": "QRIS",
      "pg_qr_string": "00020101021226670016COM.NOBUBANK.WWW...",
      "pg_expired_qr": "2025-11-18T10:42:53.255+07:00",
      "status": "pending",
      "point": 0,
      "user_id": 22,
      "branch_id": 89,
      "table_number": "A5",
      "promo_id": null,
      "user_voucher_id": null,
      "voucher_name": null,
      "voucher_type": null,
      "created_at": "2025-11-18T03:27:53.000000Z",
      "updated_at": "2025-11-18T03:27:53.000000Z",
      "brand_name": "Delitopia",
      "brand_/Volumes/T7/ordering_food/API_DOCUMENTATION_COMPLETE.mdo": "https://example.com/logo.png",
      "branch_address": "Jl. Example No. 123, Surabaya",
      "track_url": null,
      "details": [
        {
          "id": 456,
          "order_id": 123,
          "menu_id": 1,
          "menu_name": "Nasi Goreng Special",
          "notes": "No onions",
          "qty": 2,
          "total": 50000,
          "created_at": "2025-11-18T03:27:53.000000Z",
          "updated_at": "2025-11-18T03:27:53.000000Z"
        }
      ]
    }
  ],
  "message": "History order retrieved successfully"
}
```

**Success Response (Grouped by Date - for status=success):**
```json
{
  "status": "success",
  "data": [
    {
      "date": "2025-11-18",
      "orders": [
        {
          "id": 123,
          "order_id": "ORD-89-02-00008",
          "status": "paid",
          // ... other fields
        }
      ]
    },
    {
      "date": "2025-11-17",
      "orders": [
        {
          "id": 122,
          "order_id": "ORD-89-02-00007",
          "status": "completed",
          // ... other fields
        }
      ]
    }
  ],
  "message": "Completed orders grouped by date retrieved successfully"
}
```

**Error Response:**
```json
{
  "status": "error",
  "message": "No orders found for this user."
}
```

**Status Codes:**
- `200`: Success
- `404`: No orders found

---

### 4. Mark Order as Paid
Update order status from pending to paid.

**Endpoint:** `POST /orders/mark-paid`

**Request Body:**
```json
{
  "order_id": "ORD-89-02-00008"
}
```

**Success Response:**
```json
{
  "status": "success",
  "message": "Order status updated to paid"
}
```

**Error Responses:**
```json
{
  "status": "failed",
  "message": "Order not found"
}
```

```json
{
  "status": "failed",
  "message": "Order is already paid or has a different status"
}
```

**Status Codes:**
- `200`: Success
- `400`: Order already paid or invalid status
- `404`: Order not found

---

### 5. Update Order Status
Update order status to paid or completed.

**Endpoint:** `POST /orders/update-status`

**Request Body:**
```json
{
  "order_id": "ORD-89-02-00008",
  "status": "paid"
}
```

**Parameters:**
- `order_id` (required): Order ID
- `status` (required): New status - "paid" or "completed"

**Valid Status Transitions:**
- `pending` → `paid` or `completed`
- `paid` → `completed`
- `completed` → (final status, no further transitions)

**Success Response:**
```json
{
  "status": "success",
  "message": "Order status updated to paid"
}
```

**Error Responses:**
```json
{
  "status": "failed",
  "message": "Order not found"
}
```

```json
{
  "status": "failed",
  "message": "Cannot revert to pending status"
}
```

```json
{
  "status": "failed",
  "message": "Invalid status transition from paid to pending"
}
```

**Status Codes:**
- `200`: Success
- `400`: Invalid status transition
- `404`: Order not found

---

## Points Endpoints

### 6. Get Point History (Deprecated)
Get historical points for a user by phone number.

**Endpoint:** `GET /orders/point`

**Query Parameters:**
```
user_phone=08123456789
grand_total=100000
```

**Success Response:**
```json
{
  "status": "success",
  "data": [
    {
      "point": "15",
      "expired_at": "2026-11-28"
    },
    {
      "point": "7",
      "expired_at": "2026-12-28"
    }
  ],
  "message": "History points retrieved successfully"
}
```

**Empty Response:**
```json
{
  "status": "success",
  "data": [],
  "message": "No history points found for this user."
}
```

---

### 7. Get Valid Point History
Get valid (not expired) points for a user.

**Endpoint:** `GET /orders/history-point`

**Query Parameters:**
```
user_id=22
```

**Success Response:**
```json
{
  "status": "success",
  "data": [
    {
      "expired_at": "2026-11-28",
      "point": "15"
    },
    {
      "expired_at": "2026-12-28",
      "point": "7"
    }
  ],
  "message": "Valid history points retrieved successfully"
}
```

**Empty Response:**
```json
{
  "status": "success",
  "data": [],
  "message": "No valid history points found for this user."
}
```

---

## Common Response Structures

### Order Status Values
- `pending`: Order created, waiting for payment
- `paid`: Payment confirmed
- `completed`: Order fulfilled
- `expired`: Order expired (not paid within time limit)
- `failed`: Order failed

### Payment Method Values (ENUM - Case Insensitive on Input)
- `QRIS`: QR Code payment via MC Payment
- `CASH`: Cash payment
- `QR`: QR payment (alternative)

### Order Type Values
- `dine in`: Eat at restaurant
- `take away`: Take away order
- `delivery`: Delivery order

### Point Calculation
Points are calculated based on grand_total:
```
points = floor(grand_total / 10000)
```
Example: 
- Rp 77,000 = 7 points
- Rp 100,000 = 10 points

Points expire 1 year + set to day 28 from order date.

---

## Error Codes Reference

### HTTP Status Codes
- `200`: Success
- `400`: Bad Request (validation error, invalid data)
- `401`: Unauthorized (invalid or missing JWT token)
- `404`: Not Found (resource doesn't exist)
- `500`: Internal Server Error

### Common Validation Errors
```json
{
  "status": "failed",
  "message": "The date field is required."
}
```

```json
{
  "status": "failed",
  "message": "The selected user_id is invalid."
}
```

```json
{
  "status": "failed",
  "message": "The details field must be an array."
}
```

---

## Payment Flow

### QRIS Payment Flow
1. Create order with `payment: "qris"`
2. API returns QR code string and expiration time
3. Display QR code to user
4. User scans and pays via e-wallet
5. Payment gateway sends callback to server
6. Order status updates to "paid"
7. User receives confirmation

### Cash Payment Flow
1. Create order with `payment: "cash"`
2. Order created with status "pending"
3. Staff manually confirms payment
4. Call `/orders/mark-paid` or `/orders/update-status`
5. Order status updates to "paid"
6. Points are calculated and added to user account

---

## Notes

### Important Implementation Details

1. **Payment Method**: Always send payment method in any case (uppercase, lowercase, mixed). The API will automatically convert it to uppercase to match database ENUM values.

2. **Order ID Format**: 
   - Format: `ORD-{branch_id}-{order_type_code}-{count}`
   - Example: `ORD-89-02-00008`
   - Order type codes: `01` = dine in, `02` = take away/delivery

3. **External ID Format**: 
   - Format: `D3L1T0P1A-{YYMMDD}-{user_id}-{random3digits}`
   - Example: `D3L1T0P1A-251118-22-679`

4. **QR Code Expiration**: QR codes typically expire 15 minutes after generation. Check `expired_time` field.

5. **Vouchers**: When a voucher is used (`user_voucher_id` provided):
   - Status is set to "used"
   - If voucher type is "birthday", all birthday vouchers for that user are marked as used

6. **Points System**:
   - Points are only calculated when order status is updated to "paid"
   - Points expire after 1 year (on day 28 of the month)
   - User's total points are recalculated from all non-expired orders

7. **Delivery Support**: Use `/orders/b` endpoint for delivery orders to support `delivery_fee` field.

---

## Flutter Implementation Tips

### 1. QR Code Display
Use the `qr_flutter` package:
```dart
import 'package:qr_flutter/qr_flutter.dart';

QrImageView(
  data: response['data']['qr_string'],
  version: QrVersions.auto,
  size: 200.0,
)
```

### 2. Countdown Timer for QR Expiration
```dart
DateTime expiryTime = DateTime.parse(response['data']['expired_time']);
Duration remaining = expiryTime.difference(DateTime.now());

// Use Timer or CountdownTimer package
```

### 3. Payment Status Polling
```dart
// Poll order status every 3-5 seconds
Timer.periodic(Duration(seconds: 3), (timer) async {
  final status = await checkOrderStatus(orderId);
  if (status == 'paid') {
    timer.cancel();
    // Show success screen
  }
});
```

### 4. Error Handling
```dart
try {
  final response = await createOrder(orderData);
  if (response['status'] == 'success') {
    // Handle success
  } else {
    // Show error message
    showError(response['message']);
  }
} catch (e) {
  showError('Network error: $e');
}
```

### 5. Model Classes
```dart
class Order {
  final int id;
  final String orderId;
  final String orderType;
  final double grandTotal;
  final double finalTotal;
  final String payment;
  final String status;
  final String? qrString;
  final DateTime? qrExpiredTime;
  final List<OrderDetail> details;
  
  Order.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      orderId = json['order_id'],
      // ... map other fields
}

class QRISPaymentResponse {
  final String paymentMethod;
  final String qrString;
  final DateTime expiredTime;
  final String transactionId;
  final String externalId;
  final String orderId;
  
  QRISPaymentResponse.fromJson(Map<String, dynamic> json)
    : paymentMethod = json['payment_method'],
      qrString = json['qr_string'],
      // ... map other fields
}
```

---

## Testing Credentials

**MC Payment Test Merchant:**
- Merchant ID: `MC2024103198`
- Environment: Live
- Endpoint: `https://api-live.mcpayment.id/ewallet/v2/create-qr`

**Test User:**
- User ID: 22
- Branch ID: 89

---

## Changelog

**Version 1.0 (2025-11-18)**
- Initial API documentation
- QRIS payment integration
- Points system
- Order management endpoints
- Voucher support

---

## Support

For technical support or questions:
- Email: delitopiagroup@gmail.com
- Documentation: This file
- Laravel Logs: `/storage/logs/laravel.log`
