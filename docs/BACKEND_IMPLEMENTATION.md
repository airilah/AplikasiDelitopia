# Backend Implementation Guide

## What You Need to Do

You only need to add **ONE new endpoint** to your existing Laravel/PHP backend.

## Step 1: Create the Schema Endpoint

Add this route to your backend:

```php
// routes/api.php or your routes file
Route::get('/getData/uiSchema', [UISchemaController::class, 'getSchema']);
```

## Step 2: Create the Controller

```php
// app/Http/Controllers/UISchemaController.php
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class UISchemaController extends Controller
{
    public function getSchema()
    {
        // Option 1: Read from JSON file
        $schemaPath = storage_path('app/schema/ui_schema.json');
        $schema = json_decode(file_get_contents($schemaPath), true);
        
        return response()->json([
            'status' => 'success',
            'data' => $schema
        ]);
        
        // Option 2: Read from database
        // $schema = DB::table('ui_schemas')
        //     ->where('version', 'latest')
        //     ->first();
        // 
        // return response()->json([
        //     'status' => 'success',
        //     'data' => json_decode($schema->content, true)
        // ]);
    }
}
```

## Step 3: Create the Schema File

Copy the example schema to your backend:

**File**: `storage/app/schema/ui_schema.json`

```json
{
  "version": "1.0",
  "home_page": {
    "sections": [
      {
        "type": "section_header",
        "order": 0,
        "visible": true,
        "properties": {
          "title": "Featured Brands",
          "show_see_all": true
        }
      },
      {
        "type": "featured_brands",
        "order": 1,
        "visible": true,
        "properties": {
          "max_items": 4,
          "show_as_grid": true
        }
      },
      {
        "type": "spacer",
        "order": 2,
        "visible": true,
        "properties": {"height": 32}
      },
      {
        "type": "container",
        "order": 3,
        "visible": true,
        "properties": {},
        "style": {"padding": 20},
        "children": [
          {
            "type": "points_card",
            "order": 0,
            "visible": true,
            "properties": {"title": "My Points"},
            "style": {"background_color": "#DD2222"}
          }
        ]
      },
      {
        "type": "spacer",
        "order": 4,
        "visible": true,
        "properties": {"height": 24}
      },
      {
        "type": "banner_carousel",
        "order": 5,
        "visible": true,
        "properties": {
          "height": 240,
          "auto_play": true
        }
      },
      {
        "type": "spacer",
        "order": 6,
        "visible": true,
        "properties": {"height": 32}
      },
      {
        "type": "section_header",
        "order": 7,
        "visible": true,
        "properties": {
          "title": "Nearest Location",
          "icon": "location_on",
          "show_see_all": true
        }
      },
      {
        "type": "spacer",
        "order": 8,
        "visible": true,
        "properties": {"height": 16}
      },
      {
        "type": "nearest_location",
        "order": 9,
        "visible": true,
        "properties": {"max_items": 4}
      },
      {
        "type": "spacer",
        "order": 10,
        "visible": true,
        "properties": {"height": 32}
      },
      {
        "type": "section_header",
        "order": 11,
        "visible": true,
        "properties": {
          "title": "Popular Items",
          "show_see_all": true
        }
      },
      {
        "type": "spacer",
        "order": 12,
        "visible": true,
        "properties": {"height": 16}
      },
      {
        "type": "popular_items",
        "order": 13,
        "visible": true,
        "properties": {
          "max_items": 6,
          "columns": 2
        }
      }
    ]
  }
}
```

## Step 4: Test the Endpoint

```bash
# Test with curl
curl https://delitopia.softindopp.com/api/getData/uiSchema

# Expected response:
{
  "status": "success",
  "data": {
    "version": "1.0",
    "home_page": {
      "sections": [...]
    }
  }
}
```

## That's It!

✅ **No changes to existing endpoints**:
- `/getData/brand` - unchanged
- `/getData/menuByBranch` - unchanged
- `/getData/banner` - unchanged
- `/getData/branchByBrand` - unchanged
- `/getData/voucher` - unchanged
- `/getData/user` - unchanged

✅ **Just add ONE new endpoint**:
- `/getData/uiSchema` - returns layout configuration

## How to Make Changes Later

### Example 1: Show 6 Brands Instead of 4

Edit `storage/app/schema/ui_schema.json`:

```json
{
  "type": "featured_brands",
  "properties": {
    "max_items": 6  // Changed from 4
  }
}
```

Save the file. All users see the change on next app refresh.

### Example 2: Hide Popular Items Section

```json
{
  "type": "popular_items",
  "visible": false  // Changed from true
}
```

### Example 3: Reorder Sections

Just swap the `order` values:

```json
// Move banner carousel to top
{
  "type": "banner_carousel",
  "order": 1  // Was 5
}

// Move featured brands down
{
  "type": "featured_brands", 
  "order": 5  // Was 1
}
```

## Optional: Database Storage

If you want to manage schemas in database:

```sql
CREATE TABLE ui_schemas (
    id INT PRIMARY KEY AUTO_INCREMENT,
    version VARCHAR(10) NOT NULL,
    content JSON NOT NULL,
    is_active BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

INSERT INTO ui_schemas (version, content, is_active)
VALUES ('1.0', '<paste JSON here>', TRUE);
```

Then update controller:

```php
public function getSchema()
{
    $schema = DB::table('ui_schemas')
        ->where('is_active', true)
        ->first();
    
    if (!$schema) {
        return response()->json([
            'status' => 'error',
            'message' => 'No active schema found'
        ], 404);
    }
    
    return response()->json([
        'status' => 'success',
        'data' => json_decode($schema->content, true)
    ]);
}
```

## Optional: Admin Panel

Create an admin page to edit the schema:

```php
// routes/web.php
Route::get('/admin/ui-schema', [UISchemaController::class, 'edit']);
Route::post('/admin/ui-schema', [UISchemaController::class, 'update']);
```

```php
public function update(Request $request)
{
    $schema = $request->input('schema');
    
    // Validate JSON
    $decoded = json_decode($schema, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        return back()->with('error', 'Invalid JSON');
    }
    
    // Save to file
    Storage::put('schema/ui_schema.json', $schema);
    
    // Or save to database
    // DB::table('ui_schemas')->insert([
    //     'version' => $decoded['version'],
    //     'content' => $schema,
    //     'is_active' => true
    // ]);
    
    return back()->with('success', 'Schema updated');
}
```

## Security Considerations

1. **Cache the schema** to reduce file I/O:

```php
use Illuminate\Support\Facades\Cache;

public function getSchema()
{
    $schema = Cache::remember('ui_schema', 3600, function () {
        return json_decode(
            file_get_contents(storage_path('app/schema/ui_schema.json')), 
            true
        );
    });
    
    return response()->json([
        'status' => 'success',
        'data' => $schema
    ]);
}
```

2. **Validate schema format**:

```php
private function validateSchema($schema)
{
    if (!isset($schema['version'])) return false;
    if (!isset($schema['home_page']['sections'])) return false;
    
    foreach ($schema['home_page']['sections'] as $section) {
        if (!isset($section['type'])) return false;
        if (!isset($section['order'])) return false;
    }
    
    return true;
}
```

3. **Version control**: Keep schema versions in git

4. **Backup**: Always backup before updating schema

## Deployment Checklist

- [ ] Create `UISchemaController.php`
- [ ] Add route to `routes/api.php`
- [ ] Create `storage/app/schema/ui_schema.json`
- [ ] Test endpoint with curl/Postman
- [ ] Verify JSON format is valid
- [ ] Enable caching for production
- [ ] Add to version control
- [ ] Document changes for team

## Troubleshooting

**Error: File not found**
```php
// Check path
dd(storage_path('app/schema/ui_schema.json'));

// Ensure directory exists
mkdir -p storage/app/schema
```

**Error: Invalid JSON**
```bash
# Validate JSON file
cat storage/app/schema/ui_schema.json | jq .
```

**Error: Permission denied**
```bash
# Fix permissions
chmod 644 storage/app/schema/ui_schema.json
chown www-data:www-data storage/app/schema/ui_schema.json
```

## Need Help?

Check these files in the Flutter project:
- `DYNAMIC_UI_SCHEMA.md` - Complete schema documentation
- `LAYOUT_VS_DATA.md` - Understanding layout vs data
- `assets/schema/ui_schema_example.json` - Full example schema
