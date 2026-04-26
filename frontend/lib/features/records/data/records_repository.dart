import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'record_models.dart';

final recordsRepositoryProvider = Provider<RecordsRepository>((ref) {
  return RecordsRepository(ref.watch(dioProvider));
});

class RecordsRepository {
  RecordsRepository(this._dio);

  final Dio _dio;

  Future<List<CookingRecord>> recent({int limit = 10}) async {
    final response = await _dio.get<List<dynamic>>('/records/recent', queryParameters: {'limit': limit});
    return _recordsFromResponse(response.data);
  }

  Future<List<CookingRecord>> today() async {
    final response = await _dio.get<List<dynamic>>('/records/today');
    return _recordsFromResponse(response.data);
  }

  Future<List<CookingRecord>> byDate(DateTime date) async {
    final response = await _dio.get<List<dynamic>>(
      '/records/by-date',
      queryParameters: {'date': _dateString(date)},
    );
    return _recordsFromResponse(response.data);
  }

  Future<List<CalendarRecordDay>> calendarDays(DateTime month) async {
    final response = await _dio.get<List<dynamic>>(
      '/records/calendar',
      queryParameters: {'month': '${month.year}-${month.month.toString().padLeft(2, '0')}'},
    );
    return (response.data ?? [])
        .map((item) => CalendarRecordDay.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<CookingRecord>> search({
    required String query,
    String filter = 'all',
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/records/search',
      queryParameters: {'q': query, 'filter': filter},
    );
    return _recordsFromResponse(response.data);
  }

  Future<CookingRecord> read(int id) async {
    final response = await _dio.get<Map<String, dynamic>>('/records/$id');
    return CookingRecord.fromJson(response.data!);
  }

  Future<CookingRecord> create(RecordDraft draft) async {
    final response = await _dio.post<Map<String, dynamic>>('/records', data: draft.toJson());
    return CookingRecord.fromJson(response.data!);
  }

  Future<CookingRecord> update(int id, RecordDraft draft) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/records/$id',
      data: draft.toJson(includeAttachments: draft.attachments.isNotEmpty),
    );
    return CookingRecord.fromJson(response.data!);
  }

  Future<void> delete(int id) async {
    await _dio.delete<void>('/records/$id');
  }

  Future<CookingRecord> clone(int id, DateTime cookedDate) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/records/$id/clone',
      data: {'cooked_date': _dateString(cookedDate)},
    );
    return CookingRecord.fromJson(response.data!);
  }

  Future<RecordAttachment> addLink({
    required int recordId,
    required String url,
    String? title,
    String? description,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/records/$recordId/attachments/links',
      data: {'url': url, 'title': title, 'description': description},
    );
    return RecordAttachment.fromJson(response.data!);
  }

  Future<AttachmentPreview> previewLink(String url) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/records/attachments/preview',
      queryParameters: {'url': url},
    );
    return AttachmentPreview.fromJson(response.data!);
  }

  Future<RecordAttachment> uploadImage({
    required int recordId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/records/$recordId/attachments/images',
      data: formData,
    );
    return RecordAttachment.fromJson(response.data!);
  }

  Future<void> deleteAttachment({
    required int recordId,
    required int attachmentId,
  }) async {
    await _dio.delete<void>('/records/$recordId/attachments/$attachmentId');
  }

  static List<CookingRecord> _recordsFromResponse(List<dynamic>? data) {
    return (data ?? [])
        .map((item) => CookingRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static String _dateString(DateTime date) => date.toIso8601String().split('T').first;
}
