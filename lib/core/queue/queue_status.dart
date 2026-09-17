enum QueueActionStatus {
  pending,
  processing,
  completed,
  failedRetryable,
  failedFinal,
  blockedInsufficientFunds,
  rejected,
}

extension QueueActionStatusX on QueueActionStatus {
  String get name => toString().split('.').last;

  static QueueActionStatus fromName(String name) =>
      QueueActionStatus.values.firstWhere((e) => e.name == name);
}
