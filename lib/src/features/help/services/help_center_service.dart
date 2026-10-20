import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_constants.dart';
import '../models/help_center_model.dart';

class HelpCenterService {
  final String baseUrl = ApiConstants.baseUrl;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<String?> _getAuthToken() async {
    try {
      final secureToken =
          await _secureStorage.read(key: AppConstants.keyAuthToken);
      if (secureToken != null && secureToken.isNotEmpty) {
        return secureToken;
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(AppConstants.keyAuthToken) ??
          prefs.getString('auth_token');
    } catch (_) {}

    return null;
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getAuthToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// 1. Fetch Help Center Overview (Support contacts, categories, and popular FAQs)
  Future<Map<String, dynamic>> fetchHelpOverview() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/v2/help/overview');
      final response = await http.get(url, headers: headers).timeout(
            const Duration(seconds: 8),
          );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] as Map<String, dynamic>? ?? {};

        final settingsJson = data['support_settings'];
        final settings = settingsJson is Map<String, dynamic>
            ? HelpSupportSettings.fromJson(settingsJson)
            : HelpSupportSettings.defaultSettings;

        final rawCategories = data['categories'] as List? ?? [];
        final categories = rawCategories
            .whereType<Map<String, dynamic>>()
            .map((c) => HelpFaqCategory.fromJson(c))
            .toList();

        final rawPopular = data['popular_faqs'] as List? ?? [];
        final popularFaqs = rawPopular
            .whereType<Map<String, dynamic>>()
            .map((f) => HelpFaqItem.fromJson(f))
            .toList();

        return {
          'settings': settings,
          'categories': categories,
          'popular_faqs': popularFaqs,
        };
      }
    } catch (e) {
      debugPrint('⚠️ [HelpCenterService] fetchHelpOverview error: $e');
    }

    return {
      'settings': HelpSupportSettings.defaultSettings,
      'categories': <HelpFaqCategory>[],
      'popular_faqs': <HelpFaqItem>[],
    };
  }

  /// 2. Fetch FAQs with optional category or search query
  Future<List<HelpFaqItem>> fetchFaqs({int? categoryId, String? search}) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{};
      if (categoryId != null && categoryId > 0) {
        queryParams['category_id'] = categoryId.toString();
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final uri = Uri.parse('$baseUrl/v2/help/faqs').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: headers).timeout(
            const Duration(seconds: 8),
          );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = (body['data'] as List? ?? []);
        return list
            .whereType<Map<String, dynamic>>()
            .map((item) => HelpFaqItem.fromJson(item))
            .toList();
      }
    } catch (e) {
      debugPrint('⚠️ [HelpCenterService] fetchFaqs error: $e');
    }
    return [];
  }

  /// 3. Submit feedback (Helpful or Unhelpful)
  Future<bool> sendFeedback(int faqId, bool isHelpful) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/v2/help/faqs/$faqId/feedback');
      final response = await http
          .post(
            url,
            headers: headers,
            body: jsonEncode({'is_helpful': isHelpful}),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('⚠️ [HelpCenterService] sendFeedback error: $e');
      return false;
    }
  }

  /// 4. Generate order WhatsApp URL with pre-filled context (Zero image upload required!)
  Future<String?> generateOrderWhatsAppUrl({
    String? orderId,
    required String issueType,
    String? issueNotes,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/v2/help/order-whatsapp');
      final response = await http
          .post(
            url,
            headers: headers,
            body: jsonEncode({
              'order_id': orderId,
              'issue_type': issueType,
              'issue_notes': issueNotes,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data']?['whatsapp_url']?.toString();
      }
    } catch (e) {
      debugPrint('⚠️ [HelpCenterService] generateOrderWhatsAppUrl error: $e');
    }
    return null;
  }
}
