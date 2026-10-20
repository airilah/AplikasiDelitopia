/// UI Schema models for dynamic widget rendering
class UISchema {
  final String version;
  final HomePageSchema homePage;
  final ThemeSchema? theme;
  final Map<String, dynamic>? metadata;

  UISchema({
    required this.version,
    required this.homePage,
    this.theme,
    this.metadata,
  });

  factory UISchema.fromJson(Map<String, dynamic> json) {
    return UISchema(
      version: json['version'] as String? ?? '1.0',
      homePage: HomePageSchema.fromJson(
        json['home_page'] is Map<String, dynamic>
            ? json['home_page'] as Map<String, dynamic>
            : Map<String, dynamic>.from(json['home_page'] as Map),
      ),
      theme: json['theme'] != null 
          ? ThemeSchema.fromJson(
              json['theme'] is Map<String, dynamic>
                  ? json['theme'] as Map<String, dynamic>
                  : Map<String, dynamic>.from(json['theme'] as Map),
            )
          : null,
      metadata: json['metadata'] != null
          ? (json['metadata'] is Map<String, dynamic>
              ? json['metadata'] as Map<String, dynamic>
              : Map<String, dynamic>.from(json['metadata'] as Map))
          : null);
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'home_page': homePage.toJson(),
      if (theme != null) 'theme': theme!.toJson(),
      if (metadata != null) 'metadata': metadata,
    };
  }
}

class HomePageSchema {
  final List<WidgetSchema> sections;

  HomePageSchema({required this.sections});

  factory HomePageSchema.fromJson(Map<String, dynamic> json) {
    return HomePageSchema(
      sections: (json['sections'] as List<dynamic>)
          .map((e) => WidgetSchema.fromJson(
                e is Map<String, dynamic>
                    ? e
                    : Map<String, dynamic>.from(e as Map),
              ))
          .toList());
  }

  Map<String, dynamic> toJson() {
    return {
      'sections': sections.map((e) => e.toJson()).toList(),
    };
  }
}

class WidgetSchema {
  final String type;
  final String? id;
  final bool visible;
  final int order;
  final Map<String, dynamic> properties;
  final Map<String, dynamic>? style;
  final List<WidgetSchema>? children;

  WidgetSchema({
    required this.type,
    this.id,
    this.visible = true,
    required this.order,
    required this.properties,
    this.style,
    this.children,
  });

  factory WidgetSchema.fromJson(Map<String, dynamic> json) {
    return WidgetSchema(
      type: json['type']?.toString() ?? '',
      id: json['id']?.toString(),
      visible: json['visible'] == true || json['visible']?.toString().toLowerCase() == 'true',
      order: (json['order'] as num?)?.toInt() ?? 0,
      properties: json['properties'] is Map<String, dynamic>
          ? json['properties'] as Map<String, dynamic>
          : Map<String, dynamic>.from(json['properties'] as Map),
      style: json['style'] != null
          ? (json['style'] is Map<String, dynamic>
              ? json['style'] as Map<String, dynamic>
              : Map<String, dynamic>.from(json['style'] as Map))
          : null,
      children: json['children'] != null
          ? (json['children'] as List<dynamic>)
              .map((e) => WidgetSchema.fromJson(
                    e is Map<String, dynamic>
                        ? e
                        : Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : null);
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (id != null) 'id': id,
      'visible': visible,
      'order': order,
      'properties': properties,
      if (style != null) 'style': style,
      if (children != null) 'children': children!.map((e) => e.toJson()).toList(),
    };
  }
}

class ThemeSchema {
  final String primaryColor;
  final String? secondaryColor;
  final String? accentColor;
  final Map<String, dynamic>? customColors;
  final Map<String, dynamic>? fonts;

  ThemeSchema({
    required this.primaryColor,
    this.secondaryColor,
    this.accentColor,
    this.customColors,
    this.fonts,
  });

  factory ThemeSchema.fromJson(Map<String, dynamic> json) {
    return ThemeSchema(
      primaryColor: json['primary_color'] as String? ?? '#DD2222',
      secondaryColor: json['secondary_color'] as String?,
      accentColor: json['accent_color'] as String?,
      customColors: json['custom_colors'] != null
          ? (json['custom_colors'] is Map<String, dynamic>
              ? json['custom_colors'] as Map<String, dynamic>
              : Map<String, dynamic>.from(json['custom_colors'] as Map))
          : null,
      fonts: json['fonts'] != null
          ? (json['fonts'] is Map<String, dynamic>
              ? json['fonts'] as Map<String, dynamic>
              : Map<String, dynamic>.from(json['fonts'] as Map))
          : null);
  }

  Map<String, dynamic> toJson() {
    return {
      'primary_color': primaryColor,
      if (secondaryColor != null) 'secondary_color': secondaryColor,
      if (accentColor != null) 'accent_color': accentColor,
      if (customColors != null) 'custom_colors': customColors,
      if (fonts != null) 'fonts': fonts,
    };
  }
}
