# User App - POS Integration Guide
## Displaying Member Code & Voucher Claim Codes

This guide shows how to implement the **Member Profile** and **Voucher Redemption** features in the user mobile app for offline POS usage.

---

## 📱 Feature 1: My Member Profile (QR Code)

### Purpose
Display user's **Member Code** as both text and QR code so cashiers can:
- Identify the customer
- View their points and level
- See available vouchers

### API Endpoint
```
GET /api/postData/pos/my-member-profile
Authorization: Bearer {token}
```

### Request Example
```bash
curl -X GET https://delitopia.softindopp.com/api/postData/pos/my-member-profile \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Response
```json
{
  "status": "success",
  "data": {
    "user": {
      "id": 22,
      "name": "Michael",
      "phone_number": "08186888771",
      "email": "softindoputraperkasa@gmail.com",
      "member_code": "DLT-251201-A1B2",
      "point": 8,
      "user_level": {
        "name": "Bronze",
        "icon": "bronze.png",
        "color": "#CD7F32"
      }
    },
    "qr_data": "DLT-251201-A1B2"
  },
  "message": "Member profile retrieved successfully"
}
```

### UI Implementation

**Screen Layout:**
```
┌─────────────────────────────────────┐
│        MY MEMBER PROFILE            │
├─────────────────────────────────────┤
│                                     │
│         ┌─────────────────┐         │
│         │                 │         │
│         │   QR CODE HERE  │         │
│         │  DLT-251201-A1B2│         │
│         │                 │         │
│         └─────────────────┘         │
│                                     │
│         Member Code                 │
│      DLT-251201-A1B2                │
│   (Show this to cashier)            │
│                                     │
│   ┌─────────────────────────────┐   │
│   │ Name: Michael               │   │
│   │ Phone: 08186888771          │   │
│   │ Email: softindo@gmail.com   │   │
│   │                             │   │
│   │ Points: 8                   │   │
│   │ Level: Bronze 🥉            │   │
│   └─────────────────────────────┘   │
│                                     │
│   [ Copy Code ]  [ Share QR ]       │
│                                     │
└─────────────────────────────────────┘
```

### Flutter/React Native Example

**Flutter (using qr_flutter package):**
```dart
import 'package:qr_flutter/qr_flutter.dart';

class MemberProfileScreen extends StatelessWidget {
  final MemberProfile profile;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Member Profile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // QR Code
            QrImageView(
              data: profile.qrData, // "DLT-251201-A1B2"
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
            ),
            
            SizedBox(height: 20),
            
            // Member Code Text
            Text(
              'Member Code',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            Text(
              profile.user.memberCode,
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                letterSpacing: 2
              ),
            ),
            
            Text(
              '(Show this to cashier)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            
            SizedBox(height: 30),
            
            // User Info Card
            Card(
              margin: EdgeInsets.all(16),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name: ${profile.user.name}'),
                    Text('Phone: ${profile.user.phoneNumber}'),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Points: ${profile.user.point}'),
                        Text('Level: ${profile.user.userLevel.name}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.copy),
                  label: Text('Copy Code'),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: profile.user.memberCode)
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Code copied!'))
                    );
                  },
                ),
                SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: Icon(Icons.share),
                  label: Text('Share QR'),
                  onPressed: () {
                    // Share QR code image
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

**React Native (using react-native-qrcode-svg):**
```javascript
import QRCode from 'react-native-qrcode-svg';

const MemberProfileScreen = ({ profile }) => {
  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>MY MEMBER PROFILE</Text>
      
      {/* QR Code */}
      <View style={styles.qrContainer}>
        <QRCode
          value={profile.qr_data}
          size={200}
          backgroundColor="white"
        />
      </View>
      
      {/* Member Code */}
      <Text style={styles.label}>Member Code</Text>
      <Text style={styles.memberCode}>{profile.user.member_code}</Text>
      <Text style={styles.hint}>(Show this to cashier)</Text>
      
      {/* User Info */}
      <View style={styles.card}>
        <Text>Name: {profile.user.name}</Text>
        <Text>Phone: {profile.user.phone_number}</Text>
        <View style={styles.row}>
          <Text>Points: {profile.user.point}</Text>
          <Text>Level: {profile.user.user_level.name}</Text>
        </View>
      </View>
      
      {/* Actions */}
      <View style={styles.actions}>
        <Button title="Copy Code" onPress={handleCopyCode} />
        <Button title="Share QR" onPress={handleShareQR} />
      </View>
    </ScrollView>
  );
};
```

---

## 🎫 Feature 2: Voucher Claim Codes

### Purpose
Display each voucher's **Claim Code** as both text and QR code so users can redeem vouchers at physical stores.

### API Endpoint
```
GET /api/postData/my-vouchers
Authorization: Bearer {token}
```

### Request Example
```bash
curl -X GET https://delitopia.softindopp.com/api/postData/my-vouchers \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Response
```json
{
  "status": "success",
  "data": {
    "vouchers": [
      {
        "id": 789,
        "claim_code": "WXYZ-1234",
        "status": "active",
        "expiry_date": "2025-12-31 23:59:59",
        "activation_date": "2025-12-01 10:30:00",
        "usage_count": 0,
        "voucher": {
          "id": 5,
          "voucher_name": "Diskon 20% Semua Menu",
          "voucher_type": "discount_percentage",
          "description": "Potongan 20% untuk minimal pembelian Rp100.000",
          "discount_percentage": 20,
          "discount_amount": null,
          "min_spend": 100000,
          "image": "https://delitopia.softindopp.com/images/vouchers/20percent.jpg",
          "brand": {
            "name": "Delitopia",
            "logo": "https://delitopia.softindopp.com/images/logo.png"
          }
        }
      },
      {
        "id": 790,
        "claim_code": "ABCD-5678",
        "status": "inactive",
        "expiry_date": null,
        "activation_date": null,
        "usage_count": 0,
        "voucher": {
          "id": 12,
          "voucher_name": "Gratis 1 Menu Pilihan",
          "voucher_type": "free_menu",
          "description": "Dapatkan 1 menu gratis (max Rp50.000)",
          "discount_percentage": null,
          "discount_amount": null,
          "min_spend": 0,
          "image": "https://delitopia.softindopp.com/images/vouchers/freemenu.jpg",
          "brand": {
            "name": "Tomoko Sushi",
            "logo": "https://delitopia.softindopp.com/images/tomoko_logo.png"
          }
        }
      }
    ],
    "total_active": 1,
    "total_inactive": 1,
    "total_used": 0
  },
  "message": "Vouchers retrieved successfully"
}
```

### UI Implementation

**Voucher List Screen:**
```
┌─────────────────────────────────────┐
│         MY VOUCHERS                 │
├─────────────────────────────────────┤
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ [Voucher Image]                 │ │
│ │                                 │ │
│ │ Diskon 20% Semua Menu           │ │
│ │ Brand: Delitopia                │ │
│ │                                 │ │
│ │ Min. Spend: Rp 100.000          │ │
│ │ Expires: 31 Dec 2025            │ │
│ │                                 │ │
│ │ Status: ✅ Active               │ │
│ │                                 │ │
│ │ [ Use in App ]  [ Show Code ]   │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ [Voucher Image]                 │ │
│ │                                 │ │
│ │ Gratis 1 Menu Pilihan           │ │
│ │ Brand: Tomoko Sushi             │ │
│ │                                 │ │
│ │ Min. Spend: -                   │ │
│ │ Not activated yet               │ │
│ │                                 │ │
│ │ Status: ⏸️ Inactive             │ │
│ │                                 │ │
│ │ [ Activate Now ]  [ Generate ]  │ │
│ └─────────────────────────────────┘ │
│                                     │
└─────────────────────────────────────┘
```

**Voucher Detail/QR Screen (when "Show Code" tapped):**
```
┌─────────────────────────────────────┐
│     VOUCHER CLAIM CODE              │
├─────────────────────────────────────┤
│                                     │
│  Diskon 20% Semua Menu              │
│  [Brand: Delitopia]                 │
│                                     │
│         ┌─────────────────┐         │
│         │                 │         │
│         │   QR CODE HERE  │         │
│         │   WXYZ-1234     │         │
│         │                 │         │
│         └─────────────────┘         │
│                                     │
│         Claim Code                  │
│         WXYZ-1234                   │
│   (Show this to cashier)            │
│                                     │
│   ┌─────────────────────────────┐   │
│   │ How to Use at Store:        │   │
│   │                             │   │
│   │ 1. Show this code/QR to     │   │
│   │    cashier                  │   │
│   │ 2. Cashier will scan/enter  │   │
│   │    the code                 │   │
│   │ 3. Discount will be applied │   │
│   │    automatically            │   │
│   │                             │   │
│   │ Min. Purchase: Rp 100.000   │   │
│   │ Discount: 20%               │   │
│   │ Valid Until: 31 Dec 2025    │   │
│   └─────────────────────────────┘   │
│                                     │
│   [ Copy Code ]  [ Close ]          │
│                                     │
└─────────────────────────────────────┘
```

### Flutter Example

```dart
// Voucher Card Widget
class VoucherCard extends StatelessWidget {
  final VoucherData voucher;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Voucher Image
          Image.network(
            voucher.voucher.image,
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Voucher Name
                Text(
                  voucher.voucher.voucherName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                SizedBox(height: 4),
                
                // Brand
                Text(
                  'Brand: ${voucher.voucher.brand.name}',
                  style: TextStyle(color: Colors.grey),
                ),
                
                SizedBox(height: 8),
                
                // Details
                if (voucher.voucher.minSpend > 0)
                  Text('Min. Spend: Rp ${formatNumber(voucher.voucher.minSpend)}'),
                
                if (voucher.expiryDate != null)
                  Text('Expires: ${formatDate(voucher.expiryDate)}'),
                
                SizedBox(height: 8),
                
                // Status Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: voucher.status == 'active' 
                      ? Colors.green.shade100 
                      : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    voucher.status == 'active' ? '✅ Active' : '⏸️ Inactive',
                    style: TextStyle(
                      color: voucher.status == 'active' 
                        ? Colors.green.shade700 
                        : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                SizedBox(height: 12),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        child: Text('Use in App'),
                        onPressed: () => _useInApp(context, voucher),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        child: Text('Show Code'),
                        onPressed: voucher.claimCode != null
                          ? () => _showClaimCode(context, voucher)
                          : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showClaimCode(BuildContext context, VoucherData voucher) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ClaimCodeSheet(voucher: voucher),
    );
  }
}

// Claim Code Bottom Sheet
class ClaimCodeSheet extends StatelessWidget {
  final VoucherData voucher;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'VOUCHER CLAIM CODE',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          SizedBox(height: 10),
          
          Text(
            voucher.voucher.voucherName,
            style: TextStyle(fontSize: 16),
          ),
          
          SizedBox(height: 20),
          
          // QR Code
          QrImageView(
            data: voucher.claimCode,
            version: QrVersions.auto,
            size: 200.0,
            backgroundColor: Colors.white,
          ),
          
          SizedBox(height: 20),
          
          // Claim Code Text
          Text(
            'Claim Code',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          Text(
            voucher.claimCode,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          Text(
            '(Show this to cashier)',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          
          SizedBox(height: 20),
          
          // Instructions
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to Use at Store:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('1. Show this code/QR to cashier'),
                Text('2. Cashier will scan/enter the code'),
                Text('3. Discount will be applied automatically'),
                SizedBox(height: 8),
                if (voucher.voucher.minSpend > 0)
                  Text(
                    'Min. Purchase: Rp ${formatNumber(voucher.voucher.minSpend)}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                if (voucher.voucher.discountPercentage != null)
                  Text('Discount: ${voucher.voucher.discountPercentage}%'),
                if (voucher.expiryDate != null)
                  Text('Valid Until: ${formatDate(voucher.expiryDate)}'),
              ],
            ),
          ),
          
          SizedBox(height: 20),
          
          // Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.copy),
                  label: Text('Copy Code'),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: voucher.claimCode)
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Code copied!'))
                    );
                  },
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  child: Text('Close'),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

---

## 🔄 Feature 3: Generate Claim Code (for inactive vouchers)

### Purpose
Allow users to generate a claim code for vouchers that don't have one yet (status: `inactive`).

### API Endpoint
```
POST /api/postData/pos/generate-claim-code
Authorization: Bearer {token}
Content-Type: application/json
```

### Request
```json
{
  "detail_voucher_id": 790
}
```

### Response
```json
{
  "status": "success",
  "data": {
    "detail_voucher_id": 790,
    "claim_code": "ABCD-5678",
    "qr_data": "ABCD-5678",
    "status": "active",
    "voucher_name": "Gratis 1 Menu Pilihan",
    "expiry_date": "2026-12-01 23:59:59"
  },
  "message": "Claim code generated successfully. Show this code to cashier."
}
```

**Note:** This endpoint automatically **activates** the voucher if it was inactive.

### Flutter Implementation

```dart
Future<void> generateClaimCode(int detailVoucherId) async {
  try {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );
    
    final response = await http.post(
      Uri.parse('$baseUrl/api/postData/pos/generate-claim-code'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'detail_voucher_id': detailVoucherId,
      }),
    );
    
    Navigator.pop(context); // Close loading dialog
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // Show success and display the claim code
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('✅ Code Generated'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: data['data']['claim_code'],
                size: 150,
              ),
              SizedBox(height: 10),
              Text(
                data['data']['claim_code'],
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 10),
              Text(data['message']),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Copy Code'),
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: data['data']['claim_code'])
                );
              },
            ),
            TextButton(
              child: Text('Close'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      
      // Refresh voucher list
      refreshVouchers();
      
    } else {
      // Show error
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Error'),
          content: Text('Failed to generate code'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    Navigator.pop(context); // Close loading dialog
    print('Error: $e');
  }
}
```

---

## 📊 Summary

### Three Main Features to Implement:

1. **Member Profile Screen**
   - Endpoint: `GET /api/postData/pos/my-member-profile`
   - Shows: Member code as QR + text
   - Purpose: Customer identification at POS

2. **My Vouchers Screen**
   - Endpoint: `GET /api/postData/my-vouchers`
   - Shows: List of vouchers with claim codes
   - Purpose: View and use vouchers offline

3. **Voucher Claim Code Detail**
   - Shows: Individual voucher's claim code as QR + text
   - Purpose: Redeem voucher at physical store
   - Bonus: Generate code button for inactive vouchers

### QR Code Libraries

**Flutter:**
```yaml
dependencies:
  qr_flutter: ^4.1.0
```

**React Native:**
```bash
npm install react-native-qrcode-svg
```

**Android Native:**
```gradle
implementation 'com.google.zxing:core:3.5.0'
implementation 'com.journeyapps:zxing-android-embedded:4.3.0'
```

**iOS Native:**
Use `CIFilter` with `CIQRCodeGenerator`

---

## 🔐 Security Notes

1. **Always use HTTPS** for API calls
2. **Include Authorization header** with Bearer token
3. **Validate token expiry** and refresh when needed
4. **Don't cache sensitive data** (member codes, claim codes)
5. **Clear QR codes** when user logs out

---

## 🎨 Design Tips

1. Make QR codes **large enough to scan** (minimum 200x200px)
2. Use **high contrast** (black on white background)
3. Add **clear instructions** for cashiers
4. Include **copy button** for manual code entry
5. Show **expiry date prominently**
6. Use **status badges** (Active/Inactive/Used)
7. Add **brand logo** on voucher cards

---

## ✅ Testing Checklist

- [ ] Member profile loads correctly
- [ ] QR code displays member code
- [ ] Member code is copyable
- [ ] Voucher list shows all user vouchers
- [ ] Each voucher shows claim code (if available)
- [ ] Claim code QR is scannable
- [ ] Generate code works for inactive vouchers
- [ ] Status badges show correctly
- [ ] Expiry dates format properly
- [ ] Copy buttons work
- [ ] Share functionality works
- [ ] Handles errors gracefully
- [ ] Works offline (shows cached data with warning)

---

**Last Updated:** December 2, 2025  
**API Base URL:** https://delitopia.softindopp.com  
**For POS Integration:** See `docs/OFFLINE_POS_VOUCHER_SYSTEM.md`
