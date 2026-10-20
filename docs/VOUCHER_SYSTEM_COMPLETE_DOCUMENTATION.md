# Complete Voucher System Documentation

**Version:** 2.0  
**Last Updated:** December 1, 2025  
**Base URL:** `https://delitopia.softindopp.com/api`

---

## Table of Contents

1. [Overview](#overview)
2. [Voucher Types](#voucher-types)
3. [Voucher Statuses](#voucher-statuses)
4. [Expiry Types](#expiry-types)
5. [Usage Limit System](#usage-limit-system)
6. [Database Schema](#database-schema)
7. [API Endpoints](#api-endpoints)
   - [User Endpoints](#user-endpoints)
   - [Admin Endpoints](#admin-endpoints)
8. [Integration Examples](#integration-examples)
9. [Error Handling](#error-handling)
10. [Best Practices](#best-practices)

---

## Overview

The voucher system is a comprehensive solution for managing promotional vouchers, discounts, and loyalty rewards. It supports multiple acquisition methods (points, cash, auto-distribution), flexible expiry rules, and advanced usage controls.

### Key Features

- ✅ **Multiple Voucher Types**: Percentage discount, fixed amount, buy-1-get-1, free menu items
- ✅ **Flexible Acquisition**: Point redemption, cash purchase, auto-granted, birthday rewards
- ✅ **Advanced Expiry Control**: Duration-based, monthly, fixed date
- ✅ **Usage Limits**: Daily limits, total limits, cooldown periods
- ✅ **Two-Phase Lifecycle**: Purchase → Activation → Use
- ✅ **Analytics & Reporting**: Comprehensive statistics and insights
- ✅ **User Segmentation**: Distribute vouchers by user level, brand, or custom segments
- ✅ **Automated Distribution**: Birthday vouchers, level-up rewards

---

## Voucher Types

### 1. Percentage Discount (`percentage`)
Applies a percentage discount to the order total.

```json
{
  "voucher_type": "percentage",
  "discount_percentage": 15.5,
  "min_spend": 50000,
  "description": "15% off on orders above Rp 50,000"
}
```

**Fields:**
- `discount_percentage` (required): 0-100
- `min_spend` (optional): Minimum order value to apply voucher

### 2. Fixed Amount Discount (`amount`)
Applies a fixed amount discount to the order total.

```json
{
  "voucher_type": "amount",
  "discount_amount": 20000,
  "min_spend": 100000,
  "description": "Rp 20,000 off on orders above Rp 100,000"
}
```

**Fields:**
- `discount_amount` (required): Discount value in currency
- `min_spend` (optional): Minimum order value

### 3. Buy 1 Get 1 (`buy_1_get_1`)
Purchase specific menu item, get another item free.

```json
{
  "voucher_type": "buy_1_get_1",
  "buy_1_get_1_buy_id": 123,
  "buy_1_get_1_free_id": 456,
  "description": "Buy Latte, Get Cappuccino Free"
}
```

**Fields:**
- `buy_1_get_1_buy_id` (required): Menu ID user must purchase
- `buy_1_get_1_free_id` (required): Menu ID user gets free

### 4. Free Menu Item (`free_item`)
Get a specific menu item completely free.

```json
{
  "voucher_type": "free_item",
  "free_menu_item_id": 789,
  "description": "Free Croissant"
}
```

**Fields:**
- `free_menu_item_id` (required): Menu ID user gets free

---

## Voucher Statuses

Vouchers in user's wallet (`detail_vouchers`) can have these statuses:

### 1. `inactive`
- Voucher purchased/received but not yet activated
- Cannot be used until activated
- Use: Allows users to activate when ready

### 2. `active`
- Voucher is activated and ready to use
- Subject to expiry date and usage limits
- Can be applied to orders

### 3. `used`
- Voucher has been fully consumed
- No longer available for use
- Appears in history

### 4. `expired`
- Voucher passed its expiry date without being used
- System automatically marks expired vouchers
- Cannot be used

**Status Flow:**
```
inactive → activate() → active → use() → used
    ↓                       ↓
    └─────── expired ←──────┘
```

---

## Expiry Types

Control when vouchers expire after activation.

### 1. Duration-Based (`duration`)
Expires X days after activation.

```json
{
  "expiry_type": "duration",
  "duration_days": 30
}
```

**Calculation:**
```
activation_date + duration_days = expiry_date
```

**Example:**
- Activated: 2025-12-01
- Duration: 30 days
- Expires: 2025-12-31 23:59:59

### 2. Monthly (`monthly`)
Expires at end of specific month/year.

```json
{
  "expiry_type": "monthly",
  "specific_month": 12,
  "specific_year": 2025
}
```

**Calculation:**
```
Last day of specified month/year at 23:59:59
```

**Example:**
- Month: December (12)
- Year: 2025
- Expires: 2025-12-31 23:59:59

### 3. Fixed Date (`fixed`)
Expires on specific date regardless of activation.

```json
{
  "expiry_type": "fixed",
  "end_date": "2025-12-25"
}
```

**Calculation:**
```
end_date at 23:59:59
```

**Example:**
- End date: 2025-12-25
- Expires: 2025-12-25 23:59:59

---

## Usage Limit System

Control how often users can use vouchers.

### Limit Types

#### 1. Unlimited (`unlimited`)
Default behavior - no restrictions.

```json
{
  "usage_limit_type": "unlimited",
  "max_usage_per_day": null,
  "max_usage_per_user": null,
  "cooldown_hours": null
}
```

**Behavior:** Voucher can be used infinitely

#### 2. Once Per Day (`once_per_day`)
User can use voucher once per day.

```json
{
  "usage_limit_type": "once_per_day",
  "max_usage_per_day": 1,
  "cooldown_hours": null
}
```

**Behavior:** 
- Resets at midnight (Asia/Jakarta)
- Voucher status remains `active`
- `last_used_at` tracked
- `usage_count` incremented

**Use Case:** Daily promotional vouchers, loyalty rewards

#### 3. Total Limit (`total_limit`)
Maximum total uses per user.

```json
{
  "usage_limit_type": "total_limit",
  "max_usage_per_user": 5,
  "cooldown_hours": null
}
```

**Behavior:**
- After reaching limit, status → `used`
- `usage_count` tracks total uses
- Cannot exceed `max_usage_per_user`

**Use Case:** Limited-time offers, VIP rewards

#### 4. Both (`both`)
Combines daily AND total limits.

```json
{
  "usage_limit_type": "both",
  "max_usage_per_day": 2,
  "max_usage_per_user": 30,
  "cooldown_hours": null
}
```

**Behavior:**
- Must satisfy BOTH conditions
- Example: 2 times/day, max 30 total (15 days)

**Use Case:** Controlled promotions, subscription-style vouchers

#### 5. Cooldown Period (Optional)
Hours to wait between uses.

```json
{
  "usage_limit_type": "unlimited",
  "cooldown_hours": 6
}
```

**Behavior:**
- After use, must wait X hours
- More flexible than daily limit
- Can combine with any limit type

**Use Case:** Flash sales, timed promotions

### Usage Tracking Fields

**In `detail_vouchers` table:**
- `last_used_at`: Timestamp of last usage
- `usage_count`: Total number of times used

---

## Database Schema

### Vouchers Table

```sql
CREATE TABLE vouchers (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    code VARCHAR(50) UNIQUE,
    voucher_name VARCHAR(255) NOT NULL,
    brand_id BIGINT,
    user_level_id BIGINT,
    voucher_type ENUM('percentage', 'amount', 'buy_1_get_1', 'free_item'),
    description TEXT,
    
    -- Discount Configuration
    discount_amount DECIMAL(15,2),
    discount_percentage DECIMAL(5,2),
    min_spend DECIMAL(15,2),
    
    -- Acquisition
    point INT DEFAULT 0,
    price DECIMAL(15,2) DEFAULT 0,
    is_purchasable BOOLEAN DEFAULT FALSE,
    is_auto_granted BOOLEAN DEFAULT FALSE,
    
    -- Usage Limits (NEW)
    usage_limit_type ENUM('unlimited', 'once_per_day', 'total_limit', 'both') DEFAULT 'unlimited',
    max_usage_per_user INT,
    max_usage_per_day INT,
    cooldown_hours INT,
    
    -- Validity Period
    start_date DATE,
    end_date DATE,
    
    -- Expiry Configuration
    expiry_type ENUM('duration', 'monthly', 'fixed'),
    duration_days INT,
    specific_month INT,
    specific_year INT,
    
    -- Special Items
    buy_1_get_1_buy_id BIGINT,
    buy_1_get_1_free_id BIGINT,
    free_menu_item_id BIGINT,
    
    -- Media
    image VARCHAR(500),
    
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    
    FOREIGN KEY (brand_id) REFERENCES brand(id),
    FOREIGN KEY (user_level_id) REFERENCES user_levels(id),
    FOREIGN KEY (buy_1_get_1_buy_id) REFERENCES menus(id),
    FOREIGN KEY (buy_1_get_1_free_id) REFERENCES menus(id),
    FOREIGN KEY (free_menu_item_id) REFERENCES menus(id)
);
```

### Detail Vouchers Table

```sql
CREATE TABLE detail_vouchers (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    voucher_id BIGINT NOT NULL,
    order_id BIGINT,
    
    -- Status
    status ENUM('inactive', 'active', 'used', 'expired') DEFAULT 'inactive',
    
    -- Dates
    purchase_date TIMESTAMP,
    activation_date TIMESTAMP,
    expiry_date TIMESTAMP,
    purchased_at TIMESTAMP,
    
    -- Payment Info
    points_used INT DEFAULT 0,
    cash_paid DECIMAL(15,2) DEFAULT 0,
    payment_status VARCHAR(50),
    payment_method VARCHAR(50),
    payment_reference VARCHAR(255),
    purchase_type ENUM('points', 'cash', 'distributed', 'birthday', 'promo'),
    
    -- Usage Tracking (NEW)
    last_used_at TIMESTAMP,
    usage_count INT DEFAULT 0,
    
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (voucher_id) REFERENCES vouchers(id),
    FOREIGN KEY (order_id) REFERENCES orders(id)
);
```

---

## API Endpoints

### Authentication

All endpoints require JWT Bearer token (except public endpoints).

**Header:**
```
Authorization: Bearer {your_jwt_token}
```

---

## User Endpoints

### 1. Get Available Vouchers

List all vouchers currently available.

**Endpoint:** `GET /api/getData/voucher`

**Headers:**
```
Authorization: Bearer {token}
```

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "voucher_name": "15% Weekend Discount",
      "brand_name": "Delitopia Coffee",
      "voucher_type": "percentage",
      "discount_percentage": 15,
      "min_spend": 50000,
      "description": "Enjoy 15% off on weekends",
      "point": 100,
      "price": 0,
      "start_date": "2025-12-01",
      "end_date": "2025-12-31",
      "image": "https://example.com/images/voucher/voucher1.jpg",
      "usage_limit_type": "once_per_day",
      "max_usage_per_day": 1
    }
  ],
  "message": "Vouchers data retrieved successfully"
}
```

### 2. Get Voucher Details

Get details of a specific voucher.

**Endpoint:** `GET /api/getData/voucher-show/{id}`

**Parameters:**
- `id` (path): Voucher ID

**Response:**
```json
{
  "status": "success",
  "data": {
    "id": 1,
    "voucher_name": "Free Birthday Cake",
    "brand_id": 1,
    "brand_name": "Delitopia Bakery",
    "voucher_type": "free_item",
    "free_menu_item_id": 45,
    "free_menu_name": "Chocolate Cake",
    "free_menu_code": "CAKE001",
    "description": "Get a free chocolate cake on your birthday",
    "expiry_type": "duration",
    "duration_days": 7,
    "usage_limit_type": "unlimited",
    "image": "https://example.com/images/voucher/birthday.jpg"
  },
  "message": "Banner data retrieved successfully!"
}
```

### 3. Get Point Redemption Vouchers

List vouchers that can be redeemed with points.

**Endpoint:** `GET /api/getData/vouchers/point-redemption`

**Query Parameters:**
- `brand_id` (optional): Filter by brand

**Response:**
```json
{
  "status": "success",
  "data": {
    "user_points": 500,
    "vouchers": [
      {
        "id": 5,
        "voucher_name": "10% Discount Voucher",
        "brand_name": "Delitopia Coffee",
        "point": 100,
        "discount_percentage": 10,
        "can_redeem": true
      },
      {
        "id": 8,
        "voucher_name": "20% Premium Discount",
        "brand_name": "Delitopia Coffee",
        "point": 600,
        "discount_percentage": 20,
        "can_redeem": false
      }
    ]
  },
  "message": "Point redemption vouchers retrieved successfully"
}
```

### 4. Redeem Voucher with Points

Redeem a voucher using loyalty points.

**Endpoint:** `POST /api/postData/vouchers/redeem-points`

**Request Body:**
```json
{
  "voucher_id": 5
}
```

**Response (Success):**
```json
{
  "status": "success",
  "data": {
    "detail_voucher": {
      "id": 123,
      "user_id": 10,
      "voucher_id": 5,
      "status": "inactive",
      "purchased_at": "2025-12-01T10:30:00Z",
      "expiry_date": "2025-12-31T23:59:59Z",
      "voucher": {
        "id": 5,
        "voucher_name": "10% Discount Voucher",
        "brand": {
          "id": 1,
          "name": "Delitopia Coffee"
        }
      }
    },
    "points_remaining": 400
  },
  "message": "Voucher redeemed successfully with points"
}
```

**Error Response (Insufficient Points):**
```json
{
  "status": "error",
  "message": "Insufficient points. You have 50 points, need 100 points"
}
```

### 5. Get Cash Purchase Vouchers

List vouchers that can be purchased with money.

**Endpoint:** `GET /api/getData/vouchers/cash-purchase`

**Query Parameters:**
- `brand_id` (optional): Filter by brand

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 10,
      "voucher_name": "Premium 25% Off Bundle",
      "brand_name": "Delitopia Coffee",
      "price": 50000,
      "discount_percentage": 25,
      "min_spend": 200000,
      "is_purchasable": true
    }
  ],
  "message": "Cash purchase vouchers retrieved successfully"
}
```

### 6. Purchase Voucher with Cash

Purchase a voucher using money (payment gateway).

**Endpoint:** `POST /api/postData/vouchers/purchase-cash`

**Request Body:**
```json
{
  "voucher_id": 10,
  "payment_method": "esmartlink"
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "detail_voucher_id": 150,
    "payment_url": "https://payment.gateway.com/pay/abc123",
    "amount": 50000,
    "voucher": {
      "id": 10,
      "voucher_name": "Premium 25% Off Bundle"
    }
  },
  "message": "Payment initiated. Please complete payment to receive voucher."
}
```

### 7. Get My Vouchers

Get all vouchers in user's wallet.

**Endpoint:** `GET /api/getData/my-vouchers`

**Query Parameters:**
- `status` (optional): Filter by status (`inactive`, `active`, `expired`, `used`)

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 123,
      "user_id": 10,
      "voucher_id": 5,
      "status": "active",
      "purchase_date": "2025-12-01T10:30:00Z",
      "activation_date": "2025-12-01T11:00:00Z",
      "expiry_date": "2025-12-31T23:59:59Z",
      "usage_count": 2,
      "last_used_at": "2025-12-15T14:30:00Z",
      "voucher": {
        "id": 5,
        "voucher_name": "10% Discount Voucher",
        "voucher_type": "percentage",
        "discount_percentage": 10,
        "usage_limit_type": "both",
        "max_usage_per_day": 2,
        "max_usage_per_user": 10,
        "brand": {
          "name": "Delitopia Coffee"
        }
      }
    }
  ],
  "message": "User vouchers retrieved successfully"
}
```

### 8. Get My Active Vouchers

Get only active vouchers ready to use.

**Endpoint:** `GET /api/getData/my-active-vouchers`

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 123,
      "status": "active",
      "expiry_date": "2025-12-31T23:59:59Z",
      "voucher": {
        "voucher_name": "10% Discount",
        "discount_percentage": 10,
        "min_spend": 50000
      }
    }
  ],
  "message": "Active vouchers retrieved successfully"
}
```

### 9. Activate Voucher

Activate an inactive voucher to make it usable.

**Endpoint:** `POST /api/postData/voucher-activate`

**Request Body:**
```json
{
  "detail_voucher_id": 123
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "id": 123,
    "status": "active",
    "activation_date": "2025-12-01T15:00:00Z",
    "expiry_date": "2025-12-31T23:59:59Z",
    "voucher": {
      "voucher_name": "10% Discount Voucher",
      "expiry_type": "duration",
      "duration_days": 30
    }
  },
  "message": "Voucher activated successfully"
}
```

### 10. Validate Voucher Usage

Check if voucher can be used right now (checks daily limits, cooldowns).

**Endpoint:** `POST /api/getData/vouchers/validate-usage`

**Request Body:**
```json
{
  "detail_voucher_id": 123
}
```

**Response (Can Use):**
```json
{
  "status": "success",
  "data": {
    "can_use": true,
    "message": "Voucher can be used",
    "next_available": null,
    "usage_count": 2,
    "max_usage_per_user": 10,
    "max_usage_per_day": 2
  },
  "message": "Voucher can be used"
}
```

**Response (Daily Limit Reached):**
```json
{
  "status": "success",
  "data": {
    "can_use": false,
    "message": "Daily usage limit reached (2 times per day).",
    "next_available": "2025-12-02T00:00:00Z",
    "usage_count": 5,
    "max_usage_per_user": 10,
    "max_usage_per_day": 2
  },
  "message": "Voucher usage restricted"
}
```

### 11. Get Voucher Usage History

Get detailed usage information for a voucher.

**Endpoint:** `GET /api/getData/vouchers/usage-history`

**Query Parameters:**
- `detail_voucher_id`: Detail voucher ID

**Response:**
```json
{
  "status": "success",
  "data": {
    "detail_voucher_id": 123,
    "voucher_name": "Daily Coffee Discount",
    "status": "active",
    "usage_count": 5,
    "last_used_at": "2025-12-01T14:30:00Z",
    "can_use_now": false,
    "next_available_at": "2025-12-02T00:00:00Z",
    "usage_limits": {
      "type": "both",
      "max_per_user": 30,
      "max_per_day": 2,
      "cooldown_hours": null
    }
  },
  "message": "Voucher usage history retrieved successfully"
}
```

### 12. Use Voucher (Apply to Order)

Apply voucher to an order (marks as used if single-use, or records usage).

**Endpoint:** `POST /api/postData/use-voucher-api`

**Request Body:**
```json
{
  "detail_voucher_id": 123,
  "order_id": 456
}
```

**Response (Success):**
```json
{
  "status": "success",
  "data": {
    "id": 123,
    "status": "active",
    "usage_count": 3,
    "last_used_at": "2025-12-01T16:00:00Z",
    "order_id": 456
  },
  "message": "Voucher applied successfully"
}
```

**Error (Daily Limit):**
```json
{
  "status": "error",
  "message": "This voucher cannot be used right now. Next available: 2025-12-02 00:00:00 (Limited to once per day)"
}
```

### 13. Get All Vouchers Categorized

Get vouchers organized by category (point-based, cash-based, etc.).

**Endpoint:** `GET /api/postData/vouchers/all-categorized`

**Response:**
```json
{
  "status": "success",
  "data": {
    "point_redemption": [
      {
        "id": 5,
        "voucher_name": "10% Discount",
        "point": 100
      }
    ],
    "cash_purchase": [
      {
        "id": 10,
        "voucher_name": "Premium Bundle",
        "price": 50000
      }
    ],
    "auto_granted": [
      {
        "id": 15,
        "voucher_name": "Welcome Bonus",
        "is_auto_granted": true
      }
    ]
  },
  "message": "Categorized vouchers retrieved successfully"
}
```

### 14. Redeem Birthday Voucher

Special endpoint for birthday voucher redemption.

**Endpoint:** `POST /api/birthday-voucher`

**Response:**
```json
{
  "status": "success",
  "data": {
    "detail_voucher_id": 200,
    "voucher": {
      "voucher_name": "Happy Birthday Voucher",
      "voucher_type": "birthday"
    },
    "expiry_date": "2025-12-07T23:59:59Z"
  },
  "message": "Birthday voucher claimed successfully!"
}
```

---

## Admin Endpoints

Base path: `/api/admin/vouchers`

### 1. Get All Vouchers (Admin)

List all vouchers with advanced filtering and statistics.

**Endpoint:** `GET /api/admin/vouchers`

**Query Parameters:**
- `status` (optional): `active`, `upcoming`, `expired`
- `type` (optional): Voucher type
- `brand_id` (optional): Filter by brand
- `search` (optional): Search by name
- `sort_by` (optional): Sort field (default: `created_at`)
- `sort_order` (optional): `asc` or `desc` (default: `desc`)
- `per_page` (optional): Items per page (default: 15)

**Response:**
```json
{
  "status": "success",
  "data": {
    "current_page": 1,
    "data": [
      {
        "id": 1,
        "voucher_name": "Weekend Special",
        "brand_id": 1,
        "brand": {
          "id": 1,
          "name": "Delitopia Coffee"
        },
        "voucher_type": "percentage",
        "discount_percentage": 15,
        "start_date": "2025-12-01",
        "end_date": "2025-12-31",
        "status": "active",
        "total_claimed": 150,
        "total_used": 120,
        "total_unused": 25,
        "total_expired": 5,
        "usage_rate": 80,
        "usage_limit_type": "once_per_day",
        "max_usage_per_day": 1
      }
    ],
    "total": 50,
    "per_page": 15,
    "last_page": 4
  },
  "message": "Vouchers retrieved successfully"
}
```

### 2. Create Voucher (Admin)

Create a new voucher.

**Endpoint:** `POST /api/admin/vouchers`

**Request Body (Percentage Discount):**
```json
{
  "voucher_name": "Weekend 15% Off",
  "brand_id": 1,
  "voucher_type": "percentage",
  "description": "Get 15% off on weekends",
  "discount_percentage": 15,
  "min_spend": 50000,
  "point": 0,
  "price": 0,
  "is_purchasable": false,
  "is_auto_granted": false,
  "usage_limit_type": "once_per_day",
  "max_usage_per_day": 1,
  "max_usage_per_user": null,
  "cooldown_hours": null,
  "start_date": "2025-12-01",
  "end_date": "2025-12-31",
  "expiry_type": "duration",
  "duration_days": 7,
  "image": "base64_or_url"
}
```

**Request Body (Buy 1 Get 1):**
```json
{
  "voucher_name": "Coffee B1G1",
  "brand_id": 1,
  "voucher_type": "buy_1_get_1",
  "description": "Buy Latte, Get Cappuccino Free",
  "buy_1_get_1_buy_id": 123,
  "buy_1_get_1_free_id": 456,
  "point": 200,
  "price": 0,
  "start_date": "2025-12-01",
  "end_date": "2025-12-31",
  "expiry_type": "fixed",
  "usage_limit_type": "total_limit",
  "max_usage_per_user": 3
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "id": 25,
    "voucher_name": "Weekend 15% Off",
    "code": "WKND15-XYZ123",
    "created_at": "2025-12-01T10:00:00Z"
  },
  "message": "Voucher created successfully"
}
```

### 3. Update Voucher (Admin)

Update existing voucher.

**Endpoint:** `PUT /api/admin/vouchers/{id}`

**Request Body:**
```json
{
  "voucher_name": "Updated Weekend Special",
  "discount_percentage": 20,
  "end_date": "2026-01-31",
  "usage_limit_type": "both",
  "max_usage_per_day": 2,
  "max_usage_per_user": 60
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "id": 25,
    "voucher_name": "Updated Weekend Special",
    "updated_at": "2025-12-01T11:00:00Z"
  },
  "message": "Voucher updated successfully"
}
```

### 4. Delete Voucher (Admin)

Delete a voucher.

**Endpoint:** `DELETE /api/admin/vouchers/{id}`

**Response:**
```json
{
  "status": "success",
  "message": "Voucher deleted successfully"
}
```

### 5. Get Voucher Analytics

Get comprehensive statistics for vouchers.

**Endpoint:** `GET /api/admin/vouchers/analytics/statistics`

**Query Parameters:**
- `start_date`: Start date (YYYY-MM-DD)
- `end_date`: End date (YYYY-MM-DD)

**Response:**
```json
{
  "status": "success",
  "data": {
    "overview": {
      "total_vouchers": 50,
      "active_vouchers": 35,
      "total_claimed": 5000,
      "total_used": 4200,
      "redemption_rate": 84,
      "total_revenue_generated": 15000000,
      "total_discount_given": 3500000
    },
    "by_type": {
      "percentage": {
        "count": 20,
        "total_used": 2000
      },
      "amount": {
        "count": 15,
        "total_used": 1500
      },
      "buy_1_get_1": {
        "count": 10,
        "total_used": 500
      },
      "free_item": {
        "count": 5,
        "total_used": 200
      }
    },
    "top_vouchers": [
      {
        "id": 5,
        "voucher_name": "Daily Coffee 10%",
        "usage_count": 800,
        "total_discount": 500000
      }
    ],
    "daily_usage": [
      {
        "date": "2025-12-01",
        "count": 150
      }
    ]
  },
  "message": "Analytics retrieved successfully"
}
```

### 6. Compare Voucher Performance

Compare performance between vouchers or time periods.

**Endpoint:** `POST /api/admin/vouchers/analytics/compare`

**Request Body:**
```json
{
  "voucher_ids": [5, 10, 15],
  "start_date": "2025-11-01",
  "end_date": "2025-11-30"
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "comparison": [
      {
        "voucher_id": 5,
        "voucher_name": "10% Discount",
        "total_claimed": 500,
        "total_used": 450,
        "redemption_rate": 90,
        "revenue_generated": 2000000,
        "avg_order_value": 150000
      },
      {
        "voucher_id": 10,
        "voucher_name": "Free Coffee",
        "total_claimed": 300,
        "total_used": 250,
        "redemption_rate": 83.33,
        "revenue_generated": 1500000,
        "avg_order_value": 120000
      }
    ],
    "winner": {
      "by_usage": 5,
      "by_revenue": 5,
      "by_redemption_rate": 5
    }
  },
  "message": "Comparison completed successfully"
}
```

### 7. Distribute Vouchers to Users

Distribute vouchers to specific users.

**Endpoint:** `POST /api/admin/vouchers/{id}/distribute-users`

**Request Body:**
```json
{
  "user_ids": [10, 25, 30, 45],
  "expiry_date": "2025-12-31"
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "voucher_id": 5,
    "distributed_to": 4,
    "detail_voucher_ids": [201, 202, 203, 204]
  },
  "message": "Voucher distributed to 4 users successfully"
}
```

### 8. Distribute Vouchers to Segment

Distribute vouchers to user segments (by level, brand, etc.).

**Endpoint:** `POST /api/admin/vouchers/{id}/distribute-segment`

**Request Body:**
```json
{
  "segment_type": "user_level",
  "user_level_id": 3,
  "brand_id": 1,
  "expiry_date": "2025-12-31"
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "voucher_id": 5,
    "segment_type": "user_level",
    "distributed_to": 150,
    "users_affected": [10, 25, 30, ...]
  },
  "message": "Voucher distributed to segment successfully"
}
```

### 9. Export Voucher Data

Export voucher data to CSV/Excel.

**Endpoint:** `GET /api/admin/vouchers/export/data`

**Query Parameters:**
- `format`: `csv` or `excel`
- `start_date`: Filter start date
- `end_date`: Filter end date
- `voucher_id` (optional): Specific voucher

**Response:**
```
File download with voucher data
```

### 10. Get Helper Data

Get brands and menus for voucher creation.

**Endpoint:** `GET /api/admin/vouchers/helpers/brands`

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "name": "Delitopia Coffee"
    },
    {
      "id": 2,
      "name": "Delitopia Bakery"
    }
  ]
}
```

**Endpoint:** `GET /api/admin/vouchers/helpers/menus`

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 123,
      "name": "Latte",
      "code": "LATTE001",
      "price": 35000
    }
  ]
}
```

---

## Integration Examples

### Flutter/Mobile App Integration

#### 1. Display Available Vouchers

```dart
Future<List<Voucher>> getAvailableVouchers() async {
  final response = await http.get(
    Uri.parse('$baseUrl/api/getData/voucher'),
    headers: {
      'Authorization': 'Bearer $token',
    },
  );
  
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return (data['data'] as List)
        .map((v) => Voucher.fromJson(v))
        .toList();
  }
  throw Exception('Failed to load vouchers');
}
```

#### 2. Redeem Voucher with Points

```dart
Future<VoucherRedemption> redeemWithPoints(int voucherId) async {
  final response = await http.post(
    Uri.parse('$baseUrl/api/postData/vouchers/redeem-points'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: json.encode({
      'voucher_id': voucherId,
    }),
  );
  
  if (response.statusCode == 201) {
    final data = json.decode(response.body);
    return VoucherRedemption.fromJson(data['data']);
  } else {
    final error = json.decode(response.body);
    throw Exception(error['message']);
  }
}
```

#### 3. Validate Before Using

```dart
Future<bool> canUseVoucher(int detailVoucherId) async {
  final response = await http.post(
    Uri.parse('$baseUrl/api/getData/vouchers/validate-usage'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: json.encode({
      'detail_voucher_id': detailVoucherId,
    }),
  );
  
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return data['data']['can_use'];
  }
  return false;
}
```

#### 4. Apply Voucher to Order

```dart
Future<void> applyVoucherToOrder(int detailVoucherId, int orderId) async {
  final response = await http.post(
    Uri.parse('$baseUrl/api/postData/use-voucher-api'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: json.encode({
      'detail_voucher_id': detailVoucherId,
      'order_id': orderId,
    }),
  );
  
  if (response.statusCode != 200) {
    final error = json.decode(response.body);
    throw Exception(error['message']);
  }
}
```

### Admin Panel Integration (JavaScript/React)

#### 1. Create Voucher

```javascript
async function createVoucher(voucherData) {
  const response = await fetch(`${API_BASE}/api/admin/vouchers`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${adminToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      voucher_name: voucherData.name,
      brand_id: voucherData.brandId,
      voucher_type: voucherData.type,
      discount_percentage: voucherData.discountPercentage,
      usage_limit_type: voucherData.usageLimitType,
      max_usage_per_day: voucherData.maxUsagePerDay,
      start_date: voucherData.startDate,
      end_date: voucherData.endDate,
      expiry_type: 'duration',
      duration_days: 30,
    }),
  });
  
  if (!response.ok) {
    throw new Error('Failed to create voucher');
  }
  
  return await response.json();
}
```

#### 2. Get Analytics

```javascript
async function getVoucherAnalytics(startDate, endDate) {
  const url = new URL(`${API_BASE}/api/admin/vouchers/analytics/statistics`);
  url.searchParams.append('start_date', startDate);
  url.searchParams.append('end_date', endDate);
  
  const response = await fetch(url, {
    headers: {
      'Authorization': `Bearer ${adminToken}`,
    },
  });
  
  return await response.json();
}
```

#### 3. Distribute Vouchers

```javascript
async function distributeToSegment(voucherId, segmentData) {
  const response = await fetch(
    `${API_BASE}/api/admin/vouchers/${voucherId}/distribute-segment`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${adminToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        segment_type: 'user_level',
        user_level_id: segmentData.userLevelId,
        expiry_date: segmentData.expiryDate,
      }),
    }
  );
  
  return await response.json();
}
```

---

## Error Handling

### Common Error Responses

#### 1. Insufficient Points
```json
{
  "status": "error",
  "message": "Insufficient points. You have 50 points, need 100 points"
}
```

#### 2. Voucher Already Redeemed
```json
{
  "status": "error",
  "message": "You have already redeemed this voucher"
}
```

#### 3. Daily Limit Reached
```json
{
  "status": "error",
  "message": "This voucher cannot be used right now. Next available: 2025-12-02 00:00:00 (Limited to once per day)"
}
```

#### 4. Voucher Expired
```json
{
  "status": "error",
  "message": "This voucher has expired"
}
```

#### 5. Minimum Spend Not Met
```json
{
  "status": "error",
  "message": "Minimum spend of Rp 50,000 required to use this voucher"
}
```

#### 6. Validation Error
```json
{
  "status": "error",
  "message": "The given data was invalid.",
  "errors": {
    "voucher_id": ["The voucher id field is required."],
    "discount_percentage": ["The discount percentage must be between 0 and 100."]
  }
}
```

### Error Codes

| HTTP Status | Meaning |
|-------------|---------|
| 200 | Success |
| 201 | Created successfully |
| 400 | Bad request / Validation error |
| 401 | Unauthorized (invalid/missing token) |
| 403 | Forbidden (insufficient permissions) |
| 404 | Resource not found |
| 500 | Server error |

---

## Best Practices

### For Developers

1. **Always Validate Before Use**
   ```dart
   // Check if voucher can be used before applying
   final canUse = await validateVoucherUsage(detailVoucherId);
   if (canUse) {
     await applyVoucher(detailVoucherId, orderId);
   } else {
     showError('Voucher cannot be used right now');
   }
   ```

2. **Handle Expiry Gracefully**
   ```dart
   // Show time remaining
   if (voucher.expiryDate != null) {
     final remaining = voucher.expiryDate.difference(DateTime.now());
     showBadge('Expires in ${remaining.inDays} days');
   }
   ```

3. **Display Usage Limits Clearly**
   ```dart
   String getUsageLimitText(Voucher voucher) {
     switch (voucher.usageLimitType) {
       case 'once_per_day':
         return 'Use once daily';
       case 'total_limit':
         return 'Use up to ${voucher.maxUsagePerUser}x';
       case 'both':
         return '${voucher.maxUsagePerDay}x daily, ${voucher.maxUsagePerUser}x total';
       default:
         return 'Unlimited use';
     }
   }
   ```

4. **Cache Voucher List**
   ```dart
   // Cache for 5 minutes to reduce API calls
   List<Voucher>? _cachedVouchers;
   DateTime? _cacheTime;
   
   Future<List<Voucher>> getVouchers() async {
     if (_cachedVouchers != null && 
         _cacheTime != null && 
         DateTime.now().difference(_cacheTime!) < Duration(minutes: 5)) {
       return _cachedVouchers!;
     }
     
     _cachedVouchers = await fetchVouchersFromAPI();
     _cacheTime = DateTime.now();
     return _cachedVouchers!;
   }
   ```

### For Admins

1. **Set Realistic Expiry Periods**
   - Duration-based: 7-30 days for promotional vouchers
   - Monthly: Good for seasonal campaigns
   - Fixed: Use for specific events (holidays, anniversaries)

2. **Configure Usage Limits Strategically**
   - `once_per_day`: Daily engagement, loyalty rewards
   - `total_limit`: Limited-time offers, prevent abuse
   - `both`: Subscription-style benefits (e.g., 2x daily for 30 days)

3. **Monitor Analytics Regularly**
   - Check redemption rates weekly
   - Identify underperforming vouchers
   - Adjust based on user behavior

4. **Test Before Distribution**
   - Create test voucher with same configuration
   - Test all use cases (redemption, activation, usage)
   - Verify expiry calculations

5. **Use Appropriate Voucher Types**
   - Percentage: Better for high-value orders
   - Fixed amount: Clear value proposition
   - Buy 1 Get 1: Increases order quantity
   - Free item: Customer acquisition

### Security Considerations

1. **Token Management**
   - Store JWT tokens securely
   - Implement token refresh mechanism
   - Never expose tokens in logs

2. **Input Validation**
   - Always validate on backend
   - Sanitize all user inputs
   - Check minimum/maximum values

3. **Rate Limiting**
   - Limit API calls per user
   - Prevent voucher redemption spam
   - Monitor suspicious activity

4. **Audit Logging**
   - Log all voucher operations
   - Track who distributed vouchers
   - Monitor unusual redemption patterns

---

## Troubleshooting

### Issue: Voucher not appearing in user's wallet

**Possible causes:**
1. Voucher not activated after purchase
2. Voucher expired before activation
3. User doesn't meet level requirements

**Solution:**
```sql
-- Check voucher status
SELECT * FROM detail_vouchers 
WHERE user_id = ? AND voucher_id = ?;

-- Check voucher validity
SELECT * FROM vouchers 
WHERE id = ? 
AND start_date <= NOW() 
AND end_date >= NOW();
```

### Issue: Daily limit not resetting

**Cause:** Timezone mismatch

**Solution:**
- System uses `Asia/Jakarta` timezone
- Ensure server timezone is correct
- Reset happens at midnight Jakarta time

### Issue: Analytics showing incorrect numbers

**Solution:**
```sql
-- Recalculate statistics
SELECT 
    COUNT(*) as total_claimed,
    SUM(CASE WHEN status = 'used' THEN 1 ELSE 0 END) as total_used
FROM detail_vouchers
WHERE voucher_id = ?
AND created_at BETWEEN ? AND ?;
```

---

## Changelog

### Version 2.0 (December 2025)
- ✅ Added usage limit system (daily, total, cooldown)
- ✅ Added usage tracking (last_used_at, usage_count)
- ✅ Added validation endpoints
- ✅ Enhanced analytics with usage patterns

### Version 1.5 (November 2025)
- ✅ Added birthday voucher automation
- ✅ Added notification templates
- ✅ Improved expiry calculations

### Version 1.0 (October 2025)
- ✅ Initial voucher system
- ✅ Point redemption
- ✅ Cash purchase
- ✅ Admin management

---

## Support

For technical support or questions:
- **Email:** support@delitopia.com
- **Documentation:** https://docs.delitopia.com
- **API Status:** https://status.delitopia.com

---

## Appendix

### Complete Voucher Creation Example

```json
{
  "voucher_name": "Christmas Special 2025",
  "code": "XMAS2025",
  "brand_id": 1,
  "user_level_id": null,
  "voucher_type": "percentage",
  "description": "Celebrate Christmas with 25% off!",
  "discount_percentage": 25,
  "discount_amount": null,
  "min_spend": 100000,
  "point": 0,
  "price": 0,
  "is_purchasable": false,
  "is_auto_granted": false,
  "usage_limit_type": "both",
  "max_usage_per_user": 5,
  "max_usage_per_day": 1,
  "cooldown_hours": null,
  "start_date": "2025-12-20",
  "end_date": "2025-12-26",
  "expiry_type": "fixed",
  "duration_days": null,
  "specific_month": null,
  "specific_year": null,
  "image": "https://example.com/images/xmas2025.jpg",
  "buy_1_get_1_buy_id": null,
  "buy_1_get_1_free_id": null,
  "free_menu_item_id": null
}
```

This creates a Christmas voucher that:
- Gives 25% discount
- Requires Rp 100,000 minimum spend
- Can be used once per day
- Maximum 5 times total per user
- Valid Dec 20-26, 2025
- Expires on Dec 26, 2025 at 23:59:59

---

**End of Documentation**
