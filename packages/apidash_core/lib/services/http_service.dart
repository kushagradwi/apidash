import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:seed/seed.dart';
import '../consts.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import 'http_client_manager.dart';

typedef HttpResponse = Response<dynamic>;

final httpClientManager = DioHttpClientManager();

Future<(HttpResponse?, Duration?, String?)> sendHttpRequest(
  String requestId,
  APIType apiType,
  HttpRequestModel requestModel, {
  SupportedUriSchemes defaultUriScheme = kDefaultUriScheme,
  bool noSSL = false,
}) async {
  final client = httpClientManager.createClient(requestId, noSSL: noSSL);

  (Uri?, String?) uriRec = getValidRequestUri(
    requestModel.url,
    requestModel.enabledParams,
    defaultUriScheme: defaultUriScheme,
  );

  if (uriRec.$1 != null) {
    Uri requestUrl = uriRec.$1!;
    Map<String, String> headers = requestModel.enabledHeadersMap;
    HttpResponse? response;
    String? body;
    try {
      Stopwatch stopwatch = Stopwatch()..start();
      if (apiType == APIType.rest) {
        var isMultiPartRequest = requestModel.bodyContentType == ContentType.formdata;

        if (kMethodsWithBody.contains(requestModel.method)) {
          var requestBody = requestModel.body;
          if (requestBody != null && !isMultiPartRequest) {
            var contentLength = utf8.encode(requestBody).length;
            if (contentLength > 0) {
              body = requestBody;
              headers[HttpHeaders.contentLengthHeader] = contentLength.toString();
              if (!requestModel.hasContentTypeHeader) {
                headers[HttpHeaders.contentTypeHeader] = requestModel.bodyContentType.header;
              }
            }
          }
          // MultiPart Request  mirated to Dio
          if (isMultiPartRequest) {
            Map<String, dynamic> formDataMap = {};

            for (var item in requestModel.formDataList) {
              if (item.type == FormDataType.text) {
                formDataMap[item.name] = item.value;
              } else {
                formDataMap[item.name] = await MultipartFile.fromFile(item.value);
              }
            }

            FormData formData = FormData.fromMap(formDataMap);

            response = await client.post(
              requestUrl.toString(),
              data: formData,
              options: Options(headers: headers, validateStatus: (status) => true),
            );
            stopwatch.stop();
            return (response, stopwatch.elapsed, null);
          }
        }

        switch (requestModel.method) {
          case HTTPVerb.get:
            response = await client.get(
              requestUrl.toString(),
              options: Options(headers: headers, validateStatus: (status) => true),
            );
            break;
          case HTTPVerb.head:
            response = await client.head(
              requestUrl.toString(),
              options: Options(headers: headers, validateStatus: (status) => true),
            );
            break;
          case HTTPVerb.post:
            response = await client.post(
              requestUrl.toString(),
              data: body,
              options: Options(headers: headers, validateStatus: (status) => true),
            );
            break;
          case HTTPVerb.put:
            response = await client.put(
              requestUrl.toString(),
              data: body,
              options: Options(headers: headers, validateStatus: (status) => true),
            );
            break;
          case HTTPVerb.patch:
            response = await client.patch(
              requestUrl.toString(),
              data: body,
              options: Options(headers: headers, validateStatus: (status) => true),
            );
            break;
          case HTTPVerb.delete:
            response = await client.delete(
              requestUrl.toString(),
              data: body,
              options: Options(headers: headers, validateStatus: (status) => true),
            );
            break;
        }
      }

      if (apiType == APIType.graphql) {
        var requestBody = getGraphQLBody(requestModel);
        if (requestBody != null) {
          var contentLength = utf8.encode(requestBody).length;
          if (contentLength > 0) {
            body = requestBody;
            headers[HttpHeaders.contentLengthHeader] = contentLength.toString();
            if (!requestModel.hasContentTypeHeader) {
              headers[HttpHeaders.contentTypeHeader] = ContentType.json.header;
            }
          }
        }
        response = await client.post(
          requestUrl.toString(),
          data: body,
          options: Options(headers: headers, validateStatus: (status) => true),
        );
      }
      stopwatch.stop();
      return (response, stopwatch.elapsed, null);
    } on DioException catch (e) {
      if (httpClientManager.wasRequestCancelled(requestId)) {
        return (null, null, kMsgRequestCancelled);
      }
      return (null, null, e.toString());
    } finally {
      httpClientManager.closeClient(requestId);
    }
  } else {
    return (null, null, uriRec.$2);
  }
}

void cancelHttpRequest(String? requestId) {
  httpClientManager.cancelRequest(requestId);
}
