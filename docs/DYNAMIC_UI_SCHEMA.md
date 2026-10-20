# Dynamic UI Schema System

This system allows you to update the app's UI **layout** and **configuration** through an API schema without requiring app store approval.

## Quick Start

1. **Create schema endpoint**: `GET /getData/uiSchema` returning JSON schema
2. **Update app route**: Use `DynamicHomePage` instead of `HomePage`
3. **Test**: Change schema, pull-to-refresh in app
4. **Deploy**: Update schema on server, all users see changes instantly

## What You Can Change Without App Updates

✅ Show/hide sections (`visible: true/false`)  
✅ Reorder layout (`order: 1, 2, 3...`)  
✅ Change item counts (`max_items: 4 → 6`)  
✅ Switch layouts (grid ↔ horizontal scroll)  
✅ Adjust colors (hex values)  
✅ Modify spacing (`height: 24 → 32`)  
✅ Update section titles  

## What Stays in Existing APIs

📊 **All data** still comes from your current endpoints:
- Brands → `/getData/brand`
- Products → `/getData/menuByBranch`
- Banners → `/getData/banner`
- Branches → `/getData/branchByBrand`
- Vouchers → `/getData/voucher`
- User → `/getData/user`

**You only add ONE new endpoint for layout control.**

## Important: Layout Only, Not Data

⚠️ **Key Concept**: The schema controls LAYOUT, not DATA.

- ✅ **Schema controls**: Widget order, visibility, max items, styling, spacing
- ✅ **APIs still provide data**: Brands, products, banners, vouchers, etc. come from existing APIs
- ✅ **No data duplication**: Widgets use existing providers (bannersProvider, brandsProvider, popularProductsProvider)

**Example**: 
- Schema says: "Show 4 featured brands in a grid at position 1"
- Widget fetches: Brand data from `/getData/brand` API (existing endpoint)
- Result: You can change "4" to "6" or hide the section without app update

### Data Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│                      Mobile App                         │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │         DynamicHomePage (Layout Engine)          │  │
│  └──────────────────────────────────────────────────┘  │
│           │                                             │
│           ├─► Fetch /getData/uiSchema (LAYOUT)         │
│           │   • Widget order                            │
│           │   • Visibility flags                        │
│           │   • max_items, columns                      │
│           │   • Colors, spacing                         │
│           │                                             │
│  ┌──────────────────────────────────────────────────┐  │
│  │         DynamicWidgetBuilder                     │  │
│  │  Renders widgets based on schema                │  │
│  └──────────────────────────────────────────────────┘  │
│           │                                             │
│           ├─► FeaturedBrands Widget                    │
│           │   ├─► Fetch /getData/brand (DATA)          │
│           │   └─► Take first 4 items (from schema)     │
│           │                                             │
│           ├─► PopularItems Widget                      │
│           │   ├─► Fetch /getData/menuByBranch (DATA)   │
│           │   └─► Show in 2 columns (from schema)      │
│           │                                             │
│           └─► BannerCarousel Widget                    │
│               ├─► Fetch /getData/banner (DATA)         │
│               └─► Height 240px (from schema)           │
│                                                         │
└─────────────────────────────────────────────────────────┘

Schema Changes (NO app update needed):
  • Change max_items: 4 → 6
  • Hide section: visible: false
  • Reorder: order: 1 → 5
  • Change columns: 2 → 3

Data Changes (NO schema update needed):
  • Add new brands to /getData/brand
  • Update banner images
  • Change product prices
  • Modify branch locations
```

## Overview

The app fetches a UI schema from the API endpoint `/getData/uiSchema` which defines:
- What widgets to display
- In what order they appear
- Their properties (max items, layout type, etc.)
- Styling options (colors, spacing)
- Visibility toggles

**Data still comes from existing APIs:**
- Banners: `/getData/banner`
- Brands: `/getData/brand`
- Products: `/getData/menuByBranch`
- Branches: `/getData/branchByBrand`
- Vouchers: `/getData/voucher`
- User: `/getData/user`

## API Endpoint

**Endpoint:** `GET /getData/uiSchema`

**Response Format:**
```json
{
  "status": "success",
  "data": {
    "version": "1.0",
    "home_page": { ... },
    "theme": { ... }
  }
}
```

## Available Widget Types

### 1. section_header
Displays a section title with optional "See All" button.

**Properties:**
- `title` (string): Section title text
- `icon` (string, optional): Icon name (location_on, star, restaurant)
- `show_see_all` (boolean): Show "See All" button

**Example:**
```json
{
  "type": "section_header",
  "order": 0,
  "visible": true,
  "properties": {
    "title": "Featured Brands",
    "icon": "restaurant",
    "show_see_all": true
  }
}
```

### 2. featured_brands
Displays brand cards in grid or horizontal list.

**Data Source**: `/getData/brand` API (existing endpoint)

**Properties:**
- `max_items` (number): Maximum brands to show (from API response)
- `show_as_grid` (boolean): Grid layout (true) or horizontal scroll (false)

**Example:**
```json
{
  "type": "featured_brands",
  "order": 1,
  "visible": true,
  "properties": {
    "max_items": 4,
    "show_as_grid": true
  }
}
```

### 3. points_card
Displays user's points balance.

**Data Source**: `/getData/user` API (existing endpoint)

**Properties:**
- `title` (string): Card title

**Style:**
- `background_color` (hex string): Card background color

**Example:**
```json
{
  "type": "points_card",
  "order": 0,
  "visible": true,
  "properties": {
    "title": "My Points"
  },
  "style": {
    "background_color": "#DD2222"
  }
}
```

### 4. vouchers_card
Displays available vouchers count.

**Data Source**: `/getData/voucher` API (existing endpoint)

**Properties:**
- `title` (string): Card title

**Example:**
```json
{
  "type": "vouchers_card",
  "order": 1,
  "visible": true,
  "properties": {
    "title": "Vouchers"
  }
}
```

### 5. banner_carousel
Image carousel for promotional banners.

**Data Source**: `/getData/banner` API (existing endpoint)

**Properties:**
- `height` (number): Carousel height in pixels
- `auto_play` (boolean): Enable auto-play

**Example:**
```json
{
  "type": "banner_carousel",
  "order": 5,
  "visible": true,
  "properties": {
    "height": 240,
    "auto_play": true
  }
}
```

### 6. nearest_location
Shows nearest branch locations for each brand.

**Data Source**: `/getData/brand` + `/getData/branchByBrand` APIs (existing endpoints)

**Properties:**
- `max_items` (number): Maximum brands to show

**Example:**
```json
{
  "type": "nearest_location",
  "order": 9,
  "visible": true,
  "properties": {
    "max_items": 4
  }
}
```

### 7. popular_items
Grid of popular menu items.

**Data Source**: `/getData/menuByBranch` API (existing endpoint with popularity filter)

**Properties:**
- `max_items` (number): Maximum items to show
- `columns` (number): Number of grid columns

**Example:**
```json
{
  "type": "popular_items",
  "order": 13,
  "visible": true,
  "properties": {
    "max_items": 6,
    "columns": 2
  }
}
```

### 8. spacer
Empty space for layout spacing.

**Properties:**
- `height` (number): Space height in pixels

**Example:**
```json
{
  "type": "spacer",
  "order": 2,
  "visible": true,
  "properties": {
    "height": 24
  }
}
```

### 9. container
Groups multiple widgets together.

**Properties:**
- (none required)

**Style:**
- `padding` (number): Container padding in pixels

**Children:**
- Array of widget schemas

**Example:**
```json
{
  "type": "container",
  "order": 3,
  "visible": true,
  "properties": {},
  "style": {
    "padding": 20
  },
  "children": [
    {
      "type": "points_card",
      "order": 0,
      "visible": true,
      "properties": {
        "title": "My Points"
      }
    }
  ]
}
```

## Common Properties

All widgets support these properties:

- `type` (string, required): Widget type identifier
- `id` (string, optional): Unique identifier for the widget
- `order` (number, required): Display order (0-based, lower numbers appear first)
- `visible` (boolean): Show/hide widget (default: true)
- `properties` (object, required): Widget-specific properties
- `style` (object, optional): Widget styling options
- `children` (array, optional): Child widgets (for container type)

## Theme Configuration

The schema can also define app theming:

```json
{
  "theme": {
    "primary_color": "#DD2222",
    "secondary_color": "#2E7D32",
    "accent_color": "#FF6B35",
    "custom_colors": {
      "background": "#F5F5F5",
      "card": "#FFFFFF",
      "text_primary": "#212121",
      "text_secondary": "#757575"
    },
    "fonts": {
      "primary": "Poppins",
      "secondary": "Roboto"
    }
  }
}
```

## Usage Examples

### Hide a Section
Set `visible: false` to hide any widget:
```json
{
  "type": "popular_items",
  "order": 13,
  "visible": false,
  "properties": { ... }
}
```

### Reorder Sections
Change the `order` values to rearrange:
```json
// Move popular items before nearest location
{
  "type": "popular_items",
  "order": 7,  // Changed from 13
  ...
},
{
  "type": "nearest_location",
  "order": 11,  // Changed from 9
  ...
}
```

### Change Brand Display
Switch from grid to horizontal scroll:
```json
{
  "type": "featured_brands",
  "properties": {
    "max_items": 6,
    "show_as_grid": false  // Changed from true
  }
}
```

### Add More Items
Increase max_items to show more content:
```json
{
  "type": "popular_items",
  "properties": {
    "max_items": 12,  // Changed from 6
    "columns": 3      // Changed from 2
  }
}
```

## Fallback Behavior

If the API fails or returns invalid data:
- The app uses a built-in default schema
- All sections remain functional
- No app crashes or broken UI

## Testing

1. Update the schema on your backend
2. Pull to refresh the home page in the app
3. Changes appear immediately without app update

## Best Practices

1. **Always increment version**: Update `version` when changing schema
2. **Test visibility toggles**: Use `visible: false` before removing sections
3. **Gradual changes**: Make small incremental changes rather than complete redesigns
4. **Monitor order values**: Keep order values sequential for clarity
5. **Use IDs**: Add `id` to sections for easier debugging

## Server Implementation

Your backend needs to implement **only the schema endpoint**:

```php
// Example PHP endpoint for LAYOUT SCHEMA only
Route::get('/getData/uiSchema', function() {
    return response()->json([
        'status' => 'success',
        'data' => json_decode(file_get_contents('schema/ui_schema.json'))
    ]);
});
```

**All existing data endpoints remain unchanged:**
- `/getData/brand` - Brands data
- `/getData/banner` - Banners data
- `/getData/menuByBranch` - Products/menu data
- `/getData/branchByBrand` - Branches data
- `/getData/voucher` - Vouchers data
- `/getData/user` - User data

The schema just tells the app how to arrange and display this data.

Store the schema in a JSON file or database for easy updates.
