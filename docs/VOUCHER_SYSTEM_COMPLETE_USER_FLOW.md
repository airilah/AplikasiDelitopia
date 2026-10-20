# Voucher System - Complete User Flow Documentation

## 📋 Table of Contents
1. [Voucher Acquisition Methods](#voucher-acquisition-methods)
2. [Voucher Lifecycle States](#voucher-lifecycle-states)
3. [Complete User Flow](#complete-user-flow)
4. [API Endpoints Reference](#api-endpoints-reference)
5. [Voucher Types Explained](#voucher-types-explained)
6. [Usage Scenarios](#usage-scenarios)

---

## 🎯 Voucher Acquisition Methods

Users can acquire vouchers through 4 different methods:

### 1. **Point Redemption** (Free/Paid with Points)
- User exchanges points for vouchers
- Can be free (0 points) or cost points
- Status starts as: `inactive`

### 2. **Cash Purchase** (Paid with Money)
- User pays with real money (QRIS/Cash)
- Status starts as: `pending_payment` → `inactive` after payment confirmed

### 3. **Auto-Granted** (System Automatic)
- Birthday vouchers (automatic on user's birthday)
- Welcome vouchers (automatic on registration)
- Status: directly `active` or `inactive`

### 4. **Admin Granted** (Manual)
- Admin manually gives voucher to user
- Status: `inactive` or `active` (admin decides)

---

## 🔄 Voucher Lifecycle States

```
┌─────────────────────────────────────────────────────────────┐
│  VOUCHER LIFECYCLE - State Transitions                      │
└─────────────────────────────────────────────────────────────┘

[Purchase/Claim] 
       ↓
   INACTIVE ──────→ ACTIVE ──────→ USED
       │                │              │
       │                │              ↓
       └────────→ EXPIRED ←────────────┘

```

### State Details:

| State | Description | Can Activate? | Can Use? |
|-------|-------------|---------------|----------|
| **inactive** | Voucher purchased but not activated yet | ✅ Yes | ❌ No |
| **active** | Voucher activated and ready to use | ❌ Already active | ✅ Yes |
| **used** | Voucher has been used in an order | ❌ No | ❌ No |
| **expired** | Voucher expired (past expiry_date) | ❌ No | ❌ No |
| **pending_payment** | Cash purchase waiting for payment | ❌ No | ❌ No |

---

## 📱 Complete User Flow

### **Flow 1: Point Redemption Voucher**

```
1. VIEW AVAILABLE VOUCHERS
   ↓
   GET /api/getData/vouchers/point-redemption
   
   Response:
   {
     "user_points": 150,
     "vouchers": [
       {
         "id": 1,
         "voucher_name": "50% Discount",
         "point": 50,
         "can_redeem": true
       }
     ]
   }

2. REDEEM VOUCHER WITH POINTS
   ↓
   POST /api/postData/vouchers/redeem-points
   Body: { "voucher_id": 1 }
   
   ✅ System creates DetailVoucher with status: "inactive"
   ✅ Deducts points from user (if point > 0)
   ✅ Creates Point transaction record
   
3. VIEW MY VOUCHERS
   ↓
   GET /api/getData/my-vouchers?status=inactive
   
   Response:
   {
     "data": [
       {
         "id": 101,
         "voucher_name": "50% Discount",
         "status": "inactive",
         "can_activate": true,
         "purchased_at": "2025-12-01 10:00:00"
       }
     ]
   }

4. ACTIVATE VOUCHER (Make it ready to use)
   ↓
   POST /api/postData/voucher-activate
   Body: { "detail_voucher_id": 101 }
   
   ✅ Status changes: "inactive" → "active"
   ✅ Expiry date calculated based on voucher type
   
5. VIEW ACTIVE VOUCHERS
   ↓
   GET /api/getData/my-active-vouchers
   
   Response:
   {
     "data": [
       {
         "id": 101,
         "voucher_name": "50% Discount",
         "status": "active",
         "can_use": true,
         "expiry_date": "2025-12-31 23:59:59"
       }
     ]
   }

6a. USE IN ORDER (Mobile App)
    ↓
    POST /api/postData/order
    Body: {
      ...order details...,
      "user_voucher_id": 101
    }
    
    ✅ Order created with voucher applied
    ✅ Discount calculated automatically
    ✅ Voucher status: "active" → "used"

6b. CLAIM AT POS (Physical Store)
    ↓
    User shows voucher QR code at cashier
    Cashier scans QR → finds detail_voucher_id: 101
    
    POST /api/postData/use-voucher
    Body: {
      "user_id": 1,
      "voucher_id": 1
    }
    
    ✅ Voucher status: "active" → "used"
    ✅ Order can be processed at POS

7. VIEW ORDER HISTORY
   ↓
   GET /api/getData/order?type=status&status=success
   
   Response shows orders with voucher details:
   {
     "orders": [
       {
         "order_id": "ORD-01-01-00001",
         "grand_total": 100000,
         "final_total": 50000,
         "discount": 50000,
         "voucher_name": "50% Discount",
         "status": "completed"
       }
     ]
   }
```

---

### **Flow 2: Cash Purchase Voucher**

```
1. VIEW CASH PURCHASE VOUCHERS
   ↓
   GET /api/getData/vouchers/cash-purchase
   
   Response:
   {
     "data": [
       {
         "id": 5,
         "voucher_name": "100K Discount Voucher",
         "price": 50000,
         "description": "Buy for 50K, get 100K discount"
       }
     ]
   }

2. PURCHASE WITH CASH/QRIS
   ↓
   POST /api/postData/vouchers/purchase-cash
   Body: {
     "voucher_id": 5,
     "payment_method": "QRIS"
   }
   
   ✅ Creates DetailVoucher with status: "pending_payment"
   ✅ Generates payment QR code
   
   Response:
   {
     "payment_qr": "...",
     "amount": 50000,
     "detail_voucher_id": 102
   }

3. PAYMENT CONFIRMED (via callback)
   ↓
   Payment gateway sends callback
   ✅ Status: "pending_payment" → "inactive"
   
4. ACTIVATE & USE (Same as Point Redemption Flow steps 4-7)
```

---

### **Flow 3: Auto-Granted Birthday Voucher**

```
1. SYSTEM AUTO-GRANTS (Cron Job Daily)
   ↓
   Cron runs: php artisan schedule:run
   ✅ Checks users with birthday today
   ✅ Creates DetailVoucher automatically
   ✅ Status: "inactive" (user must activate)

2. USER RECEIVES NOTIFICATION
   ↓
   "Happy Birthday! You've received a special voucher!"

3. USER VIEWS MY VOUCHERS
   ↓
   GET /api/getData/my-vouchers?status=inactive
   
   Response:
   {
     "data": [
       {
         "voucher_name": "Birthday Special 50% Off",
         "status": "inactive",
         "is_birthday": true
       }
     ]
   }

4. ACTIVATE & USE (Same flow as Point Redemption)
```

---

## 🔌 API Endpoints Reference

### **User Endpoints**

#### 1. **Browse Available Vouchers**

**Point Redemption Vouchers:**
```http
GET /api/getData/vouchers/point-redemption
Authorization: Bearer {token}
Query: ?brand_id=1 (optional)

Response:
{
  "status": "success",
  "data": {
    "user_points": 150,
    "vouchers": [
      {
        "id": 1,
        "voucher_name": "50% Discount",
        "brand_name": "Delitopia",
        "point": 50,
        "can_redeem": true,
        "discount_percentage": 50,
        "min_spend": 100000,
        "start_date": "2025-12-01",
        "end_date": "2025-12-31",
        "image": "https://..."
      }
    ]
  }
}
```

**Cash Purchase Vouchers:**
```http
GET /api/getData/vouchers/cash-purchase
Authorization: Bearer {token}
Query: ?brand_id=1 (optional)

Response:
{
  "status": "success",
  "data": [
    {
      "id": 5,
      "voucher_name": "100K Discount Voucher",
      "price": 50000,
      "description": "Pay 50K, get 100K discount",
      "is_purchasable": true
    }
  ]
}
```

**All Vouchers (Categorized):**
```http
GET /api/getData/vouchers/all-categorized
Authorization: Bearer {token}

Response:
{
  "status": "success",
  "data": {
    "point_redemption": [...],
    "cash_purchase": [...],
    "free_vouchers": [...]
  }
}
```

---

#### 2. **Claim/Purchase Vouchers**

**Redeem with Points:**
```http
POST /api/postData/vouchers/redeem-points
Authorization: Bearer {token}
Content-Type: application/json

{
  "voucher_id": 1
}

Response:
{
  "status": "success",
  "data": {
    "detail_voucher": {
      "id": 101,
      "voucher_id": 1,
      "user_id": 1,
      "status": "inactive",
      "purchased_at": "2025-12-01 10:00:00",
      "expiry_date": null,
      "voucher": {
        "voucher_name": "50% Discount",
        "brand": {
          "name": "Delitopia"
        }
      }
    },
    "points_remaining": 100,
    "is_free_voucher": false
  },
  "message": "Voucher redeemed successfully with 50 points"
}
```

**Purchase with Cash:**
```http
POST /api/postData/vouchers/purchase-cash
Authorization: Bearer {token}
Content-Type: application/json

{
  "voucher_id": 5,
  "payment_method": "QRIS"
}

Response:
{
  "status": "success",
  "data": {
    "detail_voucher": {...},
    "payment_qr": "...",
    "amount": 50000
  },
  "message": "Voucher purchase initiated. Please complete payment."
}
```

---

#### 3. **View My Vouchers**

**All My Vouchers:**
```http
GET /api/getData/my-vouchers
Authorization: Bearer {token}
Query: ?status=inactive|active|used|expired (optional)

Response:
{
  "status": "success",
  "data": [
    {
      "id": 101,
      "voucher": {
        "voucher_name": "50% Discount",
        "discount_percentage": 50,
        "min_spend": 100000,
        "image": "https://..."
      },
      "status": "inactive",
      "purchased_at": "2025-12-01 10:00:00",
      "expiry_date": null,
      "can_activate": true,
      "can_use": false
    },
    {
      "id": 102,
      "voucher": {
        "voucher_name": "Free Coffee",
        "voucher_type": "free_item"
      },
      "status": "active",
      "expiry_date": "2025-12-31 23:59:59",
      "can_activate": false,
      "can_use": true
    }
  ]
}
```

**Active Vouchers Only:**
```http
GET /api/getData/my-active-vouchers
Authorization: Bearer {token}

Response:
{
  "status": "success",
  "data": [
    // Only vouchers with status="active" and not expired
  ]
}
```

---

#### 4. **Activate Voucher**

```http
POST /api/postData/voucher-activate
Authorization: Bearer {token}
Content-Type: application/json

{
  "detail_voucher_id": 101
}

Response:
{
  "status": "success",
  "data": {
    "id": 101,
    "status": "active",
    "activation_date": "2025-12-01 11:00:00",
    "expiry_date": "2025-12-31 23:59:59"
  },
  "message": "Voucher activated successfully"
}
```

---

#### 5. **Validate Voucher Before Use**

```http
POST /api/getData/vouchers/validate-usage
Authorization: Bearer {token}
Content-Type: application/json

{
  "detail_voucher_id": 101
}

Response:
{
  "status": "success",
  "data": {
    "can_use": true,
    "reason": "Voucher is ready to use",
    "usage_count": 0,
    "max_usage_per_user": 5,
    "max_usage_per_day": 1,
    "last_used_at": null,
    "next_available_at": null
  }
}

// If cannot use:
{
  "status": "success",
  "data": {
    "can_use": false,
    "reason": "Daily usage limit reached. Next available at 2025-12-02 00:00:00",
    "next_available_at": "2025-12-02 00:00:00"
  }
}
```

---

#### 6. **Use Voucher in Order**

**Method A: Mobile App (Place Order with Voucher)**
```http
POST /api/postData/order
Authorization: Bearer {token}
Content-Type: application/json

{
  "date": "2025-12-01",
  "grand_total": 100000,
  "final_total": 50000,
  "discount": 50000,
  "tax": 5000,
  "service": 5000,
  "order_type": "dine in",
  "payment": "QRIS",
  "user_id": 1,
  "branch_id": 1,
  "table_number": "A1",
  "user_voucher_id": 101,  ← IMPORTANT: Pass detail_voucher_id
  "details": [
    {
      "menu_id": 1,
      "qty": 2,
      "total": 100000
    }
  ]
}

Response:
{
  "status": "success",
  "data": {
    "order_id": "ORD-01-01-00001",
    "final_total": 50000
  }
}

✅ System automatically:
   - Applies voucher discount
   - Marks voucher as "used"
   - If birthday voucher: marks ALL birthday vouchers as used
```

**Method B: POS/Cashier (Claim at Store)**
```http
POST /api/postData/use-voucher
Authorization: Bearer {token}
Content-Type: application/json

{
  "user_id": 1,
  "voucher_id": 1
}

Response:
{
  "status": "success",
  "message": "Voucher redeemed successfully"
}

✅ Marks voucher as "used"
✅ Cashier can then manually apply discount at POS
```

---

#### 7. **View Voucher Usage History**

```http
GET /api/getData/vouchers/usage-history
Authorization: Bearer {token}
Query: ?detail_voucher_id=101

Response:
{
  "status": "success",
  "data": {
    "detail_voucher_id": 101,
    "voucher_name": "50% Discount",
    "status": "active",
    "usage_count": 2,
    "last_used_at": "2025-12-01 10:00:00",
    "can_use_now": false,
    "next_available_at": "2025-12-02 00:00:00",
    "usage_limits": {
      "type": "both",
      "max_per_user": 5,
      "max_per_day": 1,
      "cooldown_hours": 24
    }
  }
}
```

---

#### 8. **View Order History with Vouchers**

```http
GET /api/getData/order
Authorization: Bearer {token}
Query: ?user_id=1&type=status&status=success

Response:
{
  "status": "success",
  "data": [
    {
      "date": "2025-12-01",
      "orders": [
        {
          "order_id": "ORD-01-01-00001",
          "grand_total": 100000,
          "final_total": 50000,
          "discount": 50000,
          "voucher_name": "50% Discount",  ← Voucher used
          "voucher_type": "discount_percentage",
          "status": "completed",
          "created_at": "2025-12-01 10:00:00"
        }
      ]
    }
  ]
}
```

---

## 🎫 Voucher Types Explained

### 1. **Discount Percentage**
```json
{
  "voucher_type": "discount_percentage",
  "discount_percentage": 50,
  "min_spend": 100000
}
```
- Gives X% discount on total order
- Only applies if order total ≥ min_spend
- Example: 50% off for orders above 100K

### 2. **Discount Amount**
```json
{
  "voucher_type": "discount_amount",
  "discount_amount": 50000,
  "min_spend": 200000
}
```
- Gives fixed amount discount
- Example: 50K off for orders above 200K

### 3. **Buy 1 Get 1 (B1G1)**
```json
{
  "voucher_type": "buy_1_get_1",
  "buy_1_get_1_buy_id": 10,
  "buy_1_get_1_free_id": 11
}
```
- Buy specific item, get another item free
- Example: Buy Coffee, get Donut free

### 4. **Free Item**
```json
{
  "voucher_type": "free_item",
  "free_menu_item_id": 15
}
```
- Get a specific menu item for free
- Example: Free Birthday Cake

### 5. **Birthday Voucher**
```json
{
  "voucher_type": "birthday",
  "discount_percentage": 50
}
```
- Special voucher granted on user's birthday
- Auto-distributed by system
- All birthday vouchers marked "used" together when one is used

---

## 📊 Usage Scenarios

### Scenario 1: User Redeems Free Voucher (0 Points)

```
User has: 100 points
Voucher: "Welcome Gift" - 0 points

1. POST /api/postData/vouchers/redeem-points
   { "voucher_id": 1 }
   
   ✅ No points deducted (voucher.point = 0)
   ✅ DetailVoucher created (status: inactive)
   ✅ User still has 100 points

2. POST /api/postData/voucher-activate
   { "detail_voucher_id": 101 }
   
   ✅ Status: inactive → active
   ✅ Ready to use!
```

---

### Scenario 2: User Purchases Voucher with Cash

```
Voucher: "100K Discount" - Price: 50,000 IDR

1. POST /api/postData/vouchers/purchase-cash
   { "voucher_id": 5, "payment_method": "QRIS" }
   
   ✅ DetailVoucher created (status: pending_payment)
   ✅ QR code generated
   ✅ Amount: 50,000 IDR

2. User scans QR → pays via QRIS

3. Payment gateway callback received
   ✅ Status: pending_payment → inactive
   ✅ User can now activate it

4. POST /api/postData/voucher-activate
   ✅ Status: inactive → active
   ✅ Ready to use!
```

---

### Scenario 3: Birthday Voucher with Daily Limit

```
Voucher Settings:
- voucher_type: "birthday"
- usage_limit_type: "once_per_day"
- max_usage_per_day: 1

User Flow:
1. System auto-grants voucher on birthday
2. User activates voucher
3. User uses voucher on December 1st → status: "used"
4. ❌ All birthday vouchers for this user marked "used"
5. User cannot use birthday voucher again (single-use type)
```

---

### Scenario 4: Reusable Voucher with Cooldown

```
Voucher Settings:
- usage_limit_type: "both"
- max_usage_per_user: 5
- max_usage_per_day: 1
- cooldown_hours: 24

User Flow:
1. User activates voucher
2. Uses on Dec 1, 10:00 AM ✅
3. Tries to use Dec 1, 2:00 PM ❌ (daily limit reached)
4. Tries to use Dec 2, 9:00 AM ❌ (cooldown: must wait until Dec 2, 10:00 AM)
5. Uses on Dec 2, 11:00 AM ✅
6. Can use 3 more times (total limit: 5)
```

---

## 🔍 Voucher Status Quick Reference

| Status | Description | Next Action | Can Activate? | Can Use? |
|--------|-------------|-------------|---------------|----------|
| **pending_payment** | Waiting for payment | Complete payment | ❌ | ❌ |
| **inactive** | Purchased, not activated yet | Activate it | ✅ | ❌ |
| **active** | Ready to use | Use in order or at POS | ❌ | ✅ |
| **used** | Already used | View order history | ❌ | ❌ |
| **expired** | Past expiry date | N/A | ❌ | ❌ |

---

## 🎯 Summary

### **Complete Journey:**

```
1. DISCOVER
   └─ Browse point/cash vouchers

2. ACQUIRE
   ├─ Redeem with points
   ├─ Purchase with cash
   ├─ Auto-granted (birthday)
   └─ Admin granted

3. CLAIM (status: inactive)
   └─ Voucher in "My Vouchers"

4. ACTIVATE (status: inactive → active)
   └─ Calculate expiry date
   └─ Ready to use

5. USE
   ├─ In mobile app order
   └─ Claim at POS/Cashier

6. COMPLETE (status: active → used)
   └─ Discount applied
   └─ Order completed

7. HISTORY
   └─ View in order history
```

---

**✅ Voucher System Complete!**

Users can now:
- 🎁 Redeem vouchers with points (free or paid)
- 💰 Purchase vouchers with cash
- 🎂 Receive automatic birthday vouchers
- 📱 Activate vouchers when ready
- 🛒 Use in mobile app orders
- 🏪 Claim at physical store POS
- 📊 Track usage history
