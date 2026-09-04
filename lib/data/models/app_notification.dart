enum NotifyKind {
  interest,
  maturity,
  repaymentDue,
  repaymentPaid,
  autoSave,
  thrift,
  security,
  general,
}

/// An entry in the in-app notification centre.
class AppNotification {
  AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.date,
    this.read = false,
    this.amount,
  });

  final String id;
  final NotifyKind kind;
  final String title;
  final String body;
  final DateTime date;
  final bool read;
  final double? amount;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    date: date,
    read: read ?? this.read,
    amount: amount,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.index,
    'title': title,
    'body': body,
    'date': date.toIso8601String(),
    'read': read,
    'amount': amount,
  };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    kind: NotifyKind.values[j['kind'] as int],
    title: j['title'] as String,
    body: j['body'] as String,
    date: DateTime.parse(j['date'] as String),
    read: j['read'] as bool? ?? false,
    amount: (j['amount'] as num?)?.toDouble(),
  );
}
