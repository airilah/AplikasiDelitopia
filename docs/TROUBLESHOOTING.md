# Voucher & Points System - Troubleshooting Guide

## Current Status
The voucher system has been fully implemented with proper error handling.

## What's Been Fixed

### 1. API Integration ✅
- All voucher endpoints properly configured
- Safe type casting throughout all models
- Error handling returns empty data instead of crashing

### 2. Navigation ✅
- Back button no longer exits app
- Double-tap to exit with confirmation dialog
- All views navigate properly

### 3. Data Parsing ✅
- All type conversions safe with null checks
- DateTime parsing uses tryParse
- Flexible API response handling

## If Vouchers/Points Still Not Showing

### Quick Checks:

1. **Check if API is returning data:**
   - Look for `❌ Voucher Error:`, `❌ Points Error:`, `❌ My Vouchers Error:` in logs
   - These will show if API calls are failing

2. **Verify API responses:**
   - The API endpoint is: `https://delitopia.softindopp.com/api/getData/voucher`
   - Should return: `{status: "success", data: [...]}`

3. **Check authentication:**
   - Make sure user is logged in
   - Token is being sent with requests

## Testing the System

### Test Voucher Tab:
1. Open app
2. Navigate to Profile or use voucher icon
3. Should show 3 tabs: Semua Voucher, Voucher Saya, Riwayat Poin

### What Should Happen:
- **Tab 1 (Semua Voucher)**: Shows all available vouchers from API
- **Tab 2 (Voucher Saya)**: Shows user's owned vouchers  
- **Tab 3 (Riwayat Poin)**: Shows points transaction history

### If Empty:
- Check logs for error messages
- Verify API is reachable
- Confirm user authentication

## Common Issues

### Issue: "Lost connection to device"
**Solution**: App exited - this is normal when testing back button

### Issue: Vouchers not loading
**Possible causes:**
1. API endpoint changed
2. Network error
3. Authentication token expired
4. API returning different response structure

**Debug steps:**
1. Check console for `❌` error messages
2. Verify internet connection
3. Re-login to refresh token

### Issue: Type cast errors
**Status**: FIXED - All models now use safe casting

### Issue: Points not displaying on home
**Check**: User model has `point` field
**Location**: Should show on home page cards

## Technical Details

### Models Fixed:
- ✅ voucher_model.dart (4 models)
- ✅ user_model.dart  
- ✅ all shared models (menu, branch, notification, etc.)
- ✅ cart_model.dart
- ✅ order_model.dart
- ✅ favorite_model.dart
- ✅ address_model.dart

### Services Updated:
- ✅ voucher_service.dart (14 endpoints)
- ✅ order_service.dart (historyOrder fix)

### Views Enhanced:
- ✅ vouchers_view.dart (3-tab interface with back handling)
- ✅ navigation_view.dart (double-tap exit)

## Next Steps if Still Issues

1. **Hot Restart**: Press 'R' in terminal
2. **Full Rebuild**: `flutter clean && flutter run`
3. **Check API**: Test endpoint directly with Postman
4. **Review Logs**: Look for specific error messages

## Support

If errors persist, provide:
1. Exact error message from console
2. Which tab/feature is affected
3. Any red error screens shown
