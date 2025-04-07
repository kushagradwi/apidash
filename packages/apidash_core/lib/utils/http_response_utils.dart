import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:xml/xml.dart';
import '../consts.dart';

String? formatBody(String? body, Headers? headers) {
  if (headers != null && body != null) {
    try {
      var contentType = headers.value('content-type') ?? '';
      if (contentType.contains(kSubTypeJson)) {
        final tmp = jsonDecode(body);
        String result = kJsonEncoder.convert(tmp);
        return result;
      }
      if (contentType.contains(kSubTypeXml)) {
        final document = XmlDocument.parse(body);
        String result = document.toXmlString(pretty: true, indent: '  ');
        return result;
      }
      if (contentType.contains(kSubTypeHtml)) {
        var len = body.length;
        var lines = kSplitter.convert(body);
        var numOfLines = lines.length;
        if (numOfLines != 0 && len / numOfLines <= kCodeCharsPerLineLimit) {
          return body;
        }
      }
    } catch (e) {
      return null;
    }
  }
  return null;
}
// Unused because Dio has native support for multipart request
Future<Response> convertStreamedResponse(ResponseBody streamedResponse, String requestPath) async {
  try {
    // Accumulate bytes from the response stream manually
    List<int> byteList = [];
    await for (var chunk in streamedResponse.stream) {
      byteList.addAll(chunk);
    }
    Uint8List bodyBytes = Uint8List.fromList(byteList);

    // Convert headers from Map<String, List<String>> format
    Map<String, List<String>> formattedHeaders = {};
    streamedResponse.headers.forEach((key, value) {
      formattedHeaders[key] = List<String>.from(value);
    });

    // Construct Dio's Response object using the accumulated bytes
    Response response = Response(
      data: bodyBytes,
      statusCode: streamedResponse.statusCode,
      headers: Headers.fromMap(formattedHeaders),
      requestOptions: RequestOptions(path: requestPath),  // Using provided request path
      statusMessage: streamedResponse.statusMessage,
      extra: {'persistentConnection': streamedResponse.isRedirect},
    );

    return response;

  } catch (e) {
    throw DioError(
      requestOptions: RequestOptions(path: ''),
      error: 'Error converting streamed response: $e',
    );
  }
}
