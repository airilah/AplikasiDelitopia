# 🎫 Voucher System - Quick Reference Card

## 📱 For Users

### Browse Vouchers (Tab 1)
- **Points Balance** - See your current points at the top
- **Point Vouchers** - Redeem using your points (🟠 Orange)
- **Cash Vouchers** - Purchase with money (🟢 Green)
- **Locked Icon** - Not enough points to redeem

### My Vouchers (Tab 2)
- **Inactive** (⚪ Grey) - Need to activate first
- **Active** (🟢 Green) - Ready to use
- **Used** (🔵 Blue) - Already consumed
- **Expired** (🔴 Red) - Past expiry date

### Points History (Tab 3)
- **+X Poin** (🟢 Green) - Points earned
- **-X Poin** (🔴 Red) - Points spent
- **Balance** - Total available points

---

## 🔄 Actions

### Redeem with Points
1. Tap voucher → "Tukar X Poin"
2. Voucher moves to "My Vouchers"
3. Status: Inactive
4. Activate when ready

### Purchase with Cash
1. Tap voucher → "Beli Rp X"
2. Complete QRIS payment
3. Voucher appears in wallet
4. Status: Inactive

### Activate Voucher
1. Tap inactive voucher
2. "Aktifkan Voucher"
3. Confirm activation
4. Status → Active
5. Expiry countdown starts

### Use Voucher
1. Tap active voucher
2. "Gunakan Voucher"
3. System validates limits
4. Apply at checkout

---

## 🎯 Voucher Types

| Type | Icon | Description |
|------|------|-------------|
| Percentage | 📊 | 15% off |
| Amount | 💵 | Rp 20,000 off |
| Buy 1 Get 1 | 🎁 | Free item |
| Free Item | 🆓 | Complimentary item |

---

## ⏱️ Usage Limits

| Type | Description | Example |
|------|-------------|---------|
| Unlimited | No limit | Use anytime |
| Once/Day | Daily reset | 1x per day |
| Total Limit | Max uses | Max 5x total |
| Both | Combined | 2x daily, 30x total |

---

## 📅 Expiry Types

| Type | Calculation | Example |
|------|-------------|---------|
| Duration | Days after activation | 30 days |
| Monthly | End of month | Dec 31, 2025 |
| Fixed | Specific date | 2025-12-25 |

---

## 🔐 Authentication

- JWT token required
- Auto-login from SharedPreferences
- User ID validated on each request

---

## ❌ Common Errors

| Error | Meaning | Solution |
|-------|---------|----------|
| "Insufficient points" | Not enough points | Earn more points |
| "Daily limit reached" | Used max today | Wait until tomorrow |
| "Voucher expired" | Past expiry date | Get new voucher |
| "Already redeemed" | Duplicate claim | Check My Vouchers |

---

## 📊 Status Flow

```
[Purchase/Redeem] → INACTIVE
         ↓ (Activate)
       ACTIVE
         ↓ (Use)
    USED or EXPIRED
```

---

## 🎨 Color Codes

- 🔴 Red - Error, Expired, Points spent
- 🟢 Green - Success, Active, Points earned
- 🟠 Orange - Point vouchers
- 🟢 Green - Cash vouchers
- ⚪ Grey - Inactive, Locked

---

## 🚀 Quick Tips

1. **Check points first** - View balance on Tab 1
2. **Activate when ready** - Expiry starts after activation
3. **Read limits** - Daily/total usage restrictions
4. **Check expiry** - Valid until date shown
5. **Validate before use** - System checks automatically

---

## 📞 Support

For issues:
1. Pull to refresh
2. Re-login if needed
3. Check network connection
4. Contact support if persists

---

**Last Updated:** December 1, 2025  
**App Version:** 1.0  
**Status:** ✅ Production Ready
