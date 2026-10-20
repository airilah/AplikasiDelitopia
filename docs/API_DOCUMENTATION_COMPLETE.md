# Delitopia API Documentation

**Base URL:** `https://delitopia.softindopp.com/api`  
**Version:** 1.0 | **Date:** November 18, 2025

---

## Table of Contents
- [Authentication](#authentication)
- [Auth Endpoints](#auth-endpoints)
- [Brand Endpoints](#brand-endpoints)
- [Branch Endpoints](#branch-endpoints)
- [Menu Endpoints](#menu-endpoints)
- [Order Endpoints](#order-endpoints)
- [Voucher Endpoints](#voucher-endpoints)
- [Detail Voucher Endpoints](#detail-voucher-endpoints)
- [Banner Endpoints](#banner-endpoints)
- [Password Endpoints](#password-endpoints)
- [Notification Endpoints](#notification-endpoints)
- [QR Code Endpoints](#qr-code-endpoints)
- [User Endpoints](#user-endpoints)
- [Grab Delivery](#grab-delivery)
- [Error Codes](#error-codes)
- [Flutter Guide](#flutter-implementation-guide)

---

## Authentication

JWT token required for most endpoints:
```
Authorization: Bearer {token}
```

Token expires in 60 minutes. Use `/auth/refresh` to renew.

---

## Auth Endpoints

### 1. Register
**POST** `/auth/register`

**Body:**
```json
{
  "name": "John Doe",
  "birthday": "1990-05-15",
  "gender": "M",
  "email": "john@example.com",
  "password": "password123",
  "phone_number": "08123456789"
}
```

**Response (200):**
```json
{
  "status": "success",
  "message": "Registration Successful"
}
```

---

### 2. Login
**POST** `/auth/login`

**Body:**
```json
{
  "email": "john@example.com",
  "password": "password123"
}
```

**Response (200):**
```json
{
  "status": "success",
  "data": {
    "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
    "token_type": "bearer",
    "expires_in": "2025-11-18 14:30:00"
  },
  "message": "Authentication successful"
}
```

---

### 3. Login with Google
**POST** `/auth/loginWithGoogle`

**Body:**
```json
{
  "id_token": "google_oauth_token_here"
}
```

**Response (200):** Same as login

---

### 4. Get User Profile
**GET** `/auth/me`  
**Auth Required:** Yes

**Response (200):**
```json
{
  "status": "success",
  "data": {
    "id": 22,
    "name": "John Doe",
    "email": "john@example.com",
    "photo": "https://delitopia.softindopp.com/images/profile.png",
    "birthday": "1990-05-15",
    "gender": "M",
    "phone_number": "08123456789",
    "point": 150,
    "fcm_token": "fcm_device_token",
    "is_active": "1"
  },
  "message": "User data retrieved successfully"
}
```

---

### 5. Update Profile
**POST** `/auth/edit-profile/{id}`  
**Auth Required:** Yes  
**Content-Type:** `multipart/form-data`

**Body:**
```
name: John Updated
gender: M
email: newemail@example.com
phone_number: 08123456789
photo: [file]
```

**Response (200):**
```json
{
  "status": "success",
  "message": "User updated successfully",
  "photo_url": "https://delitopia.softindopp.com/images/profile_photos/123456_photo.jpg"
}
```

---

### 6. Update FCM Token
**POST** `/auth/fcm_token/{id}`  
**Auth Required:** Yes

**Body:**
```json
{
  "fcm_token": "new_fcm_device_token"
}
```

**Response (200):**
```json
{
  "status": "success",
  "message": "User updated fcm_token successfully"
}
```

---

### 7. Logout
**POST** `/auth/logout`  
**Auth Required:** Yes

**Response (200):**
```json
{
  "status": "success",
  "message": "Successfully logged out"
}
```

---

### 8. Refresh Token
**POST** `/auth/refresh`  
**Auth Required:** Yes

**Response (200):**
```json
{
  "status": "success",
  "data": {
    "access_token": "new_token_here",
    "token_type": "bearer",
    "expires_in": "2025-11-18 15:30:00"
  },
  "message": "Authentication successful"
}
```

---

### 9. Validate Token
**GET** `/auth/token-validation`

**Response (200):**
```json
{
  "status": "success",
  "message": "Token is valid"
}
```

---

### 10. Check Email
**POST** `/auth/user-validation`  
**Auth Required:** Yes

**Body:**
```json
{
  "email": "john@example.com",
  "password": "password123"
}
```

**Response (200):**
```json
{
  "status": "success",
  "message": "Email exists and is associated with a valid account"
}
```

---

### 11. Delete Account
**POST** `/auth/delete-profile/{id}`  
**Auth Required:** Yes

**Response (200):**
```json
{
  "status": "success",
  "message": "User deleted successfully"
}
```

---

## Brand Endpoints

### 1. Get All Brands
**GET** `/getData/brand`  
**Auth Required:** Yes

**Response (200):**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "name": "Delitopia",
      "logo": "https://delitopia.softindopp.com/images/logo.png",
      "service": 10,
      "tax": 11,
      "category": ["Promo", "Main Course", "Beverage"]
    }
  ],
  "message": "Brand data retrieved successfully"
}
```

---

## Branch Endpoints

### 1. Get All Branches
**GET** `/getData/branch`  
**Auth Required:** Yes

**Response (200):**
```json
{
  "status": "success",
  "data": [
    {
      "id": 89,
      "brand_id": 1,
      "brand_name": "Delitopia",
      "code": "DL001",
      "outlet": "Tunjungan Plaza",
      "location": "Surabaya",
      "address": "Jl. Tunjungan No. 1, Surabaya",
      "district": "Genteng",
      "pos_code": "60275",
      "opening_hours": "10:00",
      "closing_hours": "22:00",
      "latitude": "-7.2629855",
      "longitude": "112.7395058"
    }
  ],
  "message": "Branches data retrieved successfully"
}
```

---

### 2. Get Branches by Brand
**POST** `/getData/branchByBrand`  
**Auth Required:** Yes

**Body:**
```json
{
  "brand": "1"
}
```
Use `"brand": "all"` to get all branches.

**Response (200):**
```json
{
  "status": "success",
  "data": [
    {
      "id": 89,
      "brand_id": 1,
      "brand_name": "Delitopia",
      "brand_logo": "https://delitopia.softindopp.com/images/logo.png",
      "code": "DL001",
      "outlet": "Tunjungan Plaza",
      "location": "Surabaya",
      "address": "Jl. Tunjungan No. 1",
      "district": "Genteng",
      "pos_code": "60275",
      "opening_hours": "10:00",
      "closing_hours": "22:00",
      "longitude": "112.7395058",
      "latitude": "-7.2629855"
    }
  ],
  "message": "Branches data retrieved successfully"
}
```

---

## Menu Endpoints

### 1. Get All Menus
**GET** `/getData/menu`  
**Auth Required:** Yes

**Response (200):**
```json
{
  "status": "success",
  "data": [
    {
      "id": 16318,
      "code": "M001",
      "name": "Nasi Goreng Special",
      "photo": "https://delitopia.softindopp.com/images/menu/nasi_goreng.jpg",
      "price": 35000,
      "description": "Delicious fried rice",
      "brand_id": 1,
      "category": "Main Course",
      "is_active": 0
    }
  ],
  "message": "Menus data retrieved successfully"
}
```

---

### 2. Get Menu by Brand or Category
**POST** `/getData/menuByBranch`  
**Auth Required:** Yes

**Body:**
```json
{
  "type": "brand",
  "data": "1"
}
```
OR
```json
{
  "type": "category",
  "data": "Promo"
}
```

Use `"data": "all"` for all menus.

**Response (200):**
```json
{
  "status": "success",
  "data": [
    {
      "id": 16318,
      "code": "M001",
      "name": "Nasi Goreng Special",
      "photo": "https://delitopia.softindopp.com/images/menu.jpg",
      "price": 35000,
      "description": "Fried rice with special sauce",
      "popularity": 1,
      "brand_id": 1,
      "brand_name": "Delitopia",
      "category": "Main Course"
    }
  ],
  "message": "Menus data retrieved successfully"
}
```

**Popularity:** Items with IDs `[16366, 16318, 16606, 16701, 26831, 27665, 31928, 94530]` have `popularity: 1`

---

### 3. Get Menu by Branch and Brand
**POST** `/getData/menuByBranches`  
**Auth Required:** Yes

**Body:**
```json
{
  "type": "brand",
  "data": "1",
  "branches": "89"
}
```

**Response (200):**
```json
{
  "status": "success",
  "data": [
    {
      "id": 16318,
      "code": "M001",
      "name": "Nasi Goreng",
      "photo": "https://url.jpg",
      "price": 35000,
      "description": "Delicious",
      "brand_id": 1,
      "brand_name": "Delitopia",
      "branches_id": 89,
      "branches_outlet": "Tunjungan Plaza",
      "branches_location": "Surabaya",
      "category": "Main Course"
    }
  ],
  "message": "Menus data retrieved successfully"
}
```

---

## Order Endpoints

### 1. Create Order
**POST** `/postData/order`  
**Auth Required:** Yes

**Body:**
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
      "menu_id": 16318,
      "menu_code": "M001",
      "notes": "No onions",
      "qty": 2,
      "total": 50000
    }
  ]
}
```

**Payment values:** `"qris"`, `"cash"`, `"qr"` (case insensitive)

**Response (200) - QRIS:**
```json
{
  "status": "success",
  "data": {
    "payment_method": "QRIS",
    "qr_string": "00020101021226670016COM.NOBUBANK.WWW...",
    "expired_time": "2025-11-18T10:42:53.255+07:00",
    "transaction_id": "019a9501-2ba4-708d-b823-58eacce57730",
    "external_id": "D3L1T0P1A-251118-22-679",
    "order_id": "ORD-89-02-00008"
  },
  "message": "success create payment"
}
```

**Response (200) - Cash:**
```json
{
  "status": "success",
  "data": {
    "payment_method": "CASH",
    "order_id": "ORD-89-02-00008",
    "response": {
      "status": "success"
    }
  },
  "message": "Order has been created successfully."
}
```

---

### 2. Create Order (with Delivery Fee)
**POST** `/postData/order-new`  
**Auth Required:** Yes

**Body:** Same as Create Order, plus:
```json
{
  "delivery_fee": 10000,
  "deliver_address": "Jl. Example No. 123",
  "deliver_lat": -7.250445,
  "deliver_long": 112.768845
}
```

**Response:** Same as Create Order

---

### 3. Get Order History
**POST** `/getData/historyOrder`  
**Auth Required:** Yes

**Body:**
```json
{
  "user_id": "22",
  "type": "status",
  "status": "pending"
}
```
OR
```json
{
  "user_id": "22",
  "type": "order_id",
  "order_id": "ORD-89-02-00008"
}
```

**Status values:** `"pending"`, `"success"`

**Response (200):**
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
      "pg_qr_string": "00020101...",
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
      "brand_logo": "https://delitopia.softindopp.com/images/logo.png",
      "branch_address": "Jl. Tunjungan No. 1",
      "track_url": null,
      "details": [
        {
          "id": 456,
          "order_id": 123,
          "menu_id": 16318,
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

**For `status: "success"`**, orders are grouped by date:
```json
{
  "status": "success",
  "data": [
    {
      "date": "2025-11-18",
      "orders": [...]
    }
  ],
  "message": "Completed orders grouped by date retrieved successfully"
}
```

---

### 4. Mark Order as Paid
**POST** `/postData/order-paid`  
**Auth Required:** Yes

**Body:**
```json
{
  "order_id": "ORD-89-02-00008"
}
```

**Response (200):**
```json
{
  "status": "success",
  "message": "Order status updated to paid"
}
```

---

### 5. Update Order Status
**POST** `/postData/order-status`  
**Auth Required:** Yes

**Body:**
```json
{
  "order_id": "ORD-89-02-00008",
  "status": "paid"
}
```

**Status values:** `"paid"`, `"completed"`

**Valid transitions:**
- `pending` → `paid` or `completed`
- `paid` → `completed`

**Response (200):**
```json
{
  "status": "success",
  "message": "Order status updated to paid"
}
```

---

### 6. Get Point History
**POST** `/getData/historyPoint`  
**Auth Required:** Yes

**Body:**
```json
{
  "user_id": "22"
}
```

**Response (200):**
```json
{
  "status": "success",
  "data": [
    {
      "expired_at": "2026-11-28",
      "point": "15"
    }
  ],
  "message": "Valid history points retrieved successfully"
}
```

---

## Voucher Endpoints

### 1. Get Available Vouchers
**GET** `/getData/voucher`  
**Auth Required:** Yes

Returns vouchers not yet redeemed by authenticated user, valid today, excluding birthday vouchers.

**Response (200):**
```json
{
  "status": "success",
  "data": [
    {
      "id": 5,
      "voucher_name": "50% Off Main Course",
      "brand_id": 1,
      "brand_name": "Delitopia",
      "voucher_type": "discount_percentage",
      "description": "Get 50% off",
      "discount_amount": null,
      "discount_percentage": 50,
      "min_spend": 50000,
      "point": 10,
      "start_date": "2025-11-01",
      "end_date": "2025-11-30",
      "image": "https://delitopia.softindopp.com/images/voucher/voucher.jpg",
      "buy_1_get_1_buy_id": null,
      "buy_1_get_1_free_id": null,
      "free_menu_item_id": null,
      "buy_1_get_1_buy_name": null,
      "buy_1_get_1_free_name": null,
      "buy_1_get_1_free_code": null,
      "free_menu_name": null,
      "free_menu_code": null
    }
  ],
  "message": "Vouchers data retrieved successfully"
}
```

---

### 2. Get All Vouchers (Admin)
**GET** `/getData/voucher-list`  
**Auth Required:** Yes

**Response (200):** Same structure as above, includes all vouchers

---

### 3. Get Voucher Details
**GET** `/getData/voucher-show/{id}`  
**Auth Required:** Yes

**Response (200):**
```json
{
  "status": "success",
  "data": {
    "id": 5,
    "voucher_name": "50% Off",
    "brand_id": 1,
    "brand_name": "Delitopia",
    "voucher_type": "discount_percentage",
    "description": "Description here",
    "discount_amount": null,
    "discount_percentage": 50,
    "min_spend": 50000,
    "point": 10,
    "start_date": "2025-11-01",
    "end_date": "2025-11-30",
    "image": "https://url.jpg",
    "buy_1_get_1_buy_id": null,
    "buy_1_get_1_free_id": null,
    "free_menu_item_id": null
  },
  "message": "Banner data retrieved successfully!"
}
```

---

### 4. Create Voucher
**POST** `/postData/voucher-create`  
**Auth Required:** Yes  
**Content-Type:** `multipart/form-data`

**Body:**
```
image: [file]
voucher_name: Summer Sale
brand_id: 1
voucher_type: discount_percentage
description: Get 30% off
discount_amount: null
discount_percentage: 30
min_spend: 50000
point: 15
start_date: 2025-11-01
end_date: 2025-11-30
buy_1_get_1_buy_id: null
buy_1_get_1_free_id: null
free_menu_item_id: null
```

**Voucher types:** `discount_percentage`, `discount_amount`, `buy_1_get_1`, `free_item`, `birthday`, `welcome`

**Response (200):**
```json
{
  "status": "success",
  "message": "Voucher created successfully!",
  "data": {
    "id": 10,
    "voucher_name": "Summer Sale",
    "brand_id": 1
  }
}
```

---

### 5. Update Voucher
**POST** `/postData/voucher-update/{id}`  
**Auth Required:** Yes  
**Content-Type:** `multipart/form-data`

**Body:** Same as Create Voucher

**Response (200):**
```json
{
  "status": "success",
  "message": "Voucher updated successfully!",
  "data": {...}
}
```

---

## Detail Voucher Endpoints

### 1. Get User Vouchers
**POST** `/getData/user-voucher`  
**Auth Required:** Yes

**Body:**
```json
{
  "user_id": 22
}
```

**Response (200):**
```json
{
  "status": "success",
  "data": [
    {
      "id": 50,
      "user_id": 22,
      "voucher_id": 5,
      "status": "unused",
      "voucher_name": "50% Off",
      "brand_name": "Delitopia",
      "voucher_type": "discount_percentage",
      "description": "Get 50% off",
      "discount_amount": null,
      "discount_percentage": 50,
      "min_spend": 50000,
      "point": 10,
      "start_date": "2025-11-01",
      "end_date": "2025-11-30",
      "image": "https://url.jpg",
      "created_at": "2025-11-18T10:00:00.000000Z"
    }
  ],
  "message": "User vouchers data retrieved successfully"
}
```

---

### 2. Redeem Voucher
**POST** `/postData/use-voucher`  
**Auth Required:** Yes

**Body:**
```json
{
  "user_id": 22,
  "voucher_id": 5
}
```

**Response (200):**
```json
{
  "status": "success",
  "message": "Voucher redeemed successfully"
}
```

**Error (400):**
```json
{
  "status": "failed",
  "message": "Insufficient point"
}
```

---

### 3. Redeem Birthday Voucher
**POST** `/birthday-voucher`

**Body:**
```json
{
  "user_id": 22,
  "voucher_id": 5
}
```

**Response:** Same as Redeem Voucher

---

## Banner Endpoints

### 1. Get Active Banners
**GET** `/getData/banner`  
**Auth Required:** Yes

Returns banners valid today.

**Response (200):**
```json
{
  "status": "success",
  "data": [
    {
      "id": 10,
      "title": "Grand Opening",
      "description": "50% off all items",
      "photo": "https://delitopia.softindopp.com/images/banners/banner.jpg",
      "popup": "https://delitopia.softindopp.com/images/banners/popup/popup.jpg",
      "start_date": "2025-11-01",
      "end_date": "2025-11-30"
    }
  ],
  "message": "Banner data retrieved successfully"
}
```

---

### 2. Get Banner Details
**GET** `/getData/banner-show/{id}`  
**Auth Required:** Yes

**Response (200):**
```json
{
  "status": "success",
  "data": {
    "id": 10,
    "title": "Grand Opening",
    "description": "50% off",
    "photo": "https://url.jpg",
    "popup": "https://url.jpg",
    "start_date": "2025-11-01",
    "end_date": "2025-11-30"
  },
  "message": "Banner data retrieved successfully!"
}
```

---

### 3. Create Banner
**POST** `/postData/banner-create`  
**Auth Required:** Yes  
**Content-Type:** `multipart/form-data`

**Body:**
```
photo: [file]
popup: [file]
title: Grand Opening
description: 50% off all items
start_date: 2025-11-01
end_date: 2025-11-30
```

**Response (200):**
```json
{
  "status": "success",
  "message": "Banner created successfully!",
  "data": {
    "id": 10,
    "title": "Grand Opening"
  }
}
```

---

### 4. Update Banner
**POST** `/postData/banner-update/{id}`  
**Auth Required:** Yes  
**Content-Type:** `multipart/form-data`

**Body:** Same as Create Banner (all fields optional)

**Response (200):**
```json
{
  "status": "success",
  "message": "Banner updated successfully!",
  "data": {...}
}
```

---

## Password Endpoints

### 1. Send OTP
**POST** `/password/forgot`

**Body:**
```json
{
  "email": "john@example.com"
}
```

**Response (200):**
```json
{
  "status": "success",
  "message": "OTP has been sent to your email"
}
```

OTP expires in 10 minutes.

---

### 2. Validate OTP
**POST** `/password/otp`

**Body:**
```json
{
  "email": "john@example.com",
  "otp": 123456
}
```

**Response (200):**
```json
{
  "status": "success",
  "message": "OTP code is valid"
}
```

---

### 3. Reset Password
**POST** `/password/reset`

**Body:**
```json
{
  "email": "john@example.com",
  "otp": 123456,
  "password": "newpassword123",
  "password_confirmation": "newpassword123"
}
```

**Response (200):**
```json
{
  "status": "success",
  "message": "Password reset successfully"
}
```

---

### 4. Update Password
**POST** `/password/update`

**Body:**
```json
{
  "email": "john@example.com",
  "old_password": "oldpassword",
  "password": "newpassword123",
  "password_confirmation": "newpassword123"
}
```

**Response (200):**
```json
{
  "status": "success",
  "message": "Password updated successfully"
}
```

---

## Notification Endpoints

### 1. Get All Notifications
**GET** `/getData/notification`  
**Auth Required:** Yes

**Response (200):**
```json
{
  "message": "Notifications retrieved successfully.",
  "data": [
    {
      "id": 1,
      "title": "Order Confirmed",
      "body": "Your order has been confirmed",
      "image": "https://url.jpg",
      "type": "order",
      "type_data": "ORD-89-02-00008",
      "title_promo": null,
      "image_promo": null,
      "id_order": "ORD-89-02-00008",
      "status_order": "paid",
      "created_at": "2025-11-18T10:00:00.000000Z"
    }
  ]
}
```

---

### 2. Get Notification Details
**GET** `/getData/notification-show/{id}`  
**Auth Required:** Yes

**Response (200):**
```json
{
  "message": "Notification retrieved successfully.",
  "data": {
    "id": 1,
    "title": "Order Confirmed",
    "body": "Your order has been confirmed",
    "image": "https://url.jpg",
    "type": "order",
    "type_data": "ORD-89-02-00008"
  }
}
```

---

### 3. Send Notification
**POST** `/send-notification`  
**Auth Required:** Yes  
**Content-Type:** `multipart/form-data`

**Body:**
```
title: Order Update
body: Your order is ready
image: [file]
type: order
typeData: ORD-89-02-00008
titlePromo: null
imagePromo: null
idOrder: ORD-89-02-00008
statusOrder: paid
```

**Response (200):**
```json
{
  "message": "Notification sent successfully.",
  "data": {...}
}
```

---

## QR Code Endpoints

### 1. Get All QR Codes
**GET** `/getData/qr`  
**Auth Required:** Yes

**Response (200):**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "brand_id": 1,
      "branch_id": 89,
      "table_number": "A5",
      "qr_code": "https://delitopia.softindopp.com/images/scan_qr/qr_123.png",
      "qr_text": "base64_encoded_data"
    }
  ],
  "message": "QR data retrieved successfully"
}
```

---

### 2. Get QR Details
**GET** `/getData/qr-show/{id}`  
**Auth Required:** Yes

**Response (200):**
```json
{
  "status": "success",
  "data": {
    "id": 1,
    "brand_id": 1,
    "branch_id": 89,
    "table_number": "A5",
    "qr_code": "https://url.png",
    "qr_text": "base64_data"
  },
  "message": "QR data retrieved successfully!"
}
```

---

### 3. Create QR Code
**POST** `/postData/create-qr`  
**Auth Required:** Yes

**Body:**
```json
{
  "brand": 1,
  "branch": 89,
  "table_number": "A5"
}
```

**Response (200):**
```json
{
  "status": "success",
  "message": "QR code created successfully",
  "data": {
    "qr_code_url": "https://delitopia.softindopp.com/images/scan_qr/qr_123.png",
    "qr_text": "base64_encoded_data"
  }
}
```

---

### 4. Decode QR Code
**POST** `/postData/decode-qr`  
**Auth Required:** Yes

**Body:**
```json
{
  "qr_text": "base64_encoded_data"
}
```

**Response (200):**
```json
{
  "status": "success",
  "data": {
    "brand": 1,
    "branch": 89,
    "table_number": "A5"
  },
  "message": "QR decoded successfully"
}
```

---

## User Endpoints

### 1. Get All Users
**GET** `/getData/user-all`  
**Auth Required:** Yes

**Response (200):**
```json
{
  "status": "success",
  "data": [
    {
      "id": 22,
      "name": "John Doe",
      "email": "john@example.com",
      "phone_number": "08123456789",
      "point": 150,
      "is_active": "1"
    }
  ],
  "message": "User data retrieved successfully"
}
```

---

## Grab Delivery

### 1. Get Delivery Quotes
**POST** `/postData/grab-quotes`  
**Auth Required:** Yes

**Body:**
```json
{
  "branch_id": 89,
  "destination": {
    "address": "Jl. Example No. 123",
    "lat": -7.250445,
    "lng": 112.768845
  },
  "user_id": 22,
  "packages": [
    {
      "name": "Nasi Goreng",
      "description": "Extra spicy",
      "quantity": 2,
      "price": 35000,
      "dimensions": {
        "height": 10,
        "width": 15,
        "depth": 5,
        "weight": 500
      }
    }
  ]
}
```

**Response (200):**
```json
{
  "quotes": [
    {
      "service_type": "INSTANT",
      "amount": 15000,
      "currency": "IDR",
      "estimated_duration": "30-45 mins"
    }
  ]
}
```

---

## Webhooks

### 1. Payment Callback
**POST** `/payment/callback`

Webhook from MC Payment after transaction.

**Body:**
```json
{
  "external_id": "D3L1T0P1A-251118-22-679",
  "order_id": "ORD-89-02-00008",
  "transaction_status": "PAID",
  "payment_details": {
    "paid_time": "2025-11-18T10:30:00+07:00"
  },
  "reference_id": "MC123456",
  "response_code": "00"
}
```

**Response (200):**
```json
{
  "status": "success",
  "message": "Callback processed"
}
```

---

### 2. GrabExpress Webhook
**POST** `/grabexpress`

Webhook from GrabExpress for delivery updates.

**Body:**
```json
{
  "deliveryID": "GRAB123456",
  "status": "COMPLETED",
  "trackURL": "https://grab.com/track/123"
}
```

**Response (200):**
```json
{
  "status": "success"
}
```

---

## Error Codes

| Status | Message | Description |
|--------|---------|-------------|
| 200 | Success | Request successful |
| 400 | Bad Request | Validation error or invalid data |
| 401 | Unauthorized | Invalid or missing token |
| 404 | Not Found | Resource not found |
| 500 | Internal Server Error | Server error |

**Common Error Response:**
```json
{
  "status": "failed",
  "message": "The email field is required."
}
```

---

## Flutter Implementation Guide

### 1. Setup HTTP Client
```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const baseUrl = 'https://delitopia.softindopp.com/api';
  String? token;

  void setToken(String newToken) {
    token = newToken;
  }

  Map<String, String> getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
```

### 2. Login Example
```dart
Future<Map<String, dynamic>> login(String email, String password) async {
  final response = await http.post(
    Uri.parse('$baseUrl/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    token = data['data']['access_token'];
    return data;
  } else {
    throw Exception('Login failed');
  }
}
```

### 3. Create Order Example
```dart
Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData) async {
  final response = await http.post(
    Uri.parse('$baseUrl/postData/order'),
    headers: getHeaders(),
    body: jsonEncode(orderData),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Order creation failed');
  }
}
```

### 4. Display QR Code
```dart
import 'package:qr_flutter/qr_flutter.dart';

Widget buildQRCode(String qrString) {
  return QrImageView(
    data: qrString,
    version: QrVersions.auto,
    size: 250.0,
    backgroundColor: Colors.white,
  );
}
```

### 5. Upload Image (Multipart)
```dart
Future<Map<String, dynamic>> updateProfile(
  int userId, 
  File? photo, 
  Map<String, String> data
) async {
  var request = http.MultipartRequest(
    'POST',
    Uri.parse('$baseUrl/auth/edit-profile/$userId'),
  );

  request.headers.addAll({
    'Authorization': 'Bearer $token',
  });

  if (photo != null) {
    request.files.add(
      await http.MultipartFile.fromPath('photo', photo.path),
    );
  }

  request.fields.addAll(data);

  var response = await request.send();
  var responseBody = await response.stream.bytesToString();

  return jsonDecode(responseBody);
}
```

### 6. Model Classes
```dart
class User {
  final int id;
  final String name;
  final String email;
  final String phoneNumber;
  final int point;

  User.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      name = json['name'],
      email = json['email'],
      phoneNumber = json['phone_number'],
      point = json['point'];
}

class Order {
  final int id;
  final String orderId;
  final String orderType;
  final double finalTotal;
  final String payment;
  final String status;
  final String? qrString;
  final DateTime? qrExpired;

  Order.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      orderId = json['order_id'],
      orderType = json['order_type'],
      finalTotal = json['final_total'].toDouble(),
      payment = json['payment'],
      status = json['status'],
      qrString = json['pg_qr_string'],
      qrExpired = json['pg_expired_qr'] != null 
        ? DateTime.parse(json['pg_expired_qr']) 
        : null;
}

class Menu {
  final int id;
  final String code;
  final String name;
  final String photo;
  final double price;
  final String description;
  final int brandId;
  final String category;

  Menu.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      code = json['code'],
      name = json['name'],
      photo = json['photo'],
      price = json['price'].toDouble(),
      description = json['description'],
      brandId = json['brand_id'],
      category = json['category'];
}
```

### 7. Error Handling
```dart
Future<T> handleApiCall<T>(Future<http.Response> Function() apiCall) async {
  try {
    final response = await apiCall();
    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data as T;
    } else if (response.statusCode == 401) {
      throw Exception('Session expired. Please login again.');
    } else {
      throw Exception(data['message'] ?? 'Request failed');
    }
  } catch (e) {
    throw Exception('Network error: $e');
  }
}
```

### 8. Payment Status Polling
```dart
import 'dart:async';

Timer? _pollingTimer;

void startPollingOrderStatus(String orderId, Function(String) onStatusChange) {
  _pollingTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
    try {
      final order = await getOrderById(orderId);
      if (order['status'] == 'paid') {
        timer.cancel();
        onStatusChange('paid');
      }
    } catch (e) {
      print('Polling error: $e');
    }
  });
}

void stopPolling() {
  _pollingTimer?.cancel();
}
```

---

## Notes

### Point System
- Points = `floor(grand_total / 10000)`
- Example: Rp 77,000 = 7 points
- Points expire after 1 year (day 28)

### Payment Methods
- **QRIS**: QR payment via MC Payment (15min expiry)
- **CASH**: Manual confirmation required
- **QR**: Alternative QR payment

### Order Status Flow
1. `pending` - Order created, waiting payment
2. `paid` - Payment confirmed
3. `completed` - Order fulfilled
4. `expired` - Not paid within time limit
5. `failed` - Payment failed

### Order ID Format
- Format: `ORD-{branch_id}-{type_code}-{count}`
- Type codes: `01` = dine in, `02` = take away/delivery
- Example: `ORD-89-02-00008`

### External ID Format
- Format: `D3L1T0P1A-{YYMMDD}-{user_id}-{random3digits}`
- Example: `D3L1T0P1A-251118-22-679`

### Voucher System
- Birthday vouchers: All birthday vouchers for user marked as used
- Welcome vouchers: Auto-created on registration
- Redemption requires sufficient points

---

## Support

**Email:** delitopiagroup@gmail.com  
**Logs:** `/storage/logs/laravel.log`

**Payment Gateway:**
- Provider: MC Payment
- Environment: Live
- Merchant ID: MC2024103198

---

**End of Documentation**
