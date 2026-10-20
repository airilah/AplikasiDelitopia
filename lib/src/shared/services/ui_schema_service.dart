import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/ui_schema_model.dart';
import '../../core/services/api_client.dart';

class UISchemaService {
  final ApiClient _apiClient;

  UISchemaService(this._apiClient);

  /// Get UI schema from local asset file (for development) or server
  /// Note: This only controls LAYOUT - widgets still fetch their own data from existing APIs
  Future<UISchema> getUISchema() async {
    try {
      UISchema schema;
      // Try to load from local asset file first (for development/testing)
      try {
        final jsonString = await rootBundle.loadString('assets/schema/ui_schema_example.json');
        final jsonData = json.decode(jsonString) as Map<String, dynamic>;
        debugPrint('Loaded UI schema from local asset file');
        schema = UISchema.fromJson(jsonData);
        _ensureBannerSection(schema);
        return schema;
      } catch (assetError) {
        debugPrint('Could not load from asset file: $assetError');
      }

      // If asset fails, try API
      final response = await _apiClient.get('/getData/uiSchema');
      
      if (response['status'] == 'success') {
        // Ensure data is properly cast to Map<String, dynamic>
        final data = response['data'];
        final schemaData = data is Map<String, dynamic> 
            ? data 
            : Map<String, dynamic>.from(data as Map);
        
        debugPrint('Loaded UI schema from API');
        schema = UISchema.fromJson(schemaData);
        _ensureBannerSection(schema);
        return schema;
      }
      
      // Return default schema if both fail
      debugPrint('Using default hardcoded schema');
      schema = _getDefaultSchema();
      _ensureBannerSection(schema);
      return schema;
    } catch (e) {
      debugPrint('Error loading UI schema: $e');
      final schema = _getDefaultSchema();
      _ensureBannerSection(schema);
      return schema;
    }
  }

  void _ensureBannerSection(UISchema schema) {
    final sections = schema.homePage.sections;
    final bannerIndex = sections.indexWhere((s) => s.type == 'banner_carousel');
    if (bannerIndex != -1) {
      final oldBanner = sections[bannerIndex];
      sections[bannerIndex] = WidgetSchema(
        type: 'banner_carousel',
        id: oldBanner.id,
        order: oldBanner.order,
        visible: true,
        properties: oldBanner.properties,
        style: oldBanner.style,
        children: oldBanner.children);
    } else {
      sections.add(WidgetSchema(
        type: 'banner_carousel',
        id: 'main_banner',
        order: 4,
        visible: true,
        properties: {'height': 180, 'auto_play': true},
      ));
      sections.sort((a, b) => a.order.compareTo(b.order));
    }
  }

  /// Default schema as fallback
  UISchema _getDefaultSchema() {
    return UISchema.fromJson({
      'version': '1.0',
      'home_page': {
        'sections': [
          {
            'type': 'section_header',
            'order': 0,
            'visible': true,
            'properties': {
              'title': 'Brand Favorit',
              'icon': 'star',
              'show_see_all': true,
            },
          },
          {
            'type': 'spacer',
            'order': 1,
            'visible': true,
            'properties': {'height': 4},
          },
          {
            'type': 'featured_brands',
            'order': 2,
            'visible': true,
            'properties': {
              'max_items': 8,
              'show_as_grid': false,
              'visible_items': 4,
            },
          },
          {
            'type': 'spacer',
            'order': 3,
            'visible': true,
            'properties': {'height': 10},
          },
          {
            'type': 'banner_carousel',
            'order': 4,
            'visible': true,
            'properties': {
              'height': 180,
              'auto_play': true,
            },
          },
          {
            'type': 'spacer',
            'order': 5,
            'visible': true,
            'properties': {'height': 0},
          },
          {
            'type': 'container',
            'order': 6,
            'visible': true,
            'properties': {},
            'style': {'padding': 0},
            'children': [
              {
                'type': 'points_vouchers_row',
                'order': 0,
                'visible': true,
                'properties': {},
              },
            ],
          },
          {
            'type': 'spacer',
            'order': 7,
            'visible': true,
            'properties': {'height': 0},
          },
          {
            'type': 'section_header',
            'order': 8,
            'visible': true,
            'properties': {
              'title': 'Lokasi Terdekat',
              'icon': 'location_on',
              'show_see_all': true,
            },
          },
          {
            'type': 'spacer',
            'order': 9,
            'visible': true,
            'properties': {'height': 6},
          },
          {
            'type': 'nearest_location',
            'order': 10,
            'visible': true,
            'properties': {
              'max_items': 3,
            },
          },
          {
            'type': 'spacer',
            'order': 11,
            'visible': true,
            'properties': {'height': 8},
          },
          {
            'type': 'section_header',
            'order': 12,
            'visible': true,
            'properties': {
              'title': 'Menu Populer',
              'show_see_all': true,
              'icon': 'local_fire_department',
            },
          },
          {
            'type': 'spacer',
            'order': 13,
            'visible': true,
            'properties': {'height': 4},
          },
          {
            'type': 'popular_items',
            'order': 14,
            'visible': true,
            'properties': {
              'max_items': 4,
              'columns': 2,
            },
          },
          {
            'type': 'spacer',
            'order': 15,
            'visible': true,
            'properties': {'height': 20},
          },
          {
            'type': 'section_header',
            'order': 16,
            'visible': true,
            'properties': {
              'title': 'Voucher Aktif',
              'icon': 'card_giftcard',
              'show_see_all': true,
            },
          },
          {
            'type': 'spacer',
            'order': 17,
            'visible': true,
            'properties': {'height': 6},
          },
          {
            'type': 'vouchers_list',
            'order': 18,
            'visible': true,
            'properties': {
              'max_items': 3,
            },
          },
          {
            'type': 'spacer',
            'order': 19,
            'visible': true,
            'properties': {'height': 110},
          },
        ],
      },
    });
  }
}
