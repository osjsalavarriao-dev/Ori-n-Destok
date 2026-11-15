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
    Duration timeout = const Duration(seconds: 5),
  ]) async {
    final request = await _client.openUrl(
      body == null ? 'GET' : 'POST',
      Uri.parse('$baseUrl$path'),
    );
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode(body)));
    }
    return _read(request, timeout);
  }

  /// POST de un cuerpo binario (por ejemplo un WAV).
  Future<Map<String, dynamic>> postBytes(
    String path,
    List<int> bytes, {
    String contentType = 'audio/wav',
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final request = await _client.postUrl(Uri.parse('$baseUrl$path'));
    request.headers.contentType = ContentType.parse(contentType);
    request.contentLength = bytes.length;
    request.add(bytes);
    return _read(request, timeout);
  }

  /// POST JSON que responde con un cuerpo binario (por ejemplo audio WAV).
  Future<List<int>> postForBytes(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final request = await _client.postUrl(Uri.parse('$baseUrl$path'));
    request.headers.contentType = ContentType.json;
    request.add(utf8.encode(jsonEncode(body)));
    final response = await request.close().timeout(timeout);
    final bytes = await response
        .fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk))
        .timeout(timeout);
    if (response.statusCode >= 400) {
      throw HttpException('Operación rechazada (${response.statusCode}).');
    }
    return bytes;
  }

  Future<Map<String, dynamic>> _read(
    HttpClientRequest request,
    Duration timeout,
  ) async {
    final response = await request.close().timeout(timeout);
    final text = await utf8.decoder.bind(response).join().timeout(timeout);
    if (response.statusCode >= 400) {
      throw HttpException('Operación rechazada (${response.statusCode}).');
    }
    return jsonDecode(text) as Map<String, dynamic>;
  }

  void dispose() => _client.close(force: true);
}
