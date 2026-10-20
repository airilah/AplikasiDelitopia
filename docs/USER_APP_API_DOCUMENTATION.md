# USER APP API DOCUMENTATION

Complete API documentation for the mobile/web app with all new features and enhancements.

**Last Updated:** 30 November 2024  
**Version:** 2.0.0  
**Base URL:** `https://your-domain.com/api`

---

## 📑 Table of Contents

1. [Authentication](#authentication)
2. [User Profile & Settings](#user-profile--settings)
3. [Password Management](#password-management)
4. [Notifications](#notifications)
5. [Vouchers](#vouchers)
6. [Orders](#orders)
7. [Gamification & Levels](#gamification--levels)
8. [Reviews](#reviews)
9. [Favorites](#favorites)
10. [Cart](#cart)
11. [Search](#search)
12. [Addresses](#addresses)
13. [Analytics](#analytics)
14. [Support](#support)
15. [Payment](#payment)
16. [Account Settings](#account-settings)

---

## 🔐 Authentication

### Login with Email

**Endpoint:** `POST /api/auth/login`

**Request:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
    "token_type": "bearer",
    "expires_in": "2024-12-30 10:00:00"
  },
  "message": "Authentication successful"
}
```

**Auto-Updates:**
- ✅ `last_login_at` updated automatically
- ✅ `is_active` set to true

---

### Login with Google

**Endpoint:** `POST /api/auth/loginWithGoogle`

**Request:**
```json
{
  "id_token": "google_oauth_token_here"
}
```

**Response:** Same as email login

**Auto-Updates:**
- ✅ `last_login_at` updated
- ✅ `is_active` set to true
- ✅ Activity logged

---

### Register

**Endpoint:** `POST /api/auth/register`

**Request:**
```json
{
  "name": "John Doe",
  "birthday": "1995-05-15",
  "gender": "M",
  "email": "john@example.com",
  "password": "password123",
  "phone_number": "081234567890"
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Registration Successful"
}
```

**Auto-Benefits:**
- ✅ 4 welcome vouchers (TOMOKO, Sushikun, Ah Bang, Delitopia)
- ✅ Bronze level assigned
- ✅ Activity logged

---

### Get User Profile

**Endpoint:** `GET /api/auth/me`

**Headers:** `Authorization: Bearer {token}`

**Response:**
```json
{
  "status": "success",
  "data": {
    "id": 10,
    "name": "John Doe",
    "email": "john@example.com",
    "phone_number": "081234567890",
    "photo": "https://domain.com/images/profile.png",
    "birthday": "1995-05-15",
    "gender": "M",
    "point": 5000,
    "user_level_id": 2,
    "total_orders": 15,
    "total_spent": 2500000,
    "last_login_at": "2024-11-30 10:00:00",
    "is_active": true
  },
  "message": "User data retrieved successfully"
}
```

---

### Update Profile

**Endpoint:** `POST /api/auth/edit-profile/{id}`

**Content-Type:** `multipart/form-data`

**Request:**
```javascript
{
  "name": "John Doe Updated",
  "gender": "M",
  "email": "newemail@example.com",
  "phone_number": "081234567890",
  "photo": File  // Optional image upload
}
```

**Response:**
```json
{
  "status": "success",
  "message": "User updated successfully",
  "photo_url": "https://domain.com/images/profile_photos/xxx.jpg"
}
```

---

### Update FCM Token

**Endpoint:** `POST /api/auth/fcm_token/{id}`

**Description:** Update Firebase Cloud Messaging token for push notifications

**Request:**
```json
{
  "fcm_token": "firebase_token_here"
}
```

**Response:**
```json
{
  "status": "success",
  "message": "User updated fcm_token successfully"
}
```

---

### Logout

**Endpoint:** `POST /api/auth/logout`

**Response:**
```json
{
  "status": "success",
  "message": "Successfully logged out"
}
```

---

### Refresh Token

**Endpoint:** `POST /api/auth/refresh`

**Description:** Refresh your JWT token before it expires

**Response:**
```json
{
  "status": "success",
  "data": {
    "access_token": "new_token_here",
    "token_type": "bearer",
    "expires_in": "2024-12-31 10:00:00"
  }
}
```

---

### Validate Token

**Endpoint:** `GET /api/auth/token-validation`

**Description:** Check if your current token is still valid

**Response:**
```json
{
  "status": "success",
  "message": "Token is valid"
}
```

**Error Response:**
```json
{
  "status": "failed",
  "message": "Token has expired"
}
```

---

### Delete Account

**Endpoint:** `POST /api/auth/delete-profile/{id}`

**Description:** Soft delete account (sets `is_active` to false)

**Response:**
```json
{
  "status": "success",
  "message": "User deleted successfully"
}
```

**Note:** Account is deactivated, not permanently deleted. Contact admin to reactivate.

---

## 🔐 Password Management

### Forgot Password - Request OTP

**Endpoint:** `POST /api/password/forgot`

**Description:** Request OTP code to be sent to your email

**Request:**
```json
{
  "email": "user@example.com"
}
```

**Response:**
```json
{
  "status": "success",
  "message": "OTP sent to your email",
  "data": {
    "otp_expires_at": "2024-11-30 10:10:00"
  }
}
```

**OTP Details:**
- Valid for 10 minutes
- 6-digit code
- Sent to registered email

---

### Verify OTP

**Endpoint:** `POST /api/password/otp`

**Description:** Validate the OTP code received via email

**Request:**
```json
{
  "email": "user@example.com",
  "otp": "123456"
}
```

**Response:**
```json
{
  "status": "success",
  "message": "OTP verified successfully",
  "data": {
    "reset_token": "temp_token_for_password_reset"
  }
}
```

**Error Responses:**
```json
{
  "status": "failed",
  "message": "Invalid OTP code"
}
```

```json
{
  "status": "failed",
  "message": "OTP has expired"
}
```

---

### Reset Password (After OTP)

**Endpoint:** `POST /api/password/reset`

**Description:** Set new password after OTP verification

**Request:**
```json
{
  "email": "user@example.com",
  "otp": "123456",
  "password": "newpassword123",
  "password_confirmation": "newpassword123"
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Password reset successfully"
}
```

**Validation Rules:**
- Password minimum 8 characters
- Must match password_confirmation

---

### Change Password (While Logged In)

**Endpoint:** `POST /api/password/update`

**Headers:** `Authorization: Bearer {token}`

**Description:** Change password when you know your current password

**Request:**
```json
{
  "current_password": "oldpassword123",
  "password": "newpassword123",
  "password_confirmation": "newpassword123"
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Password updated successfully"
}
```

**Error Response:**
```json
{
  "status": "failed",
  "message": "Current password is incorrect"
}
```

---

## 🔔 Notifications

### Get Notifications

**Endpoint:** `GET /api/getData/notification`

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "user_id": 10,
      "title": "Welcome to Delitopia!",
      "body": "Get 4 welcome vouchers now",
      "image": null,
      "type": "voucher",
      "is_read": false,
      "read_at": null,
      "created_at": "2024-11-30T10:00:00Z"
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
  "status": "success",
  "data": {
    "unread_count": 5
  }
}
```

---

### Mark as Read

**Endpoint:** `PUT /api/notifications/{id}/mark-read`

**Response:**
```json
{
  "status": "success",
  "message": "Notification marked as read"
}
```

---

### Mark All as Read

**Endpoint:** `POST /api/notifications/mark-all-read`

**Request:**
```json
{
  "user_id": 10
}
```

---

## 🎟️ Vouchers

### Get Available Vouchers

**Endpoint:** `GET /api/getData/voucher`

**Description:** Shows vouchers you haven't claimed yet

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 5,
      "voucher_name": "Weekend Flash Sale",
      "brand_name": "TOMOKO",
      "voucher_type": "discount",
      "description": "50% OFF all menus",
      "discount_percentage": 50,
      "min_spend": 100000,
      "point": 0,
      "cash_price": 25000,
      "start_date": "2024-12-01",
      "end_date": "2024-12-31",
      "image": "https://domain.com/images/voucher/xxx.jpg"
    }
  ]
}
```

---

### My Vouchers

**Endpoint:** `GET /api/getData/my-vouchers`

**Description:** All your claimed vouchers

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "voucher_id": 5,
      "voucher_name": "Weekend Flash Sale",
      "status": "unused",
      "purchase_type": "points",
      "created_at": "2024-11-25T10:00:00Z"
    }
  ]
}
```

---

### My Active Vouchers

**Endpoint:** `GET /api/getData/my-active-vouchers`

**Description:** Only unused, non-expired vouchers

---

### Get Vouchers Categorized

**Endpoint:** `GET /api/postData/vouchers/all-categorized`

**Response:**
```json
{
  "status": "success",
  "data": {
    "point_redemption": [...],  // Redeem with points
    "cash_purchase": [...],     // Buy with money
    "free_vouchers": [...]      // Already in your account
  }
}
```

---

### Redeem Voucher with Points

**Endpoint:** `POST /api/postData/vouchers/redeem-points`

**Request:**
```json
{
  "voucher_id": 5
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "voucher": {...},
    "remaining_points": 3500
  },
  "message": "Voucher redeemed successfully!"
}
```

**Auto-Actions:**
- ✅ Points deducted
- ✅ Voucher added to account
- ✅ Activity logged

---

### Purchase Voucher with Cash

**Endpoint:** `POST /api/postData/vouchers/purchase-cash`

**Request:**
```json
{
  "voucher_id": 5,
  "payment_method": "esmartlink",
  "channel_code": "VA_BCA"
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "voucher": {...},
    "payment": {
      "transaction_id": "TRX123456",
      "va_number": "8012345678901234",
      "amount": 25000,
      "expired_date": "2024-12-01 23:59:59"
    }
  }
}
```

---

### Redeem Birthday Voucher

**Endpoint:** `POST /api/birthday-voucher`

**Auto-Check:** Only works on your birthday (based on `birthday` field)

**Response:**
```json
{
  "status": "success",
  "message": "4 birthday vouchers redeemed!"
}
```

---

## 🛒 Orders

### Create Order

**Endpoint:** `POST /api/postData/order-new`

**Request:**
```json
{
  "user_id": 10,
  "branch_id": 1,
  "order_details": [
    {
      "menu_id": 5,
      "menu_name": "Ramen Original",
      "quantity": 2,
      "price": 45000,
      "notes": "Extra spicy"
    }
  ],
  "delivery_type": "delivery",
  "delivery_address": "Jl. Example No. 123",
  "delivery_fee": 15000,
  "voucher_id": 5,
  "payment_method": "esmartlink",
  "channel_code": "VA_BCA"
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "order": {
      "id": 100,
      "order_number": "ORD-20241130-001",
      "total_price": 90000,
      "discount": 45000,
      "final_price": 60000,
      "status": "pending"
    },
    "payment": {
      "transaction_id": "TRX789",
      "va_number": "8012345678901234",
      "amount": 60000,
      "expired_date": "2024-12-01 23:59:59"
    }
  }
}
```

**Auto-Actions:**
- ✅ Points earned (1% of total)
- ✅ Level progress updated
- ✅ Voucher marked as used
- ✅ Activity logged
- ✅ Notification sent

---

### Order History

**Endpoint:** `POST /api/getData/historyOrder`

**Request:**
```json
{
  "user_id": 10
}
```

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 100,
      "order_number": "ORD-20241130-001",
      "branch_name": "TOMOKO Senayan",
      "total_price": 60000,
      "status": "completed",
      "created_at": "2024-11-30T10:00:00Z",
      "items": [...]
    }
  ]
}
```

---

## 🎮 Gamification & Levels

### Get All Levels

**Endpoint:** `GET /api/user-levels`

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "name": "Bronze",
      "min_spent": 0,
      "max_spent": 999999,
      "icon": "🥉",
      "benefits": "1x points, 4 welcome vouchers"
    },
    {
      "id": 2,
      "name": "Silver",
      "min_spent": 1000000,
      "max_spent": 2999999,
      "icon": "🥈",
      "benefits": "1.2x points, birthday voucher"
    },
    {
      "id": 3,
      "name": "Gold",
      "min_spent": 3000000,
      "max_spent": 4999999,
      "icon": "🥇",
      "benefits": "1.5x points, exclusive vouchers"
    }
  ]
}
```

---

### My Level & Progress

**Endpoint:** `GET /api/user-levels/my-level`

**Response:**
```json
{
  "status": "success",
  "data": {
    "current_level": {
      "id": 2,
      "name": "Silver",
      "icon": "🥈"
    },
    "total_spent": 2500000,
    "progress_percentage": 83.33,
    "spent_in_current_level": 1500000,
    "amount_to_next_level": 500000,
    "next_level": {
      "id": 3,
      "name": "Gold",
      "min_spent": 3000000
    }
  }
}
```

---

## ⭐ Reviews

### Submit Review

**Endpoint:** `POST /api/reviews`

**Request:**
```json
{
  "menu_id": 5,
  "order_id": 100,
  "rating": 5,
  "comment": "Delicious ramen! Best in town!",
  "images": ["url1", "url2"]  // Optional
}
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "id": 1,
    "menu_id": 5,
    "user_id": 10,
    "rating": 5,
    "comment": "Delicious ramen!",
    "created_at": "2024-11-30T10:00:00Z"
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
    "total_reviews": 25,
    "reviews": [
      {
        "id": 1,
        "user": {
          "name": "John Doe",
          "photo": "..."
        },
        "rating": 5,
        "comment": "Delicious!",
        "created_at": "2024-11-30T10:00:00Z"
      }
    ]
  }
}
```

---

### My Reviews

**Endpoint:** `GET /api/reviews/my-reviews`

---

## ❤️ Favorites

### Add to Favorites

**Endpoint:** `POST /api/favorites/add`

**Request:**
```json
{
  "menu_id": 5
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
      "menu_id": 5,
      "menu_name": "Ramen Original",
      "price": 45000,
      "image": "...",
      "brand_name": "TOMOKO"
    }
  ]
}
```

---

### Check if Favorited

**Endpoint:** `GET /api/favorites/check/{menuId}`

**Response:**
```json
{
  "status": "success",
  "data": {
    "is_favorite": true
  }
}
```

---

## 🛒 Cart

### Add to Cart

**Endpoint:** `POST /api/cart/add`

**Request:**
```json
{
  "menu_id": 5,
  "quantity": 2,
  "notes": "Extra spicy"
}
```

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
        "menu_id": 5,
        "menu_name": "Ramen Original",
        "quantity": 2,
        "price": 45000,
        "subtotal": 90000,
        "notes": "Extra spicy"
      }
    ],
    "total": 90000
  }
}
```

---

### Update Cart Item

**Endpoint:** `PUT /api/cart/item/{itemId}`

**Request:**
```json
{
  "quantity": 3
}
```

---

### Remove Item

**Endpoint:** `DELETE /api/cart/item/{itemId}`

---

### Clear Cart

**Endpoint:** `DELETE /api/cart/clear`

---

## 🔍 Search

### Search Menus

**Endpoint:** `POST /api/search`

**Request:**
```json
{
  "keyword": "ramen"
}
```

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 5,
      "name": "Ramen Original",
      "price": 45000,
      "brand_name": "TOMOKO",
      "image": "..."
    }
  ]
}
```

---

### Filter Menus

**Endpoint:** `POST /api/search/filter`

**Request:**
```json
{
  "brand_id": 1,
  "min_price": 40000,
  "max_price": 100000,
  "category": "main_course"
}
```

---

### Autocomplete

**Endpoint:** `GET /api/search/autocomplete?q=ram`

**Response:**
```json
{
  "status": "success",
  "data": ["Ramen Original", "Ramen Spicy", "Ramen Cheese"]
}
```

---

### Trending Searches

**Endpoint:** `GET /api/search/trending`

---

## 📍 Addresses

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
      "latitude": -6.2088,
      "longitude": 106.8456,
      "is_default": true
    }
  ]
}
```

---

### Add Address

**Endpoint:** `POST /api/addresses`

**Request:**
```json
{
  "label": "Office",
  "address": "Jl. Work St. No. 456",
  "latitude": -6.2088,
  "longitude": 106.8456,
  "notes": "Near Starbucks"
}
```

---

### Set Default

**Endpoint:** `POST /api/addresses/{id}/set-default`

---

### Find Nearest Branches

**Endpoint:** `POST /api/addresses/nearest-branches`

**Request:**
```json
{
  "latitude": -6.2088,
  "longitude": 106.8456
}
```

---

## 📊 Analytics

### Order Statistics

**Endpoint:** `GET /api/analytics/order-stats`

**Response:**
```json
{
  "status": "success",
  "data": {
    "total_orders": 15,
    "total_spent": 2500000,
    "average_order_value": 166666,
    "last_order_date": "2024-11-30"
  }
}
```

---

### Spending Summary

**Endpoint:** `GET /api/analytics/spending-summary`

**Response:**
```json
{
  "status": "success",
  "data": {
    "this_month": 500000,
    "last_month": 350000,
    "this_year": 2500000,
    "by_brand": [...]
  }
}
```

---

### Favorite Menus

**Endpoint:** `GET /api/analytics/favorite-menus`

---

### Get Recommendations

**Endpoint:** `GET /api/analytics/recommendations`

**Description:** AI-powered menu recommendations based on order history

---

## 🆘 Support

### Create Ticket

**Endpoint:** `POST /api/support/ticket`

**Request:**
```json
{
  "subject": "Order not delivered",
  "message": "My order #ORD-123 hasn't arrived",
  "category": "delivery"
}
```

---

### My Tickets

**Endpoint:** `GET /api/support/tickets`

---

### Send Message

**Endpoint:** `POST /api/support/ticket/{ticketId}/message`

---

## 💳 Payment

### E-Smartlink Payment

**Endpoint:** `POST /api/esmartlink/create-payment`

**Request:**
```json
{
  "order_id": 100,
  "amount": 60000,
  "channel_code": "VA_BCA"
}
```

**Available Channels:**
- `VA_BCA` - BCA Virtual Account
- `VA_BNI` - BNI Virtual Account
- `VA_BRI` - BRI Virtual Account
- `VA_MANDIRI` - Mandiri Virtual Account
- `QRIS` - QRIS Payment

**Response:**
```json
{
  "status": "success",
  "data": {
    "transaction_id": "TRX123456",
    "va_number": "8012345678901234",
    "qr_string": "...",  // For QRIS
    "amount": 60000,
    "expired_date": "2024-12-01 23:59:59"
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
    "transaction_id": "TRX123456",
    "status": "paid",
    "paid_at": "2024-11-30 10:30:00"
  }
}
```

---

## 🔄 Activity Tracking

All user actions are automatically logged:

- ✅ Login (email/Google)
- ✅ Registration
- ✅ Profile updates
- ✅ Orders placed
- ✅ Voucher redemptions
- ✅ Voucher usage
- ✅ Reviews submitted
- ✅ Level upgrades

**View My Activities:**

**Endpoint:** `GET /api/activities/my-activities`

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "type": "order_placed",
      "description": "Placed order ORD-123",
      "metadata": {...},
      "created_at": "2024-11-30T10:00:00Z"
    }
  ]
}
```

---

## 📱 Integration Examples

### Flutter/Dart

```dart
// Login
final response = await http.post(
  Uri.parse('https://domain.com/api/auth/login'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'email': 'user@example.com',
    'password': 'password123'
  }),
);

final data = jsonDecode(response.body);
final token = data['data']['access_token'];

// Save token
await storage.write(key: 'token', value: token);

// Get profile
final profile = await http.get(
  Uri.parse('https://domain.com/api/auth/me'),
  headers: {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json'
  },
);
```

---

### React Native

```javascript
// Login
const login = async (email, password) => {
  const response = await fetch('https://domain.com/api/auth/login', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ email, password }),
  });
  
  const data = await response.json();
  
  if (data.status === 'success') {
    await AsyncStorage.setItem('token', data.data.access_token);
    return data.data;
  }
};

// Get notifications
const getNotifications = async () => {
  const token = await AsyncStorage.getItem('token');
  
  const response = await fetch('https://domain.com/api/getData/notification', {
    headers: {
      'Authorization': `Bearer ${token}`,
    },
  });
  
  return await response.json();
};
```

---

## 🎯 Quick Reference

### Key Changes from Old App

| Feature | Old Behavior | New Behavior |
|---------|-------------|--------------|
| Login | Manual tracking | ✅ Auto-updates `last_login_at` & `is_active` |
| Registration | No welcome gifts | ✅ 4 welcome vouchers auto-distributed |
| Vouchers | Basic list | ✅ Categorized (points/cash/free) |
| Orders | No activity log | ✅ Full activity tracking |
| Notifications | Basic push | ✅ Read/unread tracking, badge count |
| User Level | Static | ✅ Auto-progression, benefits tracking |
| Reviews | Not available | ✅ Full review system |
| Favorites | Not available | ✅ Favorite menus tracking |
| Cart | Not available | ✅ Persistent shopping cart |

---

## ⚙️ Account Settings

### Get User Preferences

**Endpoint:** `GET /api/auth/me`

**Description:** Returns user profile including settings

**Settings Fields:**
- `fcm_token` - Push notification token
- `is_active` - Account status
- `last_login_at` - Last login timestamp

---

### Email Preferences

**Endpoint:** `POST /api/auth/edit-profile/{id}`

**Request:**
```json
{
  "email": "newemail@example.com"
}
```

**Note:** 
- Email must be unique
- Verification may be required (check with admin)

---

### Phone Number Update

**Endpoint:** `POST /api/auth/edit-profile/{id}`

**Request:**
```json
{
  "phone_number": "081234567890"
}
```

**Validation:**
- Must be valid phone number
- Max 15 digits

---

### Birthday Update

**Endpoint:** `POST /api/auth/edit-profile/{id}`

**Request:**
```json
{
  "birthday": "1995-05-15"
}
```

**Note:** Birthday affects birthday voucher eligibility

---

### Profile Photo Upload

**Endpoint:** `POST /api/auth/edit-profile/{id}`

**Content-Type:** `multipart/form-data`

**Request:**
```javascript
FormData {
  photo: File  // JPEG, PNG, JPG, GIF
}
```

**Validation:**
- Max file size: 2MB
- Allowed types: jpeg, png, jpg, gif

**Response:**
```json
{
  "status": "success",
  "message": "User updated successfully",
  "photo_url": "https://domain.com/images/profile_photos/123456_photo.jpg"
}
```

---

### Notification Settings

**Enable/Disable Push Notifications:**

```javascript
// To disable notifications, don't send FCM token
// To enable, update FCM token:

POST /api/auth/fcm_token/{id}
{
  "fcm_token": "your_firebase_token"
}

// To disable completely, send empty string:
{
  "fcm_token": ""
}
```

---

### Privacy & Data

**View My Activity:**
```
GET /api/activities/my-activities
```

**View My Orders:**
```
POST /api/getData/historyOrder
{
  "user_id": 10
}
```

**View My Vouchers:**
```
GET /api/getData/my-vouchers
```

**Delete Account:**
```
POST /api/auth/delete-profile/{id}
```

---

### App Settings (Client-Side)

These settings are typically stored locally in your app:

**Language Preference:**
- Store in AsyncStorage/SharedPreferences
- Default: Bahasa Indonesia

**Theme (Dark/Light Mode):**
- Store locally
- Toggle in app settings

**Notification Sounds:**
- Device settings

**Location Services:**
- Required for delivery address
- Used for nearest branch finder

---

## 🔐 Password Requirements

### Security Rules

**Password Must:**
- ✅ Minimum 8 characters
- ✅ Contain letters
- ✅ Match confirmation field

**Best Practices:**
- Use mix of uppercase, lowercase, numbers
- Don't reuse passwords from other apps
- Change password every 3-6 months
- Never share password

---

## 🔔 OTP System

### How OTP Works

1. **Request OTP** → `POST /api/password/forgot`
   - System generates 6-digit code
   - Sent to registered email
   - Valid for 10 minutes

2. **Verify OTP** → `POST /api/password/otp`
   - Enter code from email
   - System validates
   - Returns reset token

3. **Reset Password** → `POST /api/password/reset`
   - Use OTP code
   - Set new password
   - Account updated

**OTP Format:**
- 6 digits
- Example: `123456`
- Case-sensitive: NO
- Expires: 10 minutes after request

**Rate Limiting:**
- Max 3 OTP requests per 10 minutes
- Max 5 verification attempts
- Lockout after failed attempts

---

## 📧 Email Notifications

### When You'll Receive Emails

**Account Related:**
- ✅ Registration confirmation
- ✅ Password reset OTP
- ✅ Email change verification
- ✅ Account deactivation notice

**Order Related:**
- ✅ Order confirmation
- ✅ Payment received
- ✅ Order status updates
- ✅ Delivery notifications

**Marketing (Optional):**
- New voucher alerts
- Special promotions
- Birthday voucher reminder
- Level upgrade notification

**Unsubscribe:**
- Contact support to opt-out of marketing emails
- Account emails cannot be disabled

---

## 🔒 Security Notes

### Authentication Security

- ✅ All endpoints (except login/register/password-reset) require JWT token
- ✅ Tokens expire after configured time (check `expires_in`)
- ✅ Use `POST /api/auth/refresh` to refresh token before expiry
- ✅ Never store passwords in app (use secure token storage)
- ✅ Always use HTTPS in production
- ✅ Implement SSL pinning for extra security

### Token Management

**Best Practices:**

```javascript
// Store token securely
import AsyncStorage from '@react-native-async-storage/async-storage';

// Save token
await AsyncStorage.setItem('auth_token', token);

// Retrieve token
const token = await AsyncStorage.getItem('auth_token');

// Clear token on logout
await AsyncStorage.removeItem('auth_token');
```

**Flutter Secure Storage:**

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();

// Save token
await storage.write(key: 'auth_token', value: token);

// Read token
String? token = await storage.read(key: 'auth_token');

// Delete token
await storage.delete(key: 'auth_token');
```

### Password Security

- ✅ Minimum 8 characters enforced
- ✅ Passwords hashed with bcrypt
- ✅ Never sent in plain text
- ✅ OTP system for password recovery
- ✅ Current password required for changes

### Account Protection

**Two-Factor Authentication (via OTP):**
- Used for password reset
- 10-minute validity
- Rate-limited requests
- Email delivery only

**Account Lockout:**
- Too many failed logins → temporary ban
- Too many OTP attempts → cooldown period
- Contact support to unlock

**Data Privacy:**
- User data encrypted at rest
- SSL/TLS for data in transit
- No passwords stored in logs
- GDPR/privacy compliant

---

## 🆘 Troubleshooting

### Common Issues

**"Token has expired"**
```javascript
// Solution: Refresh token
POST /api/auth/refresh
```

**"Unauthenticated"**
```javascript
// Solution: Check token in headers
headers: {
  'Authorization': 'Bearer ' + token
}
```

**"OTP has expired"**
```javascript
// Solution: Request new OTP
POST /api/password/forgot
{
  "email": "user@example.com"
}
```

**"Invalid OTP code"**
- Check email for correct code
- OTP is case-sensitive for security
- Don't include spaces
- Request new OTP if needed

**"Email already exists"**
- Email is already registered
- Try logging in instead
- Use forgot password if needed

**"Current password is incorrect"**
- Check CAPS LOCK
- Verify password spelling
- Use forgot password to reset

---

## 📱 Complete App Flow Examples

### User Registration Flow

```javascript
// Step 1: Register
POST /api/auth/register
{
  "name": "John Doe",
  "birthday": "1995-05-15",
  "gender": "M",
  "email": "john@example.com",
  "password": "password123",
  "phone_number": "081234567890"
}

// Auto-receives:
// - 4 welcome vouchers
// - Bronze level
// - Activity logged

// Step 2: Login
POST /api/auth/login
{
  "email": "john@example.com",
  "password": "password123"
}

// Response: JWT token

// Step 3: Update FCM token for notifications
POST /api/auth/fcm_token/{userId}
{
  "fcm_token": "firebase_token"
}

// Step 4: Get profile
GET /api/auth/me
```

---

### Forgot Password Flow

```javascript
// Step 1: Request OTP
POST /api/password/forgot
{
  "email": "user@example.com"
}

// Response: OTP sent to email

// Step 2: User receives email with OTP
// Example email:
// "Your OTP code is: 123456"
// "Valid for 10 minutes"

// Step 3: Verify OTP
POST /api/password/otp
{
  "email": "user@example.com",
  "otp": "123456"
}

// Response: reset_token

// Step 4: Reset password
POST /api/password/reset
{
  "email": "user@example.com",
  "otp": "123456",
  "password": "newpassword123",
  "password_confirmation": "newpassword123"
}

// Response: Success

// Step 5: Login with new password
POST /api/auth/login
{
  "email": "user@example.com",
  "password": "newpassword123"
}
```

---

### Change Password Flow (While Logged In)

```javascript
// Step 1: User wants to change password in settings
// Navigate to Settings > Change Password

// Step 2: Submit password change
POST /api/password/update
Headers: {
  Authorization: Bearer {token}
}
Body: {
  "current_password": "oldpassword123",
  "password": "newpassword123",
  "password_confirmation": "newpassword123"
}

// Response: Success

// Step 3: (Optional) Force logout and re-login
POST /api/auth/logout

// Step 4: Login with new password
POST /api/auth/login
{
  "email": "user@example.com",
  "password": "newpassword123"
}
```

---

### Profile Update Flow

```javascript
// Step 1: Get current profile
GET /api/auth/me
Headers: {
  Authorization: Bearer {token}
}

// Step 2: Update profile (with photo)
POST /api/auth/edit-profile/{userId}
Content-Type: multipart/form-data
Headers: {
  Authorization: Bearer {token}
}
Body: FormData {
  name: "John Doe Updated",
  gender: "M",
  email: "newemail@example.com",
  phone_number: "081234567890",
  photo: File
}

// Response: Updated profile with new photo URL

// Step 3: Refresh profile in app
GET /api/auth/me
```

---

### Settings Screen Implementation

**React Native Example:**

```javascript
import React, { useState } from 'react';
import { View, Text, Switch, TouchableOpacity } from 'react-native';

const SettingsScreen = () => {
  const [pushNotifications, setPushNotifications] = useState(true);
  
  const handleChangePassword = () => {
    navigation.navigate('ChangePassword');
  };
  
  const handleEditProfile = () => {
    navigation.navigate('EditProfile');
  };
  
  const handleLogout = async () => {
    await fetch('https://domain.com/api/auth/logout', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });
    
    await AsyncStorage.removeItem('auth_token');
    navigation.navigate('Login');
  };
  
  return (
    <View>
      <Text style={styles.section}>Account</Text>
      
      <TouchableOpacity onPress={handleEditProfile}>
        <Text>Edit Profile</Text>
      </TouchableOpacity>
      
      <TouchableOpacity onPress={handleChangePassword}>
        <Text>Change Password</Text>
      </TouchableOpacity>
      
      <Text style={styles.section}>Notifications</Text>
      
      <View style={styles.row}>
        <Text>Push Notifications</Text>
        <Switch 
          value={pushNotifications}
          onValueChange={setPushNotifications}
        />
      </View>
      
      <Text style={styles.section}>Privacy</Text>
      
      <TouchableOpacity onPress={() => navigation.navigate('MyActivities')}>
        <Text>My Activity Log</Text>
      </TouchableOpacity>
      
      <TouchableOpacity onPress={() => navigation.navigate('OrderHistory')}>
        <Text>Order History</Text>
      </TouchableOpacity>
      
      <Text style={styles.section}>Account Actions</Text>
      
      <TouchableOpacity onPress={handleLogout}>
        <Text style={styles.logout}>Logout</Text>
      </TouchableOpacity>
      
      <TouchableOpacity onPress={() => navigation.navigate('DeleteAccount')}>
        <Text style={styles.danger}>Delete Account</Text>
      </TouchableOpacity>
    </View>
  );
};
```

---

## 📞 Support & Help

### Contact Support

**For Issues:**
- Email: support@delitopia.com
- In-app: `POST /api/support/ticket`
- Phone: +62-xxx-xxxx-xxxx

### FAQs

**Q: How do I reset my password?**
A: Use Forgot Password → Enter email → Check OTP → Set new password

**Q: Can I change my registered email?**
A: Yes, via Edit Profile. Verification may be required.

**Q: How long are vouchers valid?**
A: Check each voucher's `end_date` field.

**Q: Why can't I login?**
A: Check email/password spelling, ensure account is active, try password reset.

**Q: How do I delete my account?**
A: Settings → Delete Account (soft delete, contact admin to reactivate)

---

**Support:** Check `storage/logs/laravel.log` for errors  
**Version:** 2.0.0  
**Last Updated:** 30 November 2024
