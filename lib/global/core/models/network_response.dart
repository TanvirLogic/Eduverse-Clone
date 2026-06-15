class NetworkResponse {
  final bool isSuccess;
  final int responseCode;
  final dynamic responseData;
  final String? errorMessage;

  NetworkResponse({
    required this.isSuccess,
    required this.responseCode,
    this.responseData,
    this.errorMessage = 'Something went wrong',
  });
}
