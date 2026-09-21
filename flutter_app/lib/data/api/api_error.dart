import 'package:dio/dio.dart';

/// 从请求异常中提取可展示的错误信息。
///
/// 服务端错误统一返回 `{error: "..."}`，优先展示该信息；其余情况回退到
/// 异常自身的字符串描述。
String apiErrorMessage(Object error) {
  if (error is DioException && error.response?.data is Map) {
    final message = (error.response!.data as Map)['error'];
    if (message != null && message.toString().trim().isNotEmpty) {
      return message.toString();
    }
  }
  return error.toString();
}
