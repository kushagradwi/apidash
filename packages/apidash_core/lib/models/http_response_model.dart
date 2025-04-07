import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../extensions/extensions.dart';
import '../utils/utils.dart';
import '../consts.dart';

part 'http_response_model.freezed.dart';
part 'http_response_model.g.dart';

class Uint8ListConverter implements JsonConverter<Uint8List?, List<int>?> {
  const Uint8ListConverter();

  @override
  Uint8List? fromJson(List<int>? json) {
    return json == null ? null : Uint8List.fromList(json);
  }

  @override
  List<int>? toJson(Uint8List? object) {
    return object?.toList();
  }
}

class DurationConverter implements JsonConverter<Duration?, int?> {
  const DurationConverter();

  @override
  Duration? fromJson(int? json) {
    return json == null ? null : Duration(microseconds: json);
  }

  @override
  int? toJson(Duration? object) {
    return object?.inMicroseconds;
  }
}

@freezed
class HttpResponseModel with _$HttpResponseModel {
  const HttpResponseModel._();

  @JsonSerializable(
    explicitToJson: true,
    anyMap: true,
  )
  const factory HttpResponseModel({
    int? statusCode,
    Map<String, String>? headers,
    Map<String, String>? requestHeaders,
    String? body,
    String? formattedBody,
    @Uint8ListConverter() Uint8List? bodyBytes,
    @DurationConverter() Duration? time,
  }) = _HttpResponseModel;

  factory HttpResponseModel.fromJson(Map<String, Object?> json) =>
      _$HttpResponseModelFromJson(json);

  String? get contentType => headers?.getValueContentType();
  MediaType? get mediaType => getMediaTypeFromHeaders(headers);

  HttpResponseModel fromResponse({
    required Response response,
    Duration? time,
  }) {
    // Convert Dio headers to Map<String, String> format
    Map<String, String> responseHeaders = {};
    response.headers.forEach((key, value) {
      responseHeaders[key] = value.join(', ');
    });
 
    MediaType? mediaType = getMediaTypeFromHeaders(responseHeaders);

    // Process response body according to media type
    final body = (mediaType?.subtype == kSubTypeJson)
        ? utf8.decode(response.data is Uint8List ? response.data : utf8.encode(response.data.toString()))
        : response.data.toString();

    return HttpResponseModel(
      statusCode: response.statusCode,
      headers: responseHeaders,
      requestHeaders: Map<String, String>.from(response.requestOptions.headers),
      body: body,
      formattedBody: formatBody(body, Headers.fromMap({for (var entry in responseHeaders.entries) entry.key: [entry.value]})),
      bodyBytes: response.data is Uint8List ? response.data : Uint8List.fromList(utf8.encode(response.data.toString())),
      time: time,
    );
  }
}
