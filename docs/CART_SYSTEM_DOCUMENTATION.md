# 🛒 Cart System - Complete Documentation

## 📋 Table of Contents
1. [Overview](#overview)
2. [Database Schema](#database-schema)
3. [API Endpoints](#api-endpoints)
4. [Usage Examples](#usage-examples)
5. [Business Logic](#business-logic)
6. [Integration Guide](#integration-guide)

---

## 🎯 Overview

The Cart System allows users to add menu items to their cart, manage quantities, add customizations, and prepare for checkout. It's a persistent shopping cart that saves items until the user is ready to place an order.

### Key Features
- ✅ **Persistent Cart**: Cart items saved until checkout
- ✅ **Quantity Management**: Add, update, remove items
- ✅ **Menu Customizations**: Support for item modifications
- ✅ **Notes**: Add special instructions per item
- ✅ **Branch Association**: Cart tied to specific branch
- ✅ **Real-time Totals**: Auto-calculate subtotals

---

## 🗄️ Database Schema

### **carts** Table
```sql
CREATE TABLE carts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    branch_id BIGINT UNSIGNED NULL,
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id)
);
```

**Fields**:
- `user_id`: Owner of the cart
- `branch_id`: Associated branch (optional)
- One cart per user (auto-created if not exists)

---

### **cart_items** Table
```sql
CREATE TABLE cart_items (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    cart_id BIGINT UNSIGNED NOT NULL,
    menu_id BIGINT UNSIGNED NOT NULL,
    qty INT NOT NULL DEFAULT 1,
    price DECIMAL(10,2) NOT NULL,
    notes TEXT NULL,
    customizations JSON NULL,
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL,
    
    FOREIGN KEY (cart_id) REFERENCES carts(id) ON DELETE CASCADE,
    FOREIGN KEY (menu_id) REFERENCES menus(id) ON DELETE CASCADE,
    INDEX idx_cart_id (cart_id),
    INDEX idx_menu_id (menu_id)
);
```

**Fields**:
- `cart_id`: Parent cart
- `menu_id`: Menu item reference
- `qty`: Quantity (1+)
- `price`: Price snapshot (frozen at time of adding)
- `notes`: Special instructions (e.g., "No ice", "Extra spicy")
- `customizations`: JSON array of modifications

**Customizations Example**:
```json
{
  "size": "Large",
  "sugar_level": "50%",
  "ice_level": "Normal",
  "toppings": ["Boba", "Pudding"],
  "extras": {
    "extra_shot": true,
    "whipped_cream": false
  }
}
```

---

## 📡 API Endpoints

Base URL: `/api/cart`  
Authentication: Required (Bearer token)

---

### 1. Get Cart
**Endpoint**: `GET /api/cart`  
**Purpose**: Retrieve user's current cart with all items

**Request**:
```bash
curl -X GET "http://your-domain.com/api/cart" \
  -H "Authorization: Bearer {token}"
```

**Response** (Cart with items):
```json
{
  "status": "success",
  "data": {
    "cart": {
      "id": 123,
      "user_id": 456,
      "branch_id": 789,
      "created_at": "2025-12-01T10:00:00.000000Z",
      "updated_at": "2025-12-01T14:30:00.000000Z",
      "branch": {
        "id": 789,
        "name": "Branch A - Jakarta"
      }
    },
    "items": [
      {
        "id": 1,
        "cart_id": 123,
        "menu_id": 10,
        "qty": 2,
        "price": 45000,
        "notes": "Less sugar",
        "customizations": {
          "size": "Large",
          "ice_level": "50%"
        },
        "menu": {
          "id": 10,
          "name": "Iced Coffee",
          "code": "IC-001",
          "price": 45000,
          "brand": {
            "id": 1,
            "name": "Delite Coffee"
          }
        }
      }
    ],
    "total_items": 2,
    "subtotal": 90000
  },
  "message": "Cart retrieved successfully"
}
```

**Response** (Empty cart):
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

---

### 2. Add Item to Cart
**Endpoint**: `POST /api/cart/add`  
**Purpose**: Add menu item to cart (or update quantity if exists)

**Supports BOTH Old & New Menu Systems:**
- **Old System**: `menu_id` or `menu_code` 
- **New System**: `template_code` + `branch_id` or `branch_menu_item_id` ⭐

---

#### Option 1: Using OLD menu system (menu_code)
```bash
curl -X POST "http://your-domain.com/api/cart/add" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "menu_code": "IC-001",
    "qty": 2,
    "notes": "Less sugar please",
    "branch_id": 789
  }'
```

#### Option 2: Using NEW menu template system (template_code) ⭐ **RECOMMENDED**
```bash
curl -X POST "http://your-domain.com/api/cart/add" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "template_code": "IC-001",
    "branch_id": 90,
    "qty": 2,
    "notes": "Less sugar please",
    "customizations": {
      "size": "Large",
      "ice_level": "50%",
      "toppings": ["Boba"]
    }
  }'
```

#### Option 3: Using NEW menu template system (branch_menu_item_id) ⭐ **MOST SPECIFIC**
```bash
curl -X POST "http://your-domain.com/api/cart/add" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "branch_menu_item_id": 123,
    "qty": 2,
    "notes": "Extra ice"
  }'
```

**Request Body**:
- **Old System**:
  - `menu_id` (optional*): Menu item ID
  - `menu_code` (optional*): Menu item code (e.g., "IC-001")
  
- **New System** (recommended):
  - `template_code` (optional*): Menu template code + requires `branch_id`
  - `branch_menu_item_id` (optional*): Direct branch menu item ID (most specific)
  
  - *Note: Provide ONE of the above identifiers
  
- **Common Fields**:
  - `qty` (required): Quantity (minimum 1)
  - `notes` (optional): Special instructions
  - `customizations` (optional): JSON object with modifications
  - `branch_id` (optional): Branch ID (required if using `template_code`)

**Response** (New Menu Template System):
```json
{
  "status": "success",
  "data": {
    "cart_item": {
      "id": 1,
      "cart_id": 123,
      "menu_id": null,
      "branch_menu_item_id": 456,
      "menu_template_id": 789,
      "qty": 2,
      "price": 45000,
      "notes": "Less sugar please",
      "customizations": {
        "size": "Large",
        "ice_level": "50%",
        "toppings": ["Boba"]
      },
      "branch_menu_item": {
        "id": 456,
        "branch_id": 90,
        "is_available": true,
        "menu_template": {
          "id": 789,
          "code": "IC-001",
          "name": "Iced Coffee",
          "base_price": 40000,
          "category": "Beverages"
        }
      }
    },
    "menu_info": {
      "name": "Iced Coffee",
      "code": "IC-001",
      "price": 45000,
      "system": "new"
    }
  },
  "message": "Item added to cart"
}
```

**Response** (Old Menu System):
```json
{
  "status": "success",
  "data": {
    "cart_item": {
      "id": 1,
      "cart_id": 123,
      "menu_id": 10,
      "branch_menu_item_id": null,
      "menu_template_id": null,
      "qty": 2,
      "price": 45000,
      "notes": "Less sugar please"
    },
    "menu_info": {
      "name": "Iced Coffee",
      "code": "IC-001",
      "price": 45000,
      "system": "old"
    }
  },
  "message": "Item added to cart"
}
```

**Error Response** (no identifier provided):
```json
{
  "status": "error",
  "message": "Please provide one of: menu_id, menu_code, template_code, or branch_menu_item_id"
}
```

**Error Response** (template_code without branch_id):
```json
{
  "status": "error",
  "message": "branch_id is required when using template_code"
}
```

**Error Response** (item not available at branch):
```json
{
  "status": "error",
  "message": "This item is not available at the selected branch"
}
```

**Error Response** (item currently unavailable):
```json
{
  "status": "error",
  "message": "This item is currently unavailable"
}
```

**Behavior**:
- Accepts **OLD system**: `menu_id` or `menu_code`
- Accepts **NEW system**: `template_code` + `branch_id` OR `branch_menu_item_id`
- **NEW system checks availability** at specific branch
- If item **already in cart**: Quantity is **incremented** (qty += new_qty)
- If item **not in cart**: New cart item created
- Cart is **auto-created** if user doesn't have one

---

### 3. Update Cart Item
**Endpoint**: `PUT /api/cart/item/{itemId}`  
**Purpose**: Update quantity, notes, or customizations of existing cart item

**Request**:
```bash
curl -X PUT "http://your-domain.com/api/cart/item/1" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "qty": 3,
    "notes": "Extra ice",
    "customizations": {
      "size": "Large",
      "ice_level": "100%"
    }
  }'
```

**Request Body**:
- `qty` (required): New quantity
- `notes` (optional): Updated notes
- `customizations` (optional): Updated customizations

**Response**:
```json
{
  "status": "success",
  "data": {
    "id": 1,
    "cart_id": 123,
    "menu_id": 10,
    "qty": 3,
    "price": 45000,
    "notes": "Extra ice",
    "customizations": {
      "size": "Large",
      "ice_level": "100%"
    },
    "menu": {
      "id": 10,
      "name": "Iced Coffee"
    }
  },
  "message": "Cart item updated"
}
```

---

### 4. Remove Item from Cart
**Endpoint**: `DELETE /api/cart/item/{itemId}`  
**Purpose**: Remove specific item from cart

**Request**:
```bash
curl -X DELETE "http://your-domain.com/api/cart/item/1" \
  -H "Authorization: Bearer {token}"
```

**Response**:
```json
{
  "status": "success",
  "message": "Item removed from cart"
}
```

---

### 5. Clear Cart
**Endpoint**: `DELETE /api/cart/clear`  
**Purpose**: Remove all items from cart (cart itself remains)

**Request**:
```bash
curl -X DELETE "http://your-domain.com/api/cart/clear" \
  -H "Authorization: Bearer {token}"
```

**Response**:
```json
{
  "status": "success",
  "message": "Cart cleared successfully"
}
```

---

## 💡 Usage Examples

### Example 1: Complete Shopping Flow

```bash
# Step 1: Add first item using menu_code
curl -X POST "http://localhost/api/cart/add" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "menu_code": "IC-001",
    "qty": 2,
    "notes": "Less sugar"
  }'

# Step 2: Add second item using menu_id
curl -X POST "http://localhost/api/cart/add" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "menu_id": 15,
    "qty": 1,
    "customizations": {
      "size": "Large",
      "toppings": ["Boba", "Pudding"]
    }
  }'

# Step 3: View cart
curl -X GET "http://localhost/api/cart" \
  -H "Authorization: Bearer {token}"

# Step 4: Update first item quantity
curl -X PUT "http://localhost/api/cart/item/1" \
  -H "Authorization: Bearer {token}" \
  -d '{"qty": 3}'

# Step 5: Remove second item
curl -X DELETE "http://localhost/api/cart/item/2" \
  -H "Authorization: Bearer {token}"

# Step 6: Clear entire cart
curl -X DELETE "http://localhost/api/cart/clear" \
  -H "Authorization: Bearer {token}"
```

---

### Example 2: Cart with Menu Code

```javascript
// JavaScript example for mobile app - using menu_code
const addToCart = async (menuItem) => {
  const response = await fetch('http://api.example.com/api/cart/add', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${userToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      menu_code: menuItem.code,  // Use menu code instead of ID
      qty: 1,
      notes: "No ice",
      customizations: {
        size: "Medium",
        sugar_level: "50%",
        ice_level: "No ice",
        toppings: ["Boba"],
        extras: {
          extra_shot: true,
          whipped_cream: false
        }
      },
      branch_id: selectedBranch.id
    })
  });
  
  const data = await response.json();
  console.log('Item added:', data);
};
```

---

## 🔧 Business Logic

### Cart Creation
- Cart is **auto-created** when user adds first item
- One cart per user (existing cart is reused)
- Branch can be set during first item addition

### Item Addition
```
IF item already in cart:
  - Increment quantity (existing qty + new qty)
  - Update notes if provided
  - Update customizations if provided
ELSE:
  - Create new cart item
  - Snapshot menu price (frozen price)
```

### Price Handling
- Price is **frozen** when item added to cart
- Even if menu price changes, cart item keeps original price
- Ensures consistent pricing during checkout

### Customizations
- Stored as JSON (flexible structure)
- Can contain any key-value pairs
- Examples: size, sugar level, toppings, extras, modifications

### Cart Lifecycle
```
User adds item → Cart created (if not exists)
                ↓
User adds more items → Items accumulated
                ↓
User checks out → Order created from cart
                ↓
After checkout → Cart cleared (items deleted)
```

---

## 🔗 Integration Guide

### Checkout Integration

When user proceeds to checkout:

```php
// 1. Get cart items
$cart = Cart::where('user_id', $userId)
    ->with('items.menu')
    ->first();

// 2. Calculate totals
$subtotal = $cart->items->sum(function($item) {
    return $item->qty * $item->price;
});

// 3. Create order from cart
$order = Order::create([
    'user_id' => $userId,
    'branch_id' => $cart->branch_id,
    'total_amount' => $subtotal,
    // ... other fields
]);

// 4. Create order items from cart items
foreach ($cart->items as $cartItem) {
    OrderItem::create([
        'order_id' => $order->id,
        'menu_id' => $cartItem->menu_id,
        'qty' => $cartItem->qty,
        'price' => $cartItem->price,
        'notes' => $cartItem->notes,
        'customizations' => $cartItem->customizations,
    ]);
}

// 5. Clear cart after successful order
$cart->items()->delete();
```

---

### Voucher Integration

Apply voucher discount to cart total:

```php
// 1. Get cart total
$cartTotal = $cart->items->sum(function($item) {
    return $item->qty * $item->price;
});

// 2. Get active voucher
$voucher = DetailVoucher::where('user_id', $userId)
    ->where('status', 'active')
    ->with('voucher')
    ->first();

// 3. Calculate discount
if ($voucher) {
    $discount = 0;
    
    if ($voucher->voucher->voucher_type === 'discount_percentage') {
        $discount = ($cartTotal * $voucher->voucher->discount_percentage) / 100;
    } elseif ($voucher->voucher->voucher_type === 'discount_amount') {
        $discount = $voucher->voucher->discount_amount;
    }
    
    $finalTotal = $cartTotal - $discount;
}
```

---

## 📱 Mobile App Implementation

### Flutter Example

```dart
class CartService {
  final String baseUrl = 'http://api.example.com/api';
  final String token;
  
  CartService(this.token);
  
  // Get cart
  Future<Map<String, dynamic>> getCart() async {
    final response = await http.get(
      Uri.parse('$baseUrl/cart'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
    return json.decode(response.body);
  }
  
  // Add to cart (supports both menu_id and menu_code)
  Future<Map<String, dynamic>> addItem({
    int? menuId,
    String? menuCode,
    required int qty,
    String? notes,
    Map<String, dynamic>? customizations,
  }) async {
    // Must provide either menuId or menuCode
    if (menuId == null && menuCode == null) {
      throw Exception('Either menuId or menuCode is required');
    }
    
    final body = {
      'qty': qty,
      'notes': notes,
      'customizations': customizations,
    };
    
    // Add either menu_id or menu_code to body
    if (menuCode != null) {
      body['menu_code'] = menuCode;
    } else {
      body['menu_id'] = menuId;
    }
    
    final response = await http.post(
      Uri.parse('$baseUrl/cart/add'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );
    return json.decode(response.body);
  }
  
  // Update item
  Future<Map<String, dynamic>> updateItem({
    required int itemId,
    required int qty,
    String? notes,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/cart/item/$itemId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'qty': qty,
        'notes': notes,
      }),
    );
    return json.decode(response.body);
  }
  
  // Remove item
  Future<void> removeItem(int itemId) async {
    await http.delete(
      Uri.parse('$baseUrl/cart/item/$itemId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
  }
  
  // Clear cart
  Future<void> clearCart() async {
    await http.delete(
      Uri.parse('$baseUrl/cart/clear'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
  }
}
```

---

## ⚠️ Error Handling

### Common Errors

**Error: User ID required**
```json
{
  "status": "error",
  "message": "User ID required"
}
```
Solution: Ensure user is authenticated

**Error: Menu not found**
```json
{
  "status": "error",
  "message": "Menu not found"
}
```
Solution: Verify menu_id exists

**Error: Cart item not found**
```json
{
  "status": "error",
  "message": "Cart item not found"
}
```
Solution: Verify item belongs to user's cart

---

## 📊 Best Practices

### 1. Update Cart Badge
```javascript
// Real-time cart count
const updateCartBadge = async () => {
  const cart = await getCart();
  const itemCount = cart.data.total_items;
  updateBadge(itemCount);
};
```

### 2. Validate Before Checkout
```php
// Ensure cart not empty
if ($cart->items->count() === 0) {
    return response()->json([
        'status' => 'error',
        'message' => 'Cart is empty'
    ], 400);
}

// Ensure all items still available
foreach ($cart->items as $item) {
    $menu = Menu::find($item->menu_id);
    if (!$menu || !$menu->is_available) {
        return response()->json([
            'status' => 'error',
            'message': "Item {$menu->name} is no longer available"
        ], 400);
    }
}
```

### 3. Handle Price Changes
```php
// Show warning if price changed
foreach ($cart->items as $item) {
    $currentPrice = $item->menu->price;
    if ($item->price != $currentPrice) {
        // Notify user: "Price has changed from Rp X to Rp Y"
    }
}
```

---

## 🚀 Summary

The Cart System provides:
- ✅ Persistent shopping cart
- ✅ Quantity management
- ✅ Menu customizations support
- ✅ Special instructions (notes)
- ✅ Real-time totals
- ✅ Seamless checkout integration

**Next Steps**: See `VOUCHER_SYSTEM_COMPLETE_USER_FLOW.md` for voucher integration with cart.

---

**End of Cart System Documentation**
