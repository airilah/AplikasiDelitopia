# Complete Cart to Order & Payment Flow Documentation

## Table of Contents
1. [System Overview](#system-overview)
2. [Database Schema](#database-schema)
3. [Flow Diagram](#flow-diagram)
4. [Cart System](#cart-system)
5. [Order Creation](#order-creation)
6. [Payment Processing](#payment-processing)
7. [Payment Callback (QRIS)](#payment-callback-qris)
8. [Order Status Management](#order-status-management)
9. [Complete API Examples](#complete-api-examples)
10. [Mobile App Integration](#mobile-app-integration)
11. [Error Handling](#error-handling)

---

## System Overview

The ordering system follows this flow:

```
Cart Management → Order Creation → Payment Processing → Payment Callback → Order Fulfillment
```

### Key Features
- **Dual Menu System Support**: Works with both old menu system (menu_id) and new menu template system (template_code/branch_menu_item_id)
- **Multiple Payment Methods**: QRIS, Cash, Virtual Account (via E-Smartlink)
- **Multi-Brand Support**: Different payment gateways per brand
- **Points System**: Automatic point calculation (1 point per Rp 10,000)
- **Voucher Integration**: Supports voucher application and redemption
- **Delivery Integration**: GrabExpress integration for delivery orders
- **Real-time Callback**: Automatic order status update via payment gateway callback

---

## Database Schema

### 1. Carts Table
```sql
CREATE TABLE carts (
    id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    branch_id BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE CASCADE
);
```

### 2. Cart Items Table
```sql
CREATE TABLE cart_items (
    id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    cart_id BIGINT UNSIGNED NOT NULL,
    
    -- OLD SYSTEM FIELDS
    menu_id BIGINT NULL,
    
    -- NEW SYSTEM FIELDS
    branch_menu_item_id BIGINT UNSIGNED NULL,
    menu_template_id BIGINT UNSIGNED NULL,
    
    -- COMMON FIELDS
    qty INT NOT NULL DEFAULT 1,
    price DOUBLE(8,2) NOT NULL,
    notes TEXT NULL,
    customizations JSON NULL,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    
    FOREIGN KEY (cart_id) REFERENCES carts(id) ON DELETE CASCADE,
    FOREIGN KEY (menu_id) REFERENCES menus(id) ON DELETE CASCADE,
    FOREIGN KEY (branch_menu_item_id) REFERENCES branch_menu_items(id) ON DELETE CASCADE,
    FOREIGN KEY (menu_template_id) REFERENCES menu_templates(id) ON DELETE CASCADE
);
```

### 3. Orders Table
```sql
CREATE TABLE orders (
    id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    date DATE NOT NULL,
    order_id VARCHAR(255) NOT NULL UNIQUE,
    order_type VARCHAR(50) NOT NULL, -- 'dine in', 'delivery', 'takeaway'
    grand_total DOUBLE(10,2) NOT NULL,
    final_total DOUBLE(10,2) NOT NULL,
    discount DOUBLE(10,2) NULL,
    tax DOUBLE(10,2) NOT NULL,
    delivery_fee DOUBLE(10,2) NULL,
    service DOUBLE(10,2) NOT NULL,
    notes TEXT NULL,
    pickup_time VARCHAR(50) NULL,
    payment ENUM('CASH', 'QRIS', 'TRANSFER', 'DEBIT', 'CREDIT') NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, paid, processing, ready, completed, cancelled, expired
    point INT DEFAULT 0,
    user_voucher_id BIGINT UNSIGNED NULL,
    expired_at DATE NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    branch_id BIGINT UNSIGNED NOT NULL,
    table_number VARCHAR(50) NOT NULL,
    promo_id BIGINT UNSIGNED NULL,
    
    -- QRIS PAYMENT FIELDS
    pg_qr_string TEXT NULL,
    pg_expired_qr TIMESTAMP NULL,
    
    -- DELIVERY FIELDS
    deliver_address TEXT NULL,
    deliver_lat DECIMAL(10,8) NULL,
    deliver_long DECIMAL(11,8) NULL,
    deliver_id VARCHAR(255) NULL,
    
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE CASCADE,
    FOREIGN KEY (user_voucher_id) REFERENCES detail_vouchers(id) ON DELETE SET NULL,
    FOREIGN KEY (promo_id) REFERENCES promos(id) ON DELETE SET NULL
);
```

### 4. Detail Orders Table
```sql
CREATE TABLE detail_orders (
    id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    order_id BIGINT UNSIGNED NOT NULL,
    menu_id BIGINT UNSIGNED NOT NULL,
    menu_code VARCHAR(50) NULL,
    notes TEXT NULL,
    qty INT NOT NULL,
    total DOUBLE(10,2) NOT NULL,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (menu_id) REFERENCES menus(id) ON DELETE CASCADE
);
```

### 5. Payment Callbacks Table
```sql
CREATE TABLE payment_callbacks (
    id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    order_id BIGINT UNSIGNED NOT NULL,
    transaction_id VARCHAR(255) UNIQUE NOT NULL,
    channel VARCHAR(50) NOT NULL, -- QRIS, VA_BNI, WALLET_OVO, etc.
    amount DECIMAL(15,2) NOT NULL,
    status VARCHAR(50) DEFAULT 'PENDING', -- PENDING, SUCCESS, FAILED, EXPIRED, CANCELLED
    payment_code VARCHAR(255) NULL,
    payment_url TEXT NULL,
    qr_string TEXT NULL,
    expired_time TIMESTAMP NULL,
    payment_time TIMESTAMP NULL,
    callback_data JSON NULL,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    INDEX (transaction_id, status)
);
```

---

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CART TO ORDER FLOW                           │
└─────────────────────────────────────────────────────────────────────┘

1. CART MANAGEMENT
   ↓
   User adds items to cart
   ├─ OLD SYSTEM: menu_id or menu_code
   └─ NEW SYSTEM: template_code + branch_id OR branch_menu_item_id
   ↓
   Cart stored in database
   ├─ Cart created for user + branch
   └─ CartItems linked to cart

2. CHECKOUT / ORDER CREATION
   ↓
   User initiates checkout
   ├─ Validates cart items
   ├─ Calculates totals (tax, service, discount)
   ├─ Applies voucher (if any)
   └─ Generates order_id
   ↓
   POST /api/postData/order
   ├─ Payment = QRIS → Creates QRIS payment
   │  ├─ Calls PaymentGatewayService
   │  ├─ Brand-specific gateway OR default McPayment
   │  ├─ Generates QR string
   │  └─ Returns QR string + expired_time
   │
   └─ Payment = CASH → Direct order creation
      └─ Sends to external POS API

3. PAYMENT PROCESSING (QRIS)
   ↓
   User scans QR code
   ├─ QR displayed in app
   ├─ User scans with banking app
   └─ Payment gateway processes payment
   ↓
   Payment Gateway Status
   ├─ PENDING → Waiting for payment
   ├─ PAID → Payment successful
   └─ EXPIRED → QR code expired

4. PAYMENT CALLBACK (WEBHOOK)
   ↓
   Payment Gateway sends callback to:
   POST /api/payment/callback
   ↓
   PaymentCallbackController processes:
   ├─ Validates callback data
   ├─ Saves to payment_callbacks table
   └─ Updates order status
   ↓
   IF STATUS = PAID:
   ├─ Order.status → 'paid'
   ├─ Calculate points (grand_total / 10000)
   ├─ Create Point record
   ├─ Update User.point
   ├─ Mark voucher as 'used'
   ├─ Send to external POS API
   └─ IF delivery → Create GrabExpress order
   ↓
   IF STATUS = EXPIRED:
   └─ Order.status → 'expired'

5. ORDER FULFILLMENT
   ↓
   Restaurant processes order
   ├─ Order status: paid → processing → ready → completed
   └─ Admin updates status via dashboard

6. DELIVERY (IF APPLICABLE)
   ↓
   GrabExpress Integration
   ├─ Created automatically on payment success
   ├─ Webhook updates from Grab
   └─ deliver_id stored in orders table
```

---

## Cart System

### API Endpoints

#### 1. Get Cart
```http
GET /api/cart
Authorization: Bearer {token}
```

**Response (Empty Cart):**
```json
{
  "status": "success",
  "data": {
    "cart": null,
    "items": [],
    "total_items": 0,
    "subtotal": 0
  },
  "message": "Cart is empty"
}
```

**Response (With Items):**
```json
{
  "status": "success",
  "data": {
    "cart": {
      "id": 1,
      "user_id": 123,
      "branch_id": 90,
      "created_at": "2025-12-01T10:00:00.000000Z",
      "updated_at": "2025-12-01T10:30:00.000000Z"
    },
    "items": [
      {
        "id": 1,
        "cart_id": 1,
        "menu_id": null,
        "branch_menu_item_id": 456,
        "menu_template_id": 789,
        "qty": 2,
        "price": 50000,
        "notes": "No ice",
        "customizations": {"sugar_level": "50%"},
        "menu": {
          "id": 456,
          "name": "Ice Coffee",
          "price": 50000
        }
      }
    ],
    "total_items": 2,
    "subtotal": 100000
  },
  "message": "Cart retrieved successfully"
}
```

#### 2. Add Item to Cart

**OLD SYSTEM (Using menu_code):**
```http
POST /api/cart/add
Authorization: Bearer {token}
Content-Type: application/json

{
  "menu_code": "IC-001",
  "qty": 2,
  "notes": "Less sugar please",
  "customizations": {
    "sugar_level": "50%",
    "ice_level": "normal"
  }
}
```

**NEW SYSTEM (Using template_code + branch_id):**
```http
POST /api/cart/add
Authorization: Bearer {token}
Content-Type: application/json

{
  "template_code": "IC-001",
  "branch_id": 90,
  "qty": 2,
  "notes": "Less sugar please",
  "customizations": {
    "sugar_level": "50%",
    "ice_level": "normal"
  }
}
```

**NEW SYSTEM (Using branch_menu_item_id - Most Specific):**
```http
POST /api/cart/add
Authorization: Bearer {token}
Content-Type: application/json

{
  "branch_menu_item_id": 456,
  "qty": 2,
  "notes": "Less sugar please"
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "cart_item": {
      "id": 1,
      "cart_id": 1,
      "branch_menu_item_id": 456,
      "menu_template_id": 789,
      "qty": 2,
      "price": 50000,
      "notes": "Less sugar please",
      "system": "new"
    },
    "cart": {
      "id": 1,
      "total_items": 2,
      "subtotal": 100000
    }
  },
  "message": "Item added to cart successfully"
}
```

#### 3. Update Cart Item
```http
PUT /api/cart/update/{item_id}
Authorization: Bearer {token}
Content-Type: application/json

{
  "qty": 3,
  "notes": "Extra ice",
  "customizations": {
    "sugar_level": "75%"
  }
}
```

#### 4. Remove Item from Cart
```http
DELETE /api/cart/remove/{item_id}
Authorization: Bearer {token}
```

#### 5. Clear Cart
```http
DELETE /api/cart/clear
Authorization: Bearer {token}
```

---

## Order Creation

### API Endpoint

```http
POST /api/postData/order
Authorization: Bearer {token}
Content-Type: application/json
```

### Request Body

```json
{
  "date": "2025-12-01",
  "grand_total": 100000,
  "final_total": 95000,
  "discount": 5000,
  "tax": 10000,
  "service": 5000,
  "order_type": "dine in",
  "notes": "Please deliver to table 5",
  "pickup_time": "12:30",
  "payment": "QRIS",
  "user_id": 123,
  "branch_id": 90,
  "table_number": "T-05",
  "promo_id": null,
  "user_voucher_id": 456,
  "details": [
    {
      "menu_id": 408,
      "menu_code": "IC-001",
      "notes": "No ice",
      "qty": 2,
      "total": 100000
    }
  ],
  "deliver_address": null,
  "deliver_lat": null,
  "deliver_long": null
}
```

### Request Fields Explanation

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| date | date | ✅ | Order date (YYYY-MM-DD) |
| grand_total | number | ✅ | Subtotal before tax/service/discount |
| final_total | number | ✅ | Total after all calculations |
| discount | number | ❌ | Discount amount (from voucher/promo) |
| tax | number | ✅ | Tax amount (PB1 10%) |
| service | number | ✅ | Service charge |
| order_type | string | ✅ | "dine in", "delivery", "takeaway" |
| notes | string | ❌ | Special instructions |
| pickup_time | string | ❌ | Estimated pickup time |
| payment | string | ✅ | "QRIS", "CASH", "TRANSFER", "DEBIT", "CREDIT" |
| user_id | number | ✅ | User ID |
| branch_id | number | ✅ | Branch ID |
| table_number | string | ✅ | Table number or identifier |
| promo_id | number | ❌ | Promo ID if applied |
| user_voucher_id | number | ❌ | User's voucher ID if used |
| details | array | ✅ | Array of order items |
| deliver_address | string | ❌ | Delivery address (required if order_type = "delivery") |
| deliver_lat | number | ❌ | Delivery latitude |
| deliver_long | number | ❌ | Delivery longitude |

### Response (QRIS Payment)

```json
{
  "status": "success",
  "data": {
    "payment_method": "QRIS",
    "qr_string": "00020101021226670016COM.NOBUBANK.WWW01189360091600009121...",
    "expired_time": "2025-12-01T12:15:00.000000Z",
    "transaction_id": "TRX-20251201-123456",
    "external_id": "D3L1T0P1A-251201-123-456",
    "order_id": "ORD-90-01-00001"
  },
  "message": "success create payment"
}
```

### Response (Cash Payment)

```json
{
  "status": "success",
  "data": {
    "payment_method": "CASH",
    "order_id": "ORD-90-01-00001",
    "response": {
      "status": "success",
      "transaction_id": "TRX-CASH-001"
    }
  },
  "message": "Order has been created successfully."
}
```

### Order ID Format

```
ORD-{branch_id}-{order_type_code}-{sequence}

Examples:
- ORD-90-01-00001  (Dine in at branch 90)
- ORD-05-02-00123  (Delivery at branch 5)

Order Type Codes:
- 01: Dine in
- 02: Delivery / Takeaway
```

### External ID Format

```
D3L1T0P1A-{date}-{user_id}-{random}

Example:
D3L1T0P1A-251201-123-456
- 251201: Date (YYMMDD)
- 123: User ID
- 456: Random 3-digit code
```

---

## Payment Processing

### Payment Gateway Service

The system uses `PaymentGatewayService` which supports:

1. **McPayment** (Default)
   - QRIS payments
   - Live credentials configured per brand or uses default

2. **E-Smartlink** (Multi-channel)
   - QRIS (WALLET_QRIS)
   - Virtual Account (VA_BNI, VA_BRI, VA_MANDIRI, VA_PERMATA)
   - E-Wallet (WALLET_OVO, WALLET_DANA, WALLET_LINKAJA, WALLET_SHOPEEPAY)
   - Over-the-Counter (OTC_INDOMARET, OTC_ALFAMART)

### Payment Gateway Selection

```php
// Automatic gateway detection by brand
$branch = Branch::find($branch_id);
$paymentGateway = $paymentGatewayService->getCredentialsByBrand($branch->brand_id);

// Create payment
$paymentData = $paymentGatewayService->createQRISPayment($paymentGateway, [
    'external_id' => $external_id,
    'order_id' => $order_id,
    'amount' => $final_total,
    'description' => 'Order payment for ' . $order_id,
    'customer_email' => $user->email,
    'customer_name' => $user->name,
]);
```

### QRIS Payment Flow

```
1. Order created with payment = 'QRIS'
   ↓
2. PaymentGatewayService.createQRISPayment() called
   ├─ Generates signature
   ├─ Calls MC Payment API
   └─ Returns QR string
   ↓
3. QR string saved to orders.pg_qr_string
   ↓
4. QR string returned to app
   ↓
5. App displays QR code
   ↓
6. User scans with banking app
   ↓
7. Payment gateway processes payment
   ↓
8. Callback sent to /api/payment/callback
```

### QRIS Request Structure

```json
{
  "external_id": "D3L1T0P1A-251201-123-456",
  "order_id": "ORD-90-01-00001",
  "currency": "IDR",
  "payment_method": "wallet",
  "payment_channel": "NOBU",
  "payment_details": {
    "amount": 95000,
    "transaction_description": "Order payment for ORD-90-01-00001"
  },
  "customer_details": {
    "email": "customer@example.com",
    "full_name": "John Doe"
  },
  "wallet_details": {
    "id": "685606901022",
    "id_type": "HP"
  },
  "callback_url": "https://delitopia.softindopp.com/api/payment/callback"
}
```

### QRIS Response Structure

```json
{
  "response_code": "00",
  "response_message": "Success",
  "external_id": "D3L1T0P1A-251201-123-456",
  "order_id": "ORD-90-01-00001",
  "transaction_id": "TRX-20251201-123456",
  "qr_response": {
    "qr_string": "00020101021226670016COM.NOBUBANK.WWW01189360091600009121..."
  },
  "payment_details": {
    "amount": 95000,
    "currency": "IDR",
    "expired_time": "2025-12-01T12:15:00.000000Z"
  }
}
```

---

## Payment Callback (QRIS)

### Callback Endpoint

```http
POST /api/payment/callback
Content-Type: application/json
```

**This endpoint receives callbacks from the payment gateway (NO AUTH REQUIRED)**

### Callback Request Body

```json
{
  "external_id": "D3L1T0P1A-251201-123-456",
  "order_id": "ORD-90-01-00001",
  "transaction_status": "PAID",
  "payment_details": {
    "paid_time": "2025-12-01T11:45:30.000000Z",
    "amount": 95000,
    "currency": "IDR"
  },
  "reference_id": "REF-20251201-789012",
  "response_code": "00"
}
```

### Transaction Status Values

| Status | Description | Action |
|--------|-------------|--------|
| PAID | Payment successful | Update order to 'paid', create points, send to POS |
| PENDING | Payment pending | No action, wait for final status |
| EXPIRED | Payment expired | Update order to 'expired' |
| FAILED | Payment failed | Update order to 'failed' |
| CANCELLED | Payment cancelled | Update order to 'cancelled' |

### Callback Processing Flow

```
1. Callback received at /api/payment/callback
   ↓
2. Validate callback data
   ├─ external_id (required)
   ├─ order_id (required)
   ├─ transaction_status (required)
   └─ reference_id (required)
   ↓
3. Save to payment_callbacks table
   ↓
4. Find order by order_id
   ↓
5. IF transaction_status = 'PAID':
   ├─ Calculate points (grand_total / 10000)
   ├─ Update order.status = 'paid'
   ├─ Update order.point = calculated_points
   ├─ Create Point record
   │  ├─ user_id
   │  ├─ point (amount)
   │  ├─ type = 'earned'
   │  ├─ order_id
   │  └─ expired_at (1 year from order)
   ├─ Update User.point (sum of active points)
   ├─ Mark voucher as 'used' (if applicable)
   ├─ Send order to external POS API
   └─ IF delivery order:
      ├─ Build GrabExpress payload
      ├─ Call GrabService.createDelivery()
      └─ Save deliver_id to order
   ↓
6. IF transaction_status = 'EXPIRED':
   └─ Update order.status = 'expired'
   ↓
7. Return response 200 OK
```

### Points Calculation

```php
// Calculate points (1 point per Rp 10,000)
$points = floor($order->grand_total / 10000);

// Example:
// Rp 95,000 → 9 points
// Rp 105,000 → 10 points
// Rp 9,999 → 0 points
```

### Points Record Creation

```json
{
  "user_id": 123,
  "point": 9,
  "description": "Points earned from order ORD-90-01-00001",
  "order_id": "ORD-90-01-00001",
  "type": "earned",
  "expired_at": "2026-12-28"
}
```

### User Activity Log

```json
{
  "user_id": 123,
  "activity_type": "points_earned",
  "description": "Earned 9 points from order ORD-90-01-00001",
  "metadata": {
    "order_id": "ORD-90-01-00001",
    "points": 9,
    "order_amount": 95000
  }
}
```

### External POS API Integration

After payment success, order is sent to external POS system:

```http
POST https://sales.mannagroup.id/api/transaksi/penjualan/insert
X-Token: b0ca69a138c931feefcb53961262e7d69e43b249ffce07373fdca3e1d7e42071d84c48c2557a4659671c9c474e9602f865d1db6df74111085cd9e2bef8ac708b
Content-Type: application/json

{
  "cKdLokasi": "CAB001",
  "cKdPelanggan": "PL001",
  "cKdJenisHarga": "JH001",
  "nJumlahTamu": 2,
  "cKeterangan": "Order from mobile app",
  "nDiscRp": 0,
  "nBiayaServis": 5000,
  "nPajak": 10000,
  "nBiayaTambahan": 0,
  "nPembulatan": 0,
  "nDiscRpTambahan": 5000,
  "cUserID": "TESTER",
  "cTransOnline": "ORD-90-01-00001",
  "list": [
    {
      "cKdProduk": "IC-001",
      "nQty": 2,
      "cKeterangan": "No ice",
      "nDiscRp": 0
    }
  ],
  "list_pembayaran": [
    {
      "cKdJenisPembayaran": "JP003",
      "nBayar": 95000,
      "cKeterangan": "QRIS from Apps"
    }
  ]
}
```

### GrabExpress Delivery Integration

For delivery orders, GrabExpress delivery is created automatically:

```json
{
  "merchantOrderID": "ORD-90-01-00001",
  "serviceType": "INSTANT",
  "vehicleType": "BIKE",
  "codType": "REGULAR",
  "paymentMethod": "CASHLESS",
  "highValue": false,
  "packages": [
    {
      "name": "Ice Coffee",
      "description": "No ice",
      "quantity": 2,
      "price": 50000,
      "dimensions": {
        "height": 1,
        "width": 1,
        "depth": 1,
        "weight": 1
      }
    }
  ],
  "origin": {
    "address": "Delitopia Branch Address",
    "coordinates": {
      "latitude": -6.200000,
      "longitude": 106.816666
    }
  },
  "destination": {
    "address": "Customer Delivery Address",
    "coordinates": {
      "latitude": -6.175110,
      "longitude": 106.827153
    }
  },
  "recipient": {
    "firstName": "John",
    "lastName": "Doe",
    "email": "john@example.com",
    "phone": "081234567890",
    "smsEnabled": true
  },
  "sender": {
    "firstName": "Delitopia",
    "companyName": "Delitopia",
    "email": "delitopia2@gmail.com",
    "phone": "085232979546",
    "smsEnabled": true
  }
}
```

---

## Order Status Management

### Order Status Flow

```
pending → paid → processing → ready → completed
   ↓         ↓
expired   cancelled
```

### Status Descriptions

| Status | Description | Trigger |
|--------|-------------|---------|
| pending | Order created, awaiting payment | Order creation |
| paid | Payment received | Payment callback |
| expired | Payment expired | Payment callback or timeout |
| processing | Restaurant preparing order | Admin action |
| ready | Order ready for pickup/delivery | Admin action |
| completed | Order fulfilled | Admin action |
| cancelled | Order cancelled | Admin or user action |

### Update Order Status API

```http
POST /api/postData/order-status
Authorization: Bearer {admin_token}
Content-Type: application/json

{
  "order_id": "ORD-90-01-00001",
  "status": "processing"
}
```

---

## Complete API Examples

### Example 1: Complete Dine-In Order with QRIS

**Step 1: Add items to cart**
```bash
curl -X POST "https://delitopia.softindopp.com/api/cart/add" \
  -H "Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc..." \
  -H "Content-Type: application/json" \
  -d '{
    "template_code": "IC-001",
    "branch_id": 90,
    "qty": 2,
    "notes": "Less sugar"
  }'
```

**Step 2: Get cart**
```bash
curl -X GET "https://delitopia.softindopp.com/api/cart" \
  -H "Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc..."
```

**Step 3: Create order with QRIS**
```bash
curl -X POST "https://delitopia.softindopp.com/api/postData/order" \
  -H "Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc..." \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2025-12-01",
    "grand_total": 100000,
    "final_total": 115000,
    "discount": 0,
    "tax": 10000,
    "service": 5000,
    "order_type": "dine in",
    "notes": "Table near window",
    "payment": "QRIS",
    "user_id": 123,
    "branch_id": 90,
    "table_number": "T-05",
    "details": [
      {
        "menu_id": 408,
        "menu_code": "IC-001",
        "notes": "Less sugar",
        "qty": 2,
        "total": 100000
      }
    ]
  }'
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "payment_method": "QRIS",
    "qr_string": "00020101021226670016COM.NOBUBANK.WWW...",
    "expired_time": "2025-12-01T12:15:00.000000Z",
    "transaction_id": "TRX-20251201-123456",
    "external_id": "D3L1T0P1A-251201-123-456",
    "order_id": "ORD-90-01-00001"
  },
  "message": "success create payment"
}
```

**Step 4: Display QR code in app**
```dart
// User scans QR code with banking app
```

**Step 5: Payment gateway sends callback (automatic)**
```json
// Sent to: POST /api/payment/callback
{
  "external_id": "D3L1T0P1A-251201-123-456",
  "order_id": "ORD-90-01-00001",
  "transaction_status": "PAID",
  "payment_details": {
    "paid_time": "2025-12-01T11:45:30.000000Z"
  },
  "reference_id": "REF-20251201-789012",
  "response_code": "00"
}
```

**Step 6: Check order status**
```bash
curl -X POST "https://delitopia.softindopp.com/api/getData/historyOrder" \
  -H "Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc..." \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 123
  }'
```

---

### Example 2: Delivery Order with Voucher

```bash
curl -X POST "https://delitopia.softindopp.com/api/postData/order" \
  -H "Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc..." \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2025-12-01",
    "grand_total": 150000,
    "final_total": 140000,
    "discount": 20000,
    "tax": 10000,
    "service": 0,
    "order_type": "delivery",
    "payment": "QRIS",
    "user_id": 123,
    "branch_id": 90,
    "table_number": "DELIVERY",
    "user_voucher_id": 789,
    "deliver_address": "Jl. Sudirman No. 123, Jakarta Selatan",
    "deliver_lat": -6.175110,
    "deliver_long": 106.827153,
    "details": [
      {
        "menu_id": 408,
        "menu_code": "IC-001",
        "qty": 3,
        "total": 150000
      }
    ]
  }'
```

---

## Mobile App Integration

### Flutter Example: Complete Order Flow

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class OrderService {
  final String baseUrl = 'https://delitopia.softindopp.com/api';
  String? token;

  // 1. Add item to cart
  Future<Map<String, dynamic>> addToCart({
    String? templateCode,
    int? branchMenuItemId,
    required int branchId,
    required int qty,
    String? notes,
    Map<String, dynamic>? customizations,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cart/add'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (templateCode != null) 'template_code': templateCode,
        if (branchMenuItemId != null) 'branch_menu_item_id': branchMenuItemId,
        'branch_id': branchId,
        'qty': qty,
        if (notes != null) 'notes': notes,
        if (customizations != null) 'customizations': customizations,
      }),
    );

    return jsonDecode(response.body);
  }

  // 2. Get cart
  Future<Map<String, dynamic>> getCart() async {
    final response = await http.get(
      Uri.parse('$baseUrl/cart'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    return jsonDecode(response.body);
  }

  // 3. Create order
  Future<Map<String, dynamic>> createOrder({
    required String date,
    required double grandTotal,
    required double finalTotal,
    double? discount,
    required double tax,
    required double service,
    required String orderType,
    String? notes,
    required String payment,
    required int userId,
    required int branchId,
    required String tableNumber,
    int? userVoucherId,
    required List<Map<String, dynamic>> details,
    String? deliverAddress,
    double? deliverLat,
    double? deliverLong,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/postData/order'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'date': date,
        'grand_total': grandTotal,
        'final_total': finalTotal,
        if (discount != null) 'discount': discount,
        'tax': tax,
        'service': service,
        'order_type': orderType,
        if (notes != null) 'notes': notes,
        'payment': payment,
        'user_id': userId,
        'branch_id': branchId,
        'table_number': tableNumber,
        if (userVoucherId != null) 'user_voucher_id': userVoucherId,
        'details': details,
        if (deliverAddress != null) 'deliver_address': deliverAddress,
        if (deliverLat != null) 'deliver_lat': deliverLat,
        if (deliverLong != null) 'deliver_long': deliverLong,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create order: ${response.body}');
    }
  }

  // 4. Display QR code
  Widget buildQRCode(String qrString) {
    return QrImageView(
      data: qrString,
      version: QrVersions.auto,
      size: 300.0,
    );
  }

  // 5. Check order status (polling)
  Future<Map<String, dynamic>> checkOrderStatus(String orderId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/getData/historyOrder'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'user_id': userId,
      }),
    );

    final data = jsonDecode(response.body);
    final orders = data['data'] as List;
    final order = orders.firstWhere(
      (o) => o['order_id'] == orderId,
      orElse: () => null,
    );

    return order;
  }
}

// Usage Example
class CheckoutPage extends StatefulWidget {
  @override
  _CheckoutPageState createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final OrderService orderService = OrderService();
  String? qrString;
  String? orderId;
  Timer? statusCheckTimer;

  Future<void> checkout() async {
    try {
      // Calculate totals from cart
      final cart = await orderService.getCart();
      final items = cart['data']['items'] as List;
      
      final grandTotal = items.fold<double>(
        0, 
        (sum, item) => sum + (item['price'] * item['qty'])
      );
      
      final tax = grandTotal * 0.1; // 10% PB1
      final service = grandTotal * 0.05; // 5% service
      final finalTotal = grandTotal + tax + service;

      // Create order
      final orderResponse = await orderService.createOrder(
        date: DateTime.now().toString().split(' ')[0],
        grandTotal: grandTotal,
        finalTotal: finalTotal,
        tax: tax,
        service: service,
        orderType: 'dine in',
        payment: 'QRIS',
        userId: currentUserId,
        branchId: selectedBranchId,
        tableNumber: 'T-05',
        details: items.map((item) => {
          'menu_id': item['menu_id'] ?? item['branch_menu_item_id'],
          'menu_code': item['menu']['code'],
          'notes': item['notes'],
          'qty': item['qty'],
          'total': item['price'] * item['qty'],
        }).toList(),
      );

      if (orderResponse['status'] == 'success') {
        setState(() {
          qrString = orderResponse['data']['qr_string'];
          orderId = orderResponse['data']['order_id'];
        });

        // Start polling order status
        startStatusPolling();
      }
    } catch (e) {
      print('Checkout error: $e');
      showErrorDialog(e.toString());
    }
  }

  void startStatusPolling() {
    statusCheckTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      final order = await orderService.checkOrderStatus(orderId!);
      
      if (order != null && order['status'] == 'paid') {
        timer.cancel();
        showSuccessDialog();
      } else if (order != null && order['status'] == 'expired') {
        timer.cancel();
        showExpiredDialog();
      }
    });
  }

  @override
  void dispose() {
    statusCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Checkout')),
      body: Center(
        child: qrString != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Scan QR Code to Pay'),
                  SizedBox(height: 20),
                  orderService.buildQRCode(qrString!),
                  SizedBox(height: 20),
                  Text('Order ID: $orderId'),
                  Text('Waiting for payment...'),
                  CircularProgressIndicator(),
                ],
              )
            : ElevatedButton(
                onPressed: checkout,
                child: Text('Checkout with QRIS'),
              ),
      ),
    );
  }
}
```

---

## Error Handling

### Common Errors

#### 1. Cart Errors

**Error: Menu not available**
```json
{
  "status": "error",
  "message": "Menu item is not available at this branch"
}
```
**Solution:** Item is out of stock or not available. Choose different item.

**Error: Invalid menu identifier**
```json
{
  "status": "error",
  "message": "Please provide either menu_id, menu_code, template_code, or branch_menu_item_id"
}
```
**Solution:** Provide at least one valid menu identifier.

#### 2. Order Creation Errors

**Error: Validation failed**
```json
{
  "status": "failed",
  "message": "The user id field is required."
}
```
**Solution:** Check all required fields are provided.

**Error: Branch not found**
```json
{
  "status": "failed",
  "message": "Branch not found"
}
```
**Solution:** Verify branch_id exists and is active.

#### 3. Payment Errors

**Error: Payment gateway authentication failed**
```json
{
  "status": "failed",
  "message": "Payment gateway authentication failed. Please contact administrator to verify merchant credentials."
}
```
**Solution:** Payment gateway credentials invalid. Contact admin.

**Error: Payment gateway error**
```json
{
  "status": "failed",
  "message": "Payment gateway error: Invalid request format (Code: 01)"
}
```
**Solution:** Request format invalid. Check payload structure.

**Error: QR expired**
```json
{
  "external_id": "D3L1T0P1A-251201-123-456",
  "order_id": "ORD-90-01-00001",
  "transaction_status": "EXPIRED"
}
```
**Solution:** QR code expired. Create new order.

#### 4. Callback Processing Errors

All callback errors are logged but return 200 OK to prevent retries:

```json
{
  "message": "Callback received, but an error occurred"
}
```

Errors are logged to `storage/logs/laravel.log`:
```json
{
  "error": "Order not found for order_id: ORD-90-01-00001",
  "callback_data": {...},
  "timestamp": "2025-12-01 11:45:30"
}
```

---

## Best Practices

### 1. Cart Management
- Clear cart after successful order creation
- Validate item availability before checkout
- Use `branch_menu_item_id` for most accurate pricing
- Store customizations in JSON format

### 2. Order Creation
- Always validate totals on server-side
- Include all required fields
- Use proper order_type based on delivery
- Provide delivery coordinates for delivery orders

### 3. Payment Processing
- Display QR code clearly with expiration time
- Implement status polling (every 3-5 seconds)
- Handle EXPIRED status gracefully
- Allow user to retry payment

### 4. Error Handling
- Show user-friendly error messages
- Log all errors for debugging
- Implement retry mechanism for network errors
- Validate data before sending to API

### 5. Security
- Never expose payment credentials
- Use HTTPS for all API calls
- Validate JWT token on every request
- Sanitize user inputs

---

## Testing

### Test QRIS Payment Flow

```bash
# 1. Create test order
curl -X POST "https://delitopia.softindopp.com/api/postData/order" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d @test-order.json

# 2. Simulate payment callback
curl -X POST "https://delitopia.softindopp.com/api/payment/callback" \
  -H "Content-Type: application/json" \
  -d '{
    "external_id": "D3L1T0P1A-251201-123-456",
    "order_id": "ORD-90-01-00001",
    "transaction_status": "PAID",
    "payment_details": {
      "paid_time": "2025-12-01T11:45:30.000000Z"
    },
    "reference_id": "REF-TEST-001",
    "response_code": "00"
  }'

# 3. Check order status
curl -X POST "https://delitopia.softindopp.com/api/getData/historyOrder" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{"user_id": 123}'
```

---

## Appendix

### Related Documentation Files
- `CART_SYSTEM_DOCUMENTATION.md` - Detailed cart system documentation
- `PAYMENT_GATEWAY_IMPLEMENTATION.md` - Payment gateway setup
- `ESMARTLINK_IMPLEMENTATION_COMPLETE.md` - E-Smartlink integration
- `POINTS_SYSTEM_GUIDE.md` - Points and rewards system

### Support
For technical support or questions:
- Email: delitopia2@gmail.com
- Phone: +62 852 3297 9546

---

**Document Version:** 1.0  
**Last Updated:** December 1, 2025  
**Author:** GitHub Copilot
