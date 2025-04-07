import 'dart:io';
import 'dart:collection';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

Dio createDioClientWithNoSSL() {
  var dio = Dio();
  // Use IOHttpClientAdapter for improved compatibility
  if (dio.httpClientAdapter is IOHttpClientAdapter) {
    (dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      return client;
    };
  }
  return dio;
}

class DioHttpClientManager {
  static final DioHttpClientManager _instance = DioHttpClientManager._internal();
  static const int _maxCancelledRequests = 100;
  final Map<String, Dio> _clients = {};
  final Queue<String> _cancelledRequests = Queue();

  factory DioHttpClientManager() {
    return _instance;
  }

  DioHttpClientManager._internal();

  Dio createClient(
    String requestId, {
    bool noSSL = false,
  }) {
    // Use SSL bypass only on non-web platforms
    final dio = (noSSL && !kIsWeb) ? createDioClientWithNoSSL() : Dio();
    _clients[requestId] = dio;
    return dio;
  }

  void cancelRequest(String? requestId) {
    if (requestId != null && _clients.containsKey(requestId)) {
      try {
        _clients[requestId]?.close(force: true);
        _clients.remove(requestId);

        _cancelledRequests.addLast(requestId);
        while (_cancelledRequests.length > _maxCancelledRequests) {
          _cancelledRequests.removeFirst();
        }
      } catch (e) {
        debugPrint("Error cancelling request $requestId: $e");
      }
    }
  }

  bool wasRequestCancelled(String requestId) {
    return _cancelledRequests.contains(requestId);
  }

  void closeClient(String requestId) {
    if (_clients.containsKey(requestId)) {
      try {
        _clients[requestId]?.close(force: true);
        _clients.remove(requestId);
      } catch (e) {
        debugPrint("Error closing client $requestId: $e");
      }
    }
  }

  bool hasActiveClient(String requestId) {
    return _clients.containsKey(requestId);
  }
}
