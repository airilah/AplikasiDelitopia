import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ui_schema_model.dart';
import 'ui_schema_service.dart';
import '../../core/services/api_client.dart';

/// Provider for UI Schema Service
final uiSchemaServiceProvider = Provider<UISchemaService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return UISchemaService(apiClient);
});

/// Provider for fetching UI Schema from API
final uiSchemaProvider = FutureProvider<UISchema>((ref) async {
  final service = ref.watch(uiSchemaServiceProvider);
  return service.getUISchema();
});
