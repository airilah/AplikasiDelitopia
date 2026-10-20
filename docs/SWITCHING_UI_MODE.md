# Switching Between Static and Dynamic Home Pages

## Overview

The app now supports two home page implementations:

1. **Static Home Page** (`home_page.dart`): Hard-coded widgets, requires app update to change
2. **Dynamic Home Page** (`dynamic_home_page.dart`): Schema-driven, updates via API without app store approval

## Quick Switch Guide

### Option 1: Update Routes

Edit `/lib/src/core/routes/app_router.dart`:

```dart
// For Static Home Page
import '../../features/home/views/home_page.dart';

// For Dynamic Home Page
import '../../features/home/views/dynamic_home_page.dart';

// In routes configuration
GoRoute(
  path: '/home',
  builder: (context, state) => const DynamicHomePage(), // or HomePage()
),
```

### Option 2: Environment Variable

Create a configuration to toggle between modes:

```dart
// lib/src/core/config/app_config.dart
class AppConfig {
  static const bool useDynamicUI = true; // Set to false for static UI
}

// In your router
builder: (context, state) => AppConfig.useDynamicUI 
    ? const DynamicHomePage() 
    : const HomePage(),
```

### Option 3: Feature Flag

Fetch from API to enable/disable dynamically:

```dart
// Add to your API
GET /getData/appConfig
{
  "use_dynamic_ui": true
}

// In your app
final config = await apiClient.get('/getData/appConfig');
final useDynamic = config['use_dynamic_ui'] ?? false;
```

## Benefits of Dynamic UI

✅ **No App Store Approval Required**
- Change layout order instantly
- Hide/show sections remotely
- Update colors and styling
- Adjust item counts

✅ **A/B Testing**
- Test different layouts
- Measure user engagement
- Roll back changes instantly

✅ **Seasonal Updates**
- Holiday themes
- Special promotions
- Event-specific layouts

✅ **Emergency Fixes**
- Hide broken sections
- Disable problematic features
- Quick hotfixes

## Static UI Benefits

✅ **Performance**
- Faster initial load
- No schema parsing
- Direct widget rendering

✅ **Reliability**
- No API dependency
- Works offline
- Guaranteed layout

✅ **Development Speed**
- Easier debugging
- Faster iteration
- IDE support

## Hybrid Approach (Recommended)

Use both with a fallback mechanism:

```dart
class SmartHomePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemaAsync = ref.watch(uiSchemaProvider);
    
    return schemaAsync.when(
      data: (schema) => DynamicHomePage(schema: schema),
      loading: () => const HomePage(), // Show static while loading
      error: (_, __) => const HomePage(), // Fallback to static on error
    );
  }
}
```

This gives you:
- Dynamic updates when API works
- Instant load with static UI
- Graceful degradation on failures

## Schema Update Workflow

### For Backend Team

1. Edit `ui_schema.json` on server
2. Deploy to staging
3. Test with staging app
4. Deploy to production
5. Users see changes on next app refresh

### For App Team

1. Keep static home page updated as baseline
2. Add new widget types to `DynamicWidgetBuilder`
3. Update schema documentation
4. Deploy app update
5. Backend can then use new widgets

## Migration Strategy

### Phase 1: Parallel Run
- Keep both home pages
- Test dynamic in beta builds
- Collect feedback

### Phase 2: Gradual Rollout
- Use feature flag
- Enable for 10% of users
- Monitor analytics
- Increase to 50%, then 100%

### Phase 3: Full Dynamic
- Remove static home page (optional)
- Keep as fallback (recommended)

## API Endpoint Setup

Your backend needs to implement:

```
GET https://delitopia.softindopp.com/api/getData/uiSchema

Response:
{
  "status": "success",
  "data": {
    "version": "1.0",
    "home_page": { ... },
    "theme": { ... }
  }
}
```

Place the example schema from `assets/schema/ui_schema_example.json` on your server.

## Caching Strategy

Add caching to improve performance:

```dart
// In ui_schema_service.dart
final _cachedSchema = StateProvider<UISchema?>((ref) => null);

Future<UISchema> getUISchema() async {
  final cached = ref.read(_cachedSchema);
  if (cached != null) return cached;
  
  final schema = await _apiClient.get('/getData/uiSchema');
  ref.read(_cachedSchema.notifier).state = schema;
  return schema;
}
```

## Versioning

Track schema version for debugging:

```dart
final schemaVersion = schema.version;
print('Using UI Schema v$schemaVersion');

// In analytics
analytics.logEvent('schema_loaded', {
  'version': schemaVersion,
  'sections_count': schema.homePage.sections.length,
});
```

## Common Issues

**Q: Dynamic page shows loading forever**
- Check API endpoint is accessible
- Verify JSON format matches schema
- Check network connectivity

**Q: Widgets not appearing**
- Verify `visible: true` in schema
- Check widget order values
- Ensure widget type is implemented

**Q: Can't see changes after updating schema**
- Pull to refresh on home page
- Clear app cache
- Check schema version number

## Next Steps

1. Implement `/getData/uiSchema` endpoint on your backend
2. Test with example schema
3. Gradually customize the schema
4. Add new widget types as needed
5. Monitor user behavior and iterate
