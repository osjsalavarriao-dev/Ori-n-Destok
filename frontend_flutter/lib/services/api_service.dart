import 'dart:convert';
import 'dart:io';

class ApiService {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 3);
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  Future<Map<String, dynamic>> request(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final request = await _client.openUrl(
      body == null ? 'GET' : 'POST',
      Uri.parse('$baseUrl$path'),
    );
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close().timeout(const Duration(seconds: 5));
    final text = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 5));
    if (response.statusCode >= 400) {
      throw HttpException('Operación rechazada (${response.statusCode}).');
    }
    return jsonDecode(text) as Map<String, dynamic>;
  }

  void dispose() => _client.close(force: true);
}
