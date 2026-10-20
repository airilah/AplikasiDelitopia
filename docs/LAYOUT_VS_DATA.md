# Layout vs Data: Understanding the Dynamic UI System

## The Key Difference

### 🎨 Layout (Controlled by Schema)
**What it is**: How widgets are arranged, styled, and configured  
**Where it comes from**: `/getData/uiSchema` endpoint  
**Update method**: Change JSON on server, users pull-to-refresh  
**No app update needed**: ✅ Yes

**Examples:**
```json
{
  "type": "featured_brands",
  "order": 1,              // ← Layout: Position on page
  "visible": true,         // ← Layout: Show or hide
  "properties": {
    "max_items": 4,        // ← Layout: How many to display
    "show_as_grid": true   // ← Layout: Grid or horizontal scroll
  }
}
```

### 📊 Data (From Existing APIs)
**What it is**: The actual content (brands, products, prices, images)  
**Where it comes from**: Existing API endpoints  
**Update method**: Update database, API returns new data  
**No app update needed**: ✅ Yes (already works this way)

**Examples:**
- Brand names, logos → `/getData/brand`
- Product names, prices, images → `/getData/menuByBranch`
- Banner images → `/getData/banner`

## Real-World Examples

### Example 1: Change Number of Brands Shown

**What you want**: Show 6 brands instead of 4

**Schema Change** (No app update):
```json
{
  "type": "featured_brands",
  "properties": {
    "max_items": 6  // Changed from 4
  }
}
```

**Widget Behavior**:
1. Fetches all brands from `/getData/brand` (same as before)
2. Takes first 6 instead of first 4 (controlled by schema)
3. Displays them in grid (still from schema)

**No data API changes needed** - widget still calls `/getData/brand`

---

### Example 2: Hide Popular Items Section

**What you want**: Temporarily hide popular items during maintenance

**Schema Change** (No app update):
```json
{
  "type": "popular_items",
  "visible": false  // Hide the section
}
```

**Widget Behavior**:
- Widget checks `visible: false`
- Returns empty container
- Doesn't waste API calls

**Data API** still works - just not displayed

---

### Example 3: Reorder Sections

**What you want**: Show nearest locations before featured brands

**Schema Change** (No app update):
```json
// Before
[
  {"type": "featured_brands", "order": 1},
  {"type": "nearest_location", "order": 9}
]

// After
[
  {"type": "featured_brands", "order": 9},  // Swapped
  {"type": "nearest_location", "order": 1}  // Swapped
]
```

**Widget Behavior**:
- DynamicHomePage sorts sections by `order`
- Renders in new sequence
- Each widget still fetches its own data

---

### Example 4: Add New Brand (Data Change)

**What you want**: Add "Starbucks" to the app

**Database Change**:
```sql
INSERT INTO brands (name, logo, category) 
VALUES ('Starbucks', 'starbucks.png', 'Coffee');
```

**API Response** from `/getData/brand`:
```json
{
  "status": "success",
  "data": [
    {"id": 1, "name": "TOMOKO", ...},
    {"id": 5, "name": "Starbucks", ...}  // New brand
  ]
}
```

**Widget Behavior**:
- Fetches brands (now includes Starbucks)
- Takes first `max_items` (from schema)
- Displays them

**No schema change needed** - layout stays the same

---

## What Needs Schema Updates vs Data Updates

| Change Needed | Requires Schema Update | Requires Data Update | App Update |
|--------------|----------------------|---------------------|-----------|
| Show 6 brands instead of 4 | ✅ Yes | ❌ No | ❌ No |
| Hide a section | ✅ Yes | ❌ No | ❌ No |
| Reorder sections | ✅ Yes | ❌ No | ❌ No |
| Change grid to scroll | ✅ Yes | ❌ No | ❌ No |
| Change section title | ✅ Yes | ❌ No | ❌ No |
| Add new brand | ❌ No | ✅ Yes | ❌ No |
| Update product price | ❌ No | ✅ Yes | ❌ No |
| Change banner image | ❌ No | ✅ Yes | ❌ No |
| Update branch address | ❌ No | ✅ Yes | ❌ No |
| Add new widget type | ❌ No | ❌ No | ✅ Yes |

## Common Scenarios

### Scenario: Holiday Promotion

**Want to**:
- Show more products (6 → 12)
- Add holiday banner
- Highlight vouchers section

**Schema updates**:
```json
{
  "sections": [
    {
      "type": "popular_items",
      "properties": {"max_items": 12}  // Show more
    },
    {
      "type": "vouchers_card",
      "style": {"background_color": "#FF0000"}  // Red highlight
    }
  ]
}
```

**Data updates**:
- Upload holiday banners to server
- Create holiday vouchers in database
- Flag holiday products as popular

**Result**: No app update, instant changes

---

### Scenario: Performance Testing

**Want to**: Test if fewer items improves speed

**Schema A/B Test**:
```json
// Version A: Show 4 brands
{"properties": {"max_items": 4}}

// Version B: Show 8 brands
{"properties": {"max_items": 8}}
```

**Deploy**:
- 50% users get schema A
- 50% users get schema B
- Measure performance
- Choose winner
- Deploy to 100%

**All without app update**

---

## Architecture Summary

```
┌─────────────────────────────────────────────────────┐
│                   Your Backend                      │
├─────────────────────────────────────────────────────┤
│                                                     │
│  NEW: /getData/uiSchema                            │
│  └─► Returns: Layout configuration (JSON)          │
│      • Widget types, order, visibility             │
│      • max_items, columns, styling                 │
│                                                     │
│  EXISTING: /getData/brand                          │
│  └─► Returns: Brand data (unchanged)               │
│                                                     │
│  EXISTING: /getData/menuByBranch                   │
│  └─► Returns: Product data (unchanged)             │
│                                                     │
│  EXISTING: /getData/banner                         │
│  └─► Returns: Banner data (unchanged)              │
│                                                     │
└─────────────────────────────────────────────────────┘
                        │
                        │ API Calls
                        ▼
┌─────────────────────────────────────────────────────┐
│                   Mobile App                        │
├─────────────────────────────────────────────────────┤
│                                                     │
│  DynamicHomePage                                   │
│  ├─► Fetch schema (layout rules)                   │
│  └─► Build page based on schema                    │
│                                                     │
│  FeaturedBrandsWidget                              │
│  ├─► Read max_items from schema                    │
│  ├─► Fetch brands from /getData/brand              │
│  └─► Display first {max_items} brands              │
│                                                     │
│  PopularItemsWidget                                │
│  ├─► Read columns from schema                      │
│  ├─► Fetch products from /getData/menuByBranch     │
│  └─► Display in {columns} column grid              │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## Benefits

### For Backend Team
- Change layouts without coordinating with mobile team
- A/B test different configurations
- Emergency: Hide broken sections instantly
- No deployment risk to mobile app

### For Mobile Team
- One-time implementation
- Widgets remain simple
- No need for app updates for layout changes
- Keep existing data fetching logic

### For Business
- Faster iteration
- No app store review delays
- Better user testing
- Reduced deployment risk

## Limitations

**Schema CANNOT change**:
- ❌ Data structure (use data APIs for this)
- ❌ Business logic
- ❌ API endpoints
- ❌ Add new widget types (needs app update)

**Schema CAN change**:
- ✅ Which widgets appear
- ✅ Order of widgets
- ✅ Widget configuration
- ✅ Visual styling
- ✅ Item counts
