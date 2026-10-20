# Animation Testing Checklist

## 🎯 Visual Testing Guide

### Home Page Animations

#### Loading States
- [ ] Home page shows custom shimmer (not CircularProgressIndicator)
- [ ] Header shimmer shows gradient placeholder
- [ ] 4 brand card shimmers appear in horizontal row
- [ ] Banner shimmer shows with rounded corners
- [ ] Shimmer animation cycles smoothly (grey[300] → grey[100])

#### Interactive Elements
- [ ] Notification bell scales down (0.95) when tapped
- [ ] Notification bell scales back up when released
- [ ] Animation feels responsive (100ms)

#### Brand Cards
- [ ] Brand cards scale down (0.97) when tapped
- [ ] Scale animation is smooth (150ms)
- [ ] All 8 brands are horizontally scrollable
- [ ] 4 brands are visible initially
- [ ] Cards bounce when reaching scroll limits

#### Banner Carousel
- [ ] Banner images scale on tap (0.97)
- [ ] Page indicators animate smoothly
- [ ] Active indicator is wider (24px) than inactive (8px)
- [ ] Indicator color transitions smoothly

#### Points & Vouchers Cards
- [ ] Points card scales on tap (0.97)
- [ ] Vouchers card scales on tap (0.97)
- [ ] Gradient backgrounds render correctly
- [ ] Shadows appear properly

#### Popular Items
- [ ] Product cards scale on tap (0.97)
- [ ] Grid shimmer shows correct number of columns
- [ ] Loading state shows grid shimmer (not circular)
- [ ] Cards have subtle elevation change on tap

#### Voucher List
- [ ] Voucher items scale on tap (0.97)
- [ ] List shimmer shows 3 items
- [ ] Each voucher has proper color based on type
- [ ] "Use" button is part of the animated card

#### Staggered Sections
- [ ] Sections appear one after another (80ms delay)
- [ ] Each section slides and fades in
- [ ] Animation feels natural, not jarring
- [ ] Refresh triggers staggered animation again

### Performance Checks
- [ ] All animations run at 60 FPS
- [ ] No jank or stuttering during animations
- [ ] Smooth scrolling while animations play
- [ ] No performance issues on mid-range devices
- [ ] Memory usage stays stable

### Edge Cases
- [ ] Rapid tapping doesn't break animations
- [ ] Animations work correctly after refresh
- [ ] Animations work in both portrait and landscape
- [ ] Dark mode compatible (if implemented)
- [ ] Animations respect system animation settings

### Cross-Platform Testing
- [ ] iOS: Animations feel native to iOS
- [ ] Android: Animations feel native to Android
- [ ] Both platforms: Consistent animation timing
- [ ] Both platforms: No platform-specific bugs

## 🚀 Testing Commands

```bash
# Run on iOS simulator
flutter run -d ios

# Run on Android emulator
flutter run -d android

# Run with performance overlay
flutter run --profile

# Check for jank (use this!)
flutter run --trace-skia
```

## 📊 Performance Benchmarks

Target metrics:
- Frame render time: < 16ms (60 FPS)
- Animation start delay: < 50ms
- Memory usage: < 100MB for animations
- CPU usage during animations: < 30%

## 🔍 Common Issues to Watch For

1. **Shimmer not appearing:** Check imports and widget tree
2. **Animations too fast/slow:** Adjust duration in AnimatedCard/AnimatedButton
3. **Cards not scaling:** Verify onTap is wrapped in AnimatedCard
4. **Stagger not working:** Check StaggeredListAnimation children property
5. **Jarring transitions:** Reduce scale values (try 0.98 instead of 0.97)

## 🎨 Visual Polish Checklist

- [ ] All loading states use shimmer (no CircularProgressIndicator visible)
- [ ] Tap feedback is instant (< 50ms delay)
- [ ] Scale animations feel "springy" not linear
- [ ] Colors and shadows enhance depth
- [ ] Animations guide user attention appropriately
- [ ] No distracting or excessive motion

## ✅ Sign-Off

- [ ] Developer: Animations implemented correctly
- [ ] QA: All animations tested on real devices
- [ ] Designer: Visual polish meets design standards
- [ ] PM: User experience is enhanced by animations

---

**Testing Date:** _________________
**Tester Name:** _________________
**Device Tested:** _________________
**OS Version:** _________________
**Issues Found:** _________________
