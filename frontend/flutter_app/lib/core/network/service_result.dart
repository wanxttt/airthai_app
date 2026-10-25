/// Unified service result container for AirthAI domain services.
class ServiceResult<T> {
  final bool success;
  final T? data;
  final String? errorMessage;
  final int statusCode;

  const ServiceResult({
    required this.success,
    this.data,
    this.errorMessage,
    this.statusCode = 200,
  });

  factory ServiceResult.success(T data, {int statusCode = 200}) =>
      ServiceResult(success: true, data: data, statusCode: statusCode);

  factory ServiceResult.failure(String message, {int statusCode = 400}) =>
      ServiceResult(success: false, errorMessage: message, statusCode: statusCode);
}
