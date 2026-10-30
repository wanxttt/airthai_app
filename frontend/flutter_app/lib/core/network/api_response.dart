/// Generic API Response container for AirthAI network operations.
///
/// Phase 1: Authentication & API Infrastructure
class ApiResponse<T> {
  final int statusCode;
  final bool isSuccess;
  final T? data;
  final String? message;
  final Map<String, dynamic>? errors;
  final String? requestId;

  String? get errorMessage => message;

  const ApiResponse({
    required this.statusCode,
    required this.isSuccess,
    this.data,
    this.message,
    this.errors,
    this.requestId,
  });

  factory ApiResponse.success({
    required int statusCode,
    T? data,
    String? message,
    String? requestId,
  }) {
    return ApiResponse<T>(
      statusCode: statusCode,
      isSuccess: true,
      data: data,
      message: message,
      requestId: requestId,
    );
  }

  factory ApiResponse.error({
    required int statusCode,
    String? message,
    Map<String, dynamic>? errors,
    T? data,
    String? requestId,
  }) {
    return ApiResponse<T>(
      statusCode: statusCode,
      isSuccess: false,
      data: data,
      message: message,
      errors: errors,
      requestId: requestId,
    );
  }

  @override
  String toString() {
    return 'ApiResponse(status: $statusCode, success: $isSuccess, message: $message, requestId: $requestId, data: $data)';
  }
}
