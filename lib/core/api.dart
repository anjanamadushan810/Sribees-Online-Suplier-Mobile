import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Sribees Supply API base URL, set at build time:
///   flutter build apk --dart-define=SUPPLY_API_URL=https://devsupply.sribees.com/api
const apiBaseUrl = String.fromEnvironment(
  'SUPPLY_API_URL',
  defaultValue: 'http://10.0.2.2:8102',
);

class ApiError implements Exception {
  ApiError(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

/// Tokens live only in the platform keystore (Keychain / Android Keystore).
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
      : _s = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;

  Future<String?> access() => _s.read(key: 'access');
  Future<String?> refresh() => _s.read(key: 'refresh');
  Future<void> save(String access, String refresh) async {
    await _s.write(key: 'access', value: access);
    await _s.write(key: 'refresh', value: refresh);
  }

  Future<void> clear() async {
    await _s.delete(key: 'access');
    await _s.delete(key: 'refresh');
  }

  Future<String> language() async => await _s.read(key: 'lang') ?? 'si';
  Future<void> setLanguage(String lang) => _s.write(key: 'lang', value: lang);
}

/// Dio client: adds the bearer token, rotates it once on a 401, and calls
/// [onSignedOut] when the session is really over.
class Api {
  Api(this.tokens, {required this.onSignedOut}) {
    final options = BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    );
    _plain = Dio(options);
    dio = Dio(options);
    dio.interceptors.add(QueuedInterceptorsWrapper(
      onRequest: (o, h) async {
        final t = await tokens.access();
        if (t != null) o.headers['Authorization'] = 'Bearer $t';
        h.next(o);
      },
      onError: (e, h) async {
        if (e.response?.statusCode == 401 &&
            e.requestOptions.extra['retried'] != true &&
            await _refresh()) {
          final o = e.requestOptions..extra['retried'] = true;
          o.headers['Authorization'] = 'Bearer ${await tokens.access()}';
          try {
            return h.resolve(await dio.fetch(o));
          } on DioException catch (again) {
            return h.next(again);
          }
        }
        if (e.response?.statusCode == 401) {
          await tokens.clear();
          onSignedOut();
        }
        h.next(e);
      },
    ));
  }

  final TokenStore tokens;
  final void Function() onSignedOut;
  late final Dio dio;
  late final Dio _plain;

  Future<bool> _refresh() async {
    final r = await tokens.refresh();
    if (r == null) return false;
    try {
      final res = await _plain.post('/supplier/auth/refresh', data: {'refresh_token': r});
      await tokens.save(res.data['access_token'], res.data['refresh_token']);
      return true;
    } on DioException {
      return false;
    }
  }

  Future<dynamic> _call(Future<Response> Function() f) async {
    try {
      return (await f()).data;
    } on DioException catch (e) {
      final data = e.response?.data;
      final detail = data is Map ? data['detail'] : null;
      if (detail is String) throw ApiError(detail, status: e.response?.statusCode);
      if (detail is List && detail.isNotEmpty && detail.first is Map) {
        throw ApiError('${detail.first['msg']}', status: e.response?.statusCode);
      }
      if (e.response == null) throw ApiError('no_connection');
      throw ApiError('error', status: e.response?.statusCode);
    }
  }

  // ---- sign-in (no token yet)
  Future<void> requestCode(String phone) =>
      _call(() => _plain.post('/supplier/auth/request-code', data: {'phone': phone}));

  Future<void> verify(String phone, String code) async {
    final data = await _call(() =>
        _plain.post('/supplier/auth/verify', data: {'phone': phone, 'code': code}));
    await tokens.save(data['access_token'], data['refresh_token']);
  }

  Future<void> logout() async {
    try {
      await _call(() => dio.post('/supplier/auth/logout'));
    } catch (_) {}
    await tokens.clear();
  }

  // ---- signed in
  Future<Map<String, dynamic>> me() async => await _call(() => dio.get('/supplier/me'));
  Future<Map<String, dynamic>> catalog() async =>
      await _call(() => dio.get('/supplier/catalog'));
  Future<String> message() async =>
      (await _call(() => dio.get('/supplier/catalog/message')))['text'];
  Future<Map<String, dynamic>> preview(String text) async =>
      await _call(() => dio.post('/supplier/catalog/import/preview', data: {'text': text}));
  Future<Map<String, dynamic>> import(String text, List<Map<String, dynamic>> answers) async =>
      await _call(() => dio.post('/supplier/catalog/import',
          data: {'text': text, 'resolutions': answers}));
  Future<void> setTemplate(String header, String footer) => _call(() =>
      dio.put('/supplier/catalog/template', data: {'header': header, 'footer': footer}));
  Future<void> addSection(String title) =>
      _call(() => dio.post('/supplier/catalog/sections', data: {'title': title}));
  Future<Map<String, dynamic>> addProduct(String sectionId, String heading) async =>
      await _call(() => dio.post('/supplier/catalog/products',
          data: {'section_id': sectionId, 'heading': heading}));
  Future<void> updateProduct(String id, Map<String, dynamic> changes) =>
      _call(() => dio.patch('/supplier/catalog/products/$id', data: changes));
  Future<void> addOffer(String productId, Map<String, dynamic> body) =>
      _call(() => dio.post('/supplier/catalog/products/$productId/offers', data: body));
  Future<void> updateOffer(String id, Map<String, dynamic> changes) =>
      _call(() => dio.patch('/supplier/catalog/offers/$id', data: changes));
  Future<List<dynamic>> history(String offerId) async =>
      await _call(() => dio.get('/supplier/catalog/offers/$offerId/history'));
  Future<List<dynamic>> orders() async => await _call(() => dio.get('/supplier/orders'));
  Future<Map<String, dynamic>> order(String id) async =>
      await _call(() => dio.get('/supplier/orders/$id'));
  Future<void> answer(String id, {required bool accept, String? delivery, String? note}) =>
      _call(() => dio.post('/supplier/orders/$id/answer', data: {
            'accept': accept,
            if (delivery != null && delivery.isNotEmpty) 'delivery_charge': delivery,
            if (note != null && note.isNotEmpty) 'note': note,
          }));
}
