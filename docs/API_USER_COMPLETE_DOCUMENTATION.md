# Delitopia Food Ordering System - Complete User API Documentation

**Version:** 2.0  
**Last Updated:** December 1, 2025  
**Base URL:** `https://delitopia.softindopp.com/api`

---

## Table of Contents

1. [Authentication](#authentication)
2. [User Management](#user-management)
3. [Brand & Branch](#brand--branch)
4. [Menu System](#menu-system)
5. [Orders](#orders)
6. [Vouchers & Promotions](#vouchers--promotions)
7. [Points & Gamification](#points--gamification)
8. [Reviews & Ratings](#reviews--ratings)
9. [Favorites](#favorites)
10. [Shopping Cart](#shopping-cart)
11. [Search](#search)
12. [Addresses](#addresses)
13. [Notifications](#notifications)
14. [Payment](#payment)
15. [Delivery (Grab Express)](#delivery)
16. [QR Codes](#qr-codes)
17. [Banners](#banners)
18. [Analytics](#analytics)
19. [Support](#support)

---

## Authentication

### Register New User

Create a new user account.

**Endpoint:** `POST /api/auth/register`

**Request Body:**
```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "password": "password123",
  "password_confirmation": "password123",
  "phone": "08123456789",
  "date_of_birth": "1990-01-15"
}
```

**Response:**
```json
{
  "status": "success",
  "message": "User registered successfully",
  "data": {
    "user": {
      "id": 1,
      "name": "John Doe",
      "email": "john@example.com",
      "phone": "08123456789"
    },
    "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
    "token_type": "bearer",
    "expires_in": 5184000
  }
}
```

---

### Login

Authenticate user and get access token.

**Endpoint:** `POST /api/auth/login`

**Request Body:**
```json
{
  "email": "john@example.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "token_type": "bearer",
  "expires_in": 5184000
}
```

---

### Login with Google

Authenticate using Google OAuth.

**Endpoint:** `POST /api/auth/loginWithGoogle`

**Request Body:**
```json
{
  "id_token": "google_id_token_here",
  "name": "John Doe",
  "email": "john@example.com",
  "photo": "https://lh3.googleusercontent.com/..."
}
```

**Response:**
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "token_type": "bearer",
  "expires_in": 5184000,
  "user": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com"
  }
}
```

---

### Get Current User

Get authenticated user information.

**Endpoint:** `GET /api/auth/me`

**Headers:**
```
Authorization: Bearer {token}
```

**Response:**
```json
{
  "id": 1,
  "name": "John Doe",
  "email": "john@example.com",
  "phone": "08123456789",
  "date_of_birth": "1990-01-15",
  "points": 1500,
  "user_level_id": 2,
  "level": {
    "id": 2,
    "name": "Silver",
    "min_spending": 500000,
    "discount_percentage": 5
  }
}
```

---

### Refresh Token

Refresh the JWT access token.

**Endpoint:** `POST /api/auth/refresh`

**Headers:**
```
Authorization: Bearer {old_token}
```

**Response:**
```json
{
  "access_token": "new_token_here",
  "token_type": "bearer",
  "expires_in": 5184000
}
```

---

### Logout

Invalidate the current token.

**Endpoint:** `POST /api/auth/logout`

**Headers:**
```
Authorization: Bearer {token}
```

**Response:**
```json
{
  "message": "Successfully logged out"
}
```

---

### Update Profile

Update user profile information.

**Endpoint:** `POST /api/auth/edit-profile/{userId}`

**Headers:**
```
Authorization: Bearer {token}
Content-Type: multipart/form-data
```

**Request Body:**
```
name: John Smith
phone: 08123456789
date_of_birth: 1990-01-15
photo: [file]
```

**Response:**
```json
{
  "status": "success",
  "message": "Profile updated successfully",
  "data": {
    "id": 1,
    "name": "John Smith",
    "email": "john@example.com",
    "phone": "08123456789",
    "photo": "https://delitopia.softindopp.com/images/users/john.jpg"
  }
}
```

---

### Update FCM Token

Update Firebase Cloud Messaging token for push notifications.

**Endpoint:** `POST /api/auth/fcm_token/{userId}`

**Request Body:**
```json
{
  "fcm_token": "firebase_token_here"
}
```

---

### Password Management

#### Forgot Password (Send OTP)

**Endpoint:** `POST /api/password/forgot`

**Request Body:**
```json
{
  "email": "john@example.com"
}
```

**Response:**
```json
{
  "status": "success",
  "message": "OTP sent to your email"
}
```

---

#### Validate OTP

**Endpoint:** `POST /api/password/otp`

**Request Body:**
```json
{
  "email": "john@example.com",
  "otp": "123456"
}
```

**Response:**
```json
{
  "status": "success",
  "message": "OTP validated successfully",
  "reset_token": "reset_token_here"
}
```

---

#### Reset Password

**Endpoint:** `POST /api/password/reset`

**Request Body:**
```json
{
  "email": "john@example.com",
  "reset_token": "reset_token_here",
  "password": "new_password",
  "password_confirmation": "new_password"
}
```

---

#### Update Password (Authenticated)

**Endpoint:** `POST /api/password/update`

**Headers:**
```
Authorization: Bearer {token}
```

**Request Body:**
```json
{
  "current_password": "old_password",
  "new_password": "new_password",
  "new_password_confirmation": "new_password"
}
```

---

## User Management

### Check Email Availability

Check if email is already registered.

**Endpoint:** `POST /api/auth/user-validation`

**Request Body:**
```json
{
  "email": "john@example.com"
}
```

**Response:**
```json
{
  "available": false,
  "message": "Email already registered"
}
```

---

### Delete Account

Delete user account (soft delete).

**Endpoint:** `POST /api/auth/delete-profile/{userId}`

**Headers:**
```
Authorization: Bearer {token}
```

**Response:**
```json
{
  "status": "success",
  "message": "Account deleted successfully"
}
```

---

## Brand & Branch

### Get All Brands

Retrieve all available brands.

**Endpoint:** `GET /api/getData/brand`

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
      "name": "TOMOKO",
      "logo": "https://delitopia.softindopp.com/images/brands/tomoko.png",
      "description": "Japanese Restaurant"
    }
  ]
}
```

---

### Get All Branches

Retrieve all branches.

**Endpoint:** `GET /api/getData/branch`

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
      "id": 90,
      "outlet": "Central Park",
      "location": "Jakarta",
      "address": "Jl. Letjen S. Parman Kav. 28",
      "phone": "021-12345678",
      "brand_id": 1,
      "latitude": -6.1753924,
      "longitude": 106.7909689
    }
  ]
}
```

---

### Get Branches by Brand

Filter branches by brand ID.

**Endpoint:** `POST /api/getData/branchByBrand`

**Headers:**
```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body:**
```json
{
  "brand_id": 1
}
```

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 90,
      "outlet": "Central Park",
      "location": "Jakarta",
      "brand_id": 1
    }
  ]
}
```

---

## Menu System

### Get All Menus

**Endpoint:** `GET /api/getData/menu`

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
      "code": "P000055",
      "name": "Aburi Crispy Salmon L",
      "photo": "https://delitopia.softindopp.com/images/menus/...",
      "price": 45000,
      "description": "Aburi Crispy Salmon L",
      "brand_id": 1,
      "brand_name": "TOMOKO",
      "category": "SUSHI"
    }
  ],
  "message": "Menus data retrieved successfully"
}
```

---

### Get Menus by Brand/Category

**Endpoint:** `POST /api/getData/menuByBranch`

**Request Body:**
```json
{
  "type": "brand",
  "data": "1"
}
```

Or by category:
```json
{
  "type": "category",
  "data": "SUSHI"
}
```

---

### Get Menus by Branch (Recommended)

Get branch-specific menus with accurate pricing.

**Endpoint:** `POST /api/getData/menuByBranches`

**Request Body:**
```json
{
  "type": "brand",
  "data": "1",
  "branches": "90"
}
```

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "code": "P000055",
      "name": "Aburi Crispy Salmon L",
      "photo": "https://delitopia.softindopp.com/images/menus/...",
      "price": 45000,
      "description": "Aburi Crispy Salmon L",
      "brand_id": 1,
      "brand_name": "TOMOKO",
      "branches_id": 90,
      "branches_outlet": "Central Park",
      "branches_location": "Jakarta",
      "category": "SUSHI"
    }
  ]
}
```

---

### Get Menu Categories

**Endpoint:** `GET /api/getData/menus/categories`

**Query Parameters:**
- `brand_id` (optional): Filter by brand

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "category": "SUSHI",
      "count": 45
    },
    {
      "category": "RAMEN",
      "count": 23
    }
  ]
}
```

---

## Orders

### Create Order

Create a new order.

**Endpoint:** `POST /api/postData/order-new`

**Headers:**
```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body:**
```json
{
  "branch_id": 90,
  "delivery_method": "delivery",
  "payment_method": "cash",
  "delivery_address": "Jl. Example No. 123",
  "delivery_fee": 15000,
  "voucher_id": null,
  "notes": "Extra spicy please",
  "items": [
    {
      "menu_id": 1,
      "quantity": 2,
      "price": 45000,
      "notes": ""
    },
    {
      "menu_id": 5,
      "quantity": 1,
      "price": 35000,
      "notes": "No onions"
    }
  ]
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Order created successfully",
  "data": {
    "order_id": "ORD-20251201-001",
    "total_amount": 140000,
    "status": "pending",
    "payment_url": "https://payment.gateway.com/pay/xxx"
  }
}
```

---

### Get Order History

**Endpoint:** `POST /api/getData/historyOrder`

**Request Body:**
```json
{
  "user_id": 1
}
```

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": "ORD-20251201-001",
      "created_at": "2025-12-01 10:30:00",
      "total_amount": 140000,
      "status": "completed",
      "branch": {
        "id": 90,
        "outlet": "Central Park"
      },
      "items": [
        {
          "menu_name": "Aburi Crispy Salmon L",
          "quantity": 2,
          "price": 45000
        }
      ]
    }
  ]
}
```

---

### Mark Order as Paid

**Endpoint:** `POST /api/postData/order-paid`

**Request Body:**
```json
{
  "order_id": "ORD-20251201-001",
  "payment_proof": "base64_image_or_url"
}
```

---

### Get Points History

**Endpoint:** `POST /api/getData/historyPoint`

**Request Body:**
```json
{
  "user_id": 1
}
```

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "type": "earn",
      "points": 100,
      "description": "Order ORD-20251201-001",
      "created_at": "2025-12-01 10:30:00"
    },
    {
      "type": "redeem",
      "points": -50,
      "description": "Voucher redemption",
      "created_at": "2025-12-01 09:00:00"
    }
  ]
}
```

---

## Vouchers & Promotions

### Get Available Vouchers

**Endpoint:** `GET /api/getData/voucher`

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "code": "DISC20",
      "title": "20% Discount",
      "description": "Get 20% off for all menu",
      "discount_type": "percentage",
      "discount_value": 20,
      "min_purchase": 100000,
      "max_discount": 50000,
      "valid_from": "2025-12-01",
      "valid_until": "2025-12-31",
      "usage_limit": 100,
      "used_count": 25
    }
  ]
}
```

---

### Get My Vouchers

**Endpoint:** `GET /api/getData/my-vouchers`

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "voucher": {
        "code": "DISC20",
        "title": "20% Discount",
        "discount_value": 20
      },
      "status": "active",
      "used_at": null,
      "expires_at": "2025-12-31"
    }
  ]
}
```

---

### Get My Active Vouchers

**Endpoint:** `GET /api/getData/my-active-vouchers`

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "code": "DISC20",
      "title": "20% Discount",
      "discount_value": 20,
      "can_use": true,
      "expires_in_days": 15
    }
  ]
}
```

---

### Get Vouchers for Purchase

Get vouchers available for cash purchase.

**Endpoint:** `GET /api/getData/vouchers-for-purchase`

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 5,
      "code": "PREMIUM50",
      "title": "Premium 50K Discount",
      "price": 40000,
      "discount_value": 50000,
      "purchase_type": "cash"
    }
  ]
}
```

---

### Purchase Voucher with Cash

**Endpoint:** `POST /api/postData/vouchers/purchase-cash`

**Request Body:**
```json
{
  "voucher_id": 5,
  "payment_method": "e-wallet"
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Voucher purchased successfully",
  "data": {
    "detail_voucher_id": 123,
    "voucher_code": "PREMIUM50",
    "payment_url": "https://payment.gateway.com/pay/xxx"
  }
}
```

---

### Redeem Voucher with Points

**Endpoint:** `POST /api/postData/vouchers/redeem-points`

**Request Body:**
```json
{
  "voucher_id": 3,
  "points": 500
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Voucher redeemed successfully",
  "data": {
    "voucher_code": "POINTS20",
    "remaining_points": 1000
  }
}
```

---

### Activate Voucher

Activate a purchased voucher.

**Endpoint:** `POST /api/postData/voucher-activate`

**Request Body:**
```json
{
  "detail_voucher_id": 123
}
```

---

### Use Voucher in Order

**Endpoint:** `POST /api/postData/use-voucher-api`

**Request Body:**
```json
{
  "voucher_code": "DISC20",
  "order_id": "ORD-20251201-001"
}
```

---

### Redeem Birthday Voucher

**Endpoint:** `POST /api/birthday-voucher`

**Request Body:**
```json
{
  "user_id": 1
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Birthday voucher claimed successfully",
  "data": {
    "voucher_code": "BDAY2025",
    "discount_value": 25000
  }
}
```

---

### Validate Voucher Usage

**Endpoint:** `POST /api/getData/vouchers/validate-usage`

**Request Body:**
```json
{
  "voucher_code": "DISC20",
  "user_id": 1,
  "order_amount": 150000
}
```

**Response:**
```json
{
  "valid": true,
  "can_use": true,
  "discount_amount": 30000,
  "final_amount": 120000,
  "message": "Voucher can be applied"
}
```

---

### Get Voucher Usage History

**Endpoint:** `GET /api/getData/vouchers/usage-history`

**Query Parameters:**
- `user_id`: User ID

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "voucher_code": "DISC20",
      "used_at": "2025-12-01 10:30:00",
      "order_id": "ORD-20251201-001",
      "discount_amount": 30000
    }
  ]
}
```

---

### Get All Vouchers Categorized

**Endpoint:** `GET /api/postData/vouchers/all-categorized`

**Response:**
```json
{
  "status": "success",
  "data": {
    "available": [...],
    "point_redemption": [...],
    "cash_purchase": [...],
    "my_vouchers": [...]
  }
}
```

---

## Points & Gamification

### Get User Levels

**Endpoint:** `GET /api/user-levels`

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "name": "Bronze",
      "min_spending": 0,
      "discount_percentage": 0,
      "point_multiplier": 1
    },
    {
      "id": 2,
      "name": "Silver",
      "min_spending": 500000,
      "discount_percentage": 5,
      "point_multiplier": 1.5
    }
  ]
}
```

---

### Get My Level

Get current user's level and progress.

**Endpoint:** `GET /api/user-levels/my-level`

**Response:**
```json
{
  "status": "success",
  "data": {
    "current_level": {
      "id": 2,
      "name": "Silver",
      "discount_percentage": 5
    },
    "total_spending": 750000,
    "next_level": {
      "id": 3,
      "name": "Gold",
      "min_spending": 1000000
    },
    "progress_to_next": 75,
    "amount_needed": 250000
  }
}
```

---

## Reviews & Ratings

### Create Review

**Endpoint:** `POST /api/reviews`

**Request Body:**
```json
{
  "menu_id": 1,
  "order_id": "ORD-20251201-001",
  "rating": 5,
  "comment": "Delicious!",
  "photos": ["base64_image_1", "base64_image_2"]
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Review submitted successfully",
  "data": {
    "id": 123,
    "rating": 5,
    "comment": "Delicious!"
  }
}
```

---

### Get Menu Reviews

**Endpoint:** `GET /api/reviews/menu/{menuId}`

**Response:**
```json
{
  "status": "success",
  "data": {
    "average_rating": 4.5,
    "total_reviews": 42,
    "reviews": [
      {
        "id": 123,
        "user_name": "John Doe",
        "rating": 5,
        "comment": "Delicious!",
        "photos": ["url1", "url2"],
        "created_at": "2025-12-01 10:30:00",
        "helpful_count": 5
      }
    ]
  }
}
```

---

### Reply to Review

**Endpoint:** `POST /api/reviews/{reviewId}/reply`

**Request Body:**
```json
{
  "reply": "Thank you for your feedback!"
}
```

---

### Mark Review as Helpful

**Endpoint:** `POST /api/reviews/{reviewId}/helpful`

---

### Get My Reviews

**Endpoint:** `GET /api/reviews/my-reviews`

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 123,
      "menu_name": "Aburi Crispy Salmon L",
      "rating": 5,
      "comment": "Delicious!",
      "created_at": "2025-12-01 10:30:00"
    }
  ]
}
```

---

## Favorites

### Add to Favorites

**Endpoint:** `POST /api/favorites/add`

**Request Body:**
```json
{
  "menu_id": 1
}
```

---

### Remove from Favorites

**Endpoint:** `DELETE /api/favorites/{menuId}`

---

### Get My Favorites

**Endpoint:** `GET /api/favorites`

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "menu": {
        "id": 1,
        "name": "Aburi Crispy Salmon L",
        "photo": "...",
        "price": 45000
      },
      "added_at": "2025-12-01 10:30:00"
    }
  ]
}
```

---

### Check if Menu is Favorite

**Endpoint:** `GET /api/favorites/check/{menuId}`

**Response:**
```json
{
  "is_favorite": true
}
```

---

## Shopping Cart

### Add Item to Cart

**Endpoint:** `POST /api/cart/add`

**Request Body:**
```json
{
  "menu_id": 1,
  "quantity": 2,
  "notes": "Extra spicy"
}
```

---

### Update Cart Item

**Endpoint:** `PUT /api/cart/item/{itemId}`

**Request Body:**
```json
{
  "quantity": 3,
  "notes": "Extra spicy, no onions"
}
```

---

### Remove Cart Item

**Endpoint:** `DELETE /api/cart/item/{itemId}`

---

### Get Cart

**Endpoint:** `GET /api/cart`

**Response:**
```json
{
  "status": "success",
  "data": {
    "items": [
      {
        "id": 1,
        "menu": {
          "id": 1,
          "name": "Aburi Crispy Salmon L",
          "price": 45000
        },
        "quantity": 2,
        "subtotal": 90000,
        "notes": "Extra spicy"
      }
    ],
    "total_items": 2,
    "total_amount": 90000
  }
}
```

---

### Clear Cart

**Endpoint:** `DELETE /api/cart/clear`

---

## Search

### Search Menus

**Endpoint:** `POST /api/search`

**Request Body:**
```json
{
  "query": "salmon",
  "branch_id": 90,
  "category": "SUSHI",
  "min_price": 20000,
  "max_price": 100000
}
```

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "name": "Aburi Crispy Salmon L",
      "price": 45000,
      "category": "SUSHI",
      "relevance_score": 0.95
    }
  ]
}
```

---

### Filter Menus

**Endpoint:** `POST /api/search/filter`

**Request Body:**
```json
{
  "branch_id": 90,
  "categories": ["SUSHI", "RAMEN"],
  "price_range": {
    "min": 20000,
    "max": 100000
  },
  "rating_min": 4.0
}
```

---

### Autocomplete

**Endpoint:** `GET /api/search/autocomplete?q=sal`

**Response:**
```json
{
  "suggestions": [
    "Salmon Nigiri",
    "Salmon Sashimi",
    "Crispy Salmon Roll"
  ]
}
```

---

### Trending Searches

**Endpoint:** `GET /api/search/trending`

**Response:**
```json
{
  "data": [
    "Salmon",
    "Ramen",
    "Sushi"
  ]
}
```

---

### My Search History

**Endpoint:** `GET /api/search/history`

---

### Clear Search History

**Endpoint:** `DELETE /api/search/history`

---

## Addresses

### Get My Addresses

**Endpoint:** `GET /api/addresses`

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "label": "Home",
      "address": "Jl. Example No. 123",
      "latitude": -6.1753924,
      "longitude": 106.7909689,
      "is_default": true
    }
  ]
}
```

---

### Add Address

**Endpoint:** `POST /api/addresses`

**Request Body:**
```json
{
  "label": "Office",
  "address": "Jl. Office St. No. 456",
  "latitude": -6.1753924,
  "longitude": 106.7909689,
  "notes": "2nd floor"
}
```

---

### Update Address

**Endpoint:** `PUT /api/addresses/{id}`

---

### Set Default Address

**Endpoint:** `POST /api/addresses/{id}/set-default`

---

### Delete Address

**Endpoint:** `DELETE /api/addresses/{id}`

---

### Get Nearest Branches

**Endpoint:** `POST /api/addresses/nearest-branches`

**Request Body:**
```json
{
  "latitude": -6.1753924,
  "longitude": 106.7909689,
  "radius": 5
}
```

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 90,
      "outlet": "Central Park",
      "distance_km": 2.3,
      "estimated_delivery_time": 30
    }
  ]
}
```

---

## Notifications

### Get My Notifications

**Endpoint:** `GET /api/getData/notification`

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "title": "Order Completed",
      "body": "Your order ORD-20251201-001 has been completed",
      "type": "order",
      "read_at": null,
      "created_at": "2025-12-01 10:30:00"
    }
  ]
}
```

---

### Get Unread Count

**Endpoint:** `GET /api/notifications/unread-count/{userId}`

**Response:**
```json
{
  "unread_count": 5
}
```

---

### Mark Notification as Read

**Endpoint:** `PUT /api/notifications/{id}/mark-read`

---

### Mark All as Read

**Endpoint:** `POST /api/notifications/mark-all-read`

---

## Payment

### Get Available Payment Channels

**Endpoint:** `GET /api/payment-channels`

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "name": "E-Smartlink",
      "type": "gateway",
      "methods": [
        {
          "code": "VA_BRI",
          "name": "BRI Virtual Account",
          "fee": 4000
        },
        {
          "code": "QRIS",
          "name": "QRIS",
          "fee": 0
        }
      ]
    },
    {
      "id": 2,
      "name": "Cash",
      "type": "manual"
    }
  ]
}
```

---

### Get Payment Gateway Info

**Endpoint:** `GET /api/payment-gateways/{brandId}`

**Response:**
```json
{
  "status": "success",
  "data": {
    "gateway": "esmartlink",
    "merchant_id": "MERCHANT123",
    "available_methods": ["VA_BRI", "QRIS", "TRANSFER"]
  }
}
```

---

### Create E-Smartlink Payment

**Endpoint:** `POST /api/esmartlink/create-payment`

**Request Body:**
```json
{
  "order_id": "ORD-20251201-001",
  "amount": 140000,
  "payment_method": "VA_BRI",
  "customer_name": "John Doe",
  "customer_email": "john@example.com",
  "customer_phone": "08123456789"
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "transaction_id": "TRX-001",
    "va_number": "80008123456789012",
    "payment_url": "https://payment.esmartlink.com/pay/xxx",
    "expired_at": "2025-12-01 23:59:59"
  }
}
```

---

### Check Payment Status

**Endpoint:** `GET /api/esmartlink/inquiry/{transactionId}`

**Response:**
```json
{
  "status": "success",
  "data": {
    "transaction_id": "TRX-001",
    "payment_status": "paid",
    "paid_at": "2025-12-01 11:00:00"
  }
}
```

---

### Cancel Payment

**Endpoint:** `POST /api/esmartlink/cancel/{transactionId}`

---

## Delivery (Grab Express)

### Get Delivery Quotes

**Endpoint:** `POST /api/postData/grab-quotes`

**Request Body:**
```json
{
  "origin": {
    "latitude": -6.1753924,
    "longitude": 106.7909689
  },
  "destination": {
    "latitude": -6.2087634,
    "longitude": 106.8450141
  },
  "packages": [
    {
      "name": "Food Order",
      "description": "Sushi and Ramen",
      "quantity": 2,
      "price": 140000
    }
  ]
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "quotes": [
      {
        "service_type": "INSTANT",
        "amount": 25000,
        "currency": "IDR",
        "estimated_time": 30
      }
    ]
  }
}
```

---

## QR Codes

### Decode QR Code

**Endpoint:** `POST /api/postData/decode-qr`

**Request Body:**
```json
{
  "qr_data": "QR_CODE_DATA_HERE"
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "type": "voucher",
    "voucher_code": "DISC20",
    "valid": true
  }
}
```

---

## Banners

### Get Banners

**Endpoint:** `GET /api/getData/banner`

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "title": "Grand Opening Promo",
      "image": "https://delitopia.softindopp.com/images/banners/promo1.jpg",
      "link": "https://delitopia.com/promo",
      "is_active": true
    }
  ]
}
```

---

### Get Banner Details

**Endpoint:** `GET /api/getData/banner-show/{id}`

---

## Analytics

### Get Order Statistics

**Endpoint:** `GET /api/analytics/order-stats`

**Response:**
```json
{
  "status": "success",
  "data": {
    "total_orders": 45,
    "completed_orders": 40,
    "cancelled_orders": 5,
    "total_spent": 4500000,
    "average_order_value": 100000
  }
}
```

---

### Get Spending Summary

**Endpoint:** `GET /api/analytics/spending-summary`

**Query Parameters:**
- `period`: `month`, `quarter`, `year`

**Response:**
```json
{
  "status": "success",
  "data": {
    "period": "month",
    "total_spending": 1500000,
    "by_category": {
      "SUSHI": 800000,
      "RAMEN": 500000,
      "DONBURI": 200000
    },
    "by_month": [...]
  }
}
```

---

### Get Favorite Menus

**Endpoint:** `GET /api/analytics/favorite-menus`

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "menu_name": "Aburi Crispy Salmon L",
      "order_count": 15,
      "total_spent": 675000
    }
  ]
}
```

---

### Get Recommendations

**Endpoint:** `GET /api/analytics/recommendations`

**Response:**
```json
{
  "status": "success",
  "data": {
    "based_on_favorites": [...],
    "based_on_orders": [...],
    "trending": [...]
  }
}
```

---

### Get Activity Log

**Endpoint:** `GET /api/analytics/activity-log`

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "activity_type": "order_placed",
      "description": "Placed order ORD-20251201-001",
      "created_at": "2025-12-01 10:30:00"
    }
  ]
}
```

---

### Get My Activities

**Endpoint:** `GET /api/activities/my-activities`

**Query Parameters:**
- `type`: Filter by activity type
- `limit`: Number of results

---

## Support

### Create Support Ticket

**Endpoint:** `POST /api/support/ticket`

**Request Body:**
```json
{
  "subject": "Order Issue",
  "message": "My order was not delivered",
  "order_id": "ORD-20251201-001",
  "category": "delivery"
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "ticket_id": "TKT-001",
    "status": "open"
  }
}
```

---

### Get My Tickets

**Endpoint:** `GET /api/support/tickets`

---

### Get Ticket Details

**Endpoint:** `GET /api/support/ticket/{ticketId}`

---

### Send Message to Ticket

**Endpoint:** `POST /api/support/ticket/{ticketId}/message`

**Request Body:**
```json
{
  "message": "Still waiting for response"
}
```

---

### Close Ticket

**Endpoint:** `POST /api/support/ticket/{ticketId}/close`

---

## Code Examples

### JavaScript/React Native

```javascript
// Login
const login = async (email, password) => {
  const response = await fetch('https://delitopia.softindopp.com/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password })
  });
  const data = await response.json();
  localStorage.setItem('token', data.access_token);
  return data;
};

// Get Menus
const getMenus = async (branchId) => {
  const token = localStorage.getItem('token');
  const response = await fetch('https://delitopia.softindopp.com/api/getData/menuByBranches', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      type: 'brand',
      data: 'all',
      branches: branchId.toString()
    })
  });
  return await response.json();
};

// Create Order
const createOrder = async (orderData) => {
  const token = localStorage.getItem('token');
  const response = await fetch('https://delitopia.softindopp.com/api/postData/order-new', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(orderData)
  });
  return await response.json();
};
```

---

### Flutter/Dart

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  final String baseUrl = 'https://delitopia.softindopp.com/api';
  String? token;
  
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body);
    token = data['access_token'];
    return data;
  }
  
  Future<List<dynamic>> getMenus(int branchId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/getData/menuByBranches'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'type': 'brand',
        'data': 'all',
        'branches': branchId.toString(),
      }),
    );
    final data = jsonDecode(response.body);
    return data['data'];
  }
}
```

---

## Error Codes

| Code | Message | Description |
|------|---------|-------------|
| 200 | Success | Request successful |
| 401 | Unauthorized | Invalid or expired token |
| 404 | Not Found | Resource not found |
| 422 | Validation Error | Invalid request data |
| 500 | Server Error | Internal server error |

---

**© 2025 Delitopia. All rights reserved.**
