/// Generic API Response container for AirthAI network operations.
///
/// Phase 1: Authentication & API Infrastructure
class ApiResponse<T> {
  final int statusCode;
  final bool isSuccess;
  final T? data;
  final String? message;
  final Map<String, dynamic>? errors;

  const ApiResponse({
    required this.statusCode,
    required this.isSuccess,
    this.data,
    this.message,
    this.errors,
  });

  factory ApiResponse.success({
    required int statusCode,
    T? data,
    String? message,
  }) {
    return ApiResponse<T>(
      statusCode: statusCode,
      isSuccess: true,
      data: data,
      message: message,
    );
  }

  factory ApiResponse.error({
    required int statusCode,
    String? message,
    Map<String, dynamic>? errors,
    T? data,
  }) {
    return ApiResponse<T>(
      statusCode: statusCode,
      isSuccess: false,
      data: data,
      message: message,
      errors: errors,
    );
  }

  @override
  String toString() {
    return 'ApiResponse(status: $statusCode, success: $isSuccess, message: $message, data: $data)';
  }
}

