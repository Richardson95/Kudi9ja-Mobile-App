/// Help and complaints: a customer's conversations with the Kudi9ja team.
///
/// Live on both sides. A reply is pushed down the server's event stream the
/// moment it is saved, so the thread on a phone and the queue on the panel
/// update without anybody pulling to refresh.
library;

import '_wire.dart';

enum SupportKind { complaint, enquiry }

extension SupportKindX on SupportKind {
  String get wire => toWire(this);

  String get label => switch (this) {
    SupportKind.complaint => 'Complaint',
    SupportKind.enquiry => 'Question',
  };
}

enum SupportStatus { open, awaitingCustomer, resolved }

extension SupportStatusX on SupportStatus {
  String get wire => toWire(this);
}

enum SupportAuthor { customer, staff, system }

class SupportConversation {
  const SupportConversation({
    required this.id,
    required this.reference,
    required this.kind,
    required this.kindLabel,
    required this.category,
    required this.subject,
    required this.status,
    required this.statusLabel,
    required this.lastMessageAt,
    required this.createdAt,
    this.assignedToName = '',
    this.lastMessagePreview = '',
    this.lastMessageBy,
    this.unread = 0,
    this.acknowledgeBy,
    this.acknowledgedAt,
    this.resolveBy,
    this.resolvedAt,
    this.resolutionNote = '',
    this.overdue = false,
    this.customerId = '',
    this.customerName = '',
    this.customerRef = '',
    this.assignedToId = '',
    this.resolvedBy = '',
  });

  final String id;

  /// What the customer quotes, and what the team searches by.
  final String reference;
  final SupportKind kind;
  final String kindLabel;
  final String category;
  final String subject;
  final SupportStatus status;
  final String statusLabel;
  final String assignedToName;
  final DateTime lastMessageAt;
  final String lastMessagePreview;
  final SupportAuthor? lastMessageBy;

  /// Messages the reader has not seen yet — the customer's replies on the
  /// panel's view, the team's on the customer's.
  final int unread;

  /// When the team must acknowledge and resolve it by, under the Terms.
  final DateTime? acknowledgeBy;
  final DateTime? acknowledgedAt;
  final DateTime? resolveBy;
  final DateTime? resolvedAt;

  /// What the team said when they marked it sorted. The customer sees it.
  final String resolutionNote;

  /// Past one of those dates without the step it promised.
  final bool overdue;
  final DateTime createdAt;

  // The panel's fields.
  final String customerId;
  final String customerName;
  final String customerRef;
  final String assignedToId;
  final String resolvedBy;

  bool get isResolved => status == SupportStatus.resolved;

  static SupportConversation fromApi(Map<String, dynamic> j) =>
      SupportConversation(
        id: str(j['id']),
        reference: str(j['reference']),
        kind: wireEnum(j['kind'], SupportKind.values, SupportKind.enquiry),
        kindLabel: str(j['kindLabel']),
        category: str(j['category']),
        subject: str(j['subject']),
        status: wireEnum(j['status'], SupportStatus.values, SupportStatus.open),
        statusLabel: str(j['statusLabel']),
        assignedToName: str(j['assignedToName']),
        lastMessageAt: date(j['lastMessageAt']),
        lastMessagePreview: str(j['lastMessagePreview']),
        lastMessageBy: j['lastMessageBy'] == null
            ? null
            : wireEnum(j['lastMessageBy'], SupportAuthor.values, SupportAuthor.system),
        unread: integer(j['unread']),
        acknowledgeBy: dateOrNull(j['acknowledgeBy']),
        acknowledgedAt: dateOrNull(j['acknowledgedAt']),
        resolveBy: dateOrNull(j['resolveBy']),
        resolvedAt: dateOrNull(j['resolvedAt']),
        resolutionNote: str(j['resolutionNote']),
        overdue: boolean(j['overdue']),
        createdAt: date(j['createdAt']),
        customerId: str(j['customerId']),
        customerName: str(j['customerName']),
        customerRef: str(j['customerRef']),
        assignedToId: str(j['assignedToId']),
        resolvedBy: str(j['resolvedBy']),
      );
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.conversationId,
    required this.author,
    required this.authorName,
    required this.mine,
    required this.createdAt,
    this.body = '',
    this.attachmentName = '',
    this.attachmentType = '',
    this.attachmentSize = 0,
    this.attachmentUrl = '',
  });

  final String id;
  final String conversationId;
  final SupportAuthor author;
  final String authorName;

  /// Written by whoever is reading — the customer on their view, any of the
  /// team on the panel's.
  final bool mine;
  final String body;
  final String attachmentName;
  final String attachmentType;
  final int attachmentSize;

  /// Where the file is fetched from, with the reader's own session. Never a
  /// public link: a photo of a bank app is somebody's account.
  final String attachmentUrl;
  final DateTime createdAt;

  bool get hasAttachment => attachmentUrl.isNotEmpty || attachmentName.isNotEmpty;
  bool get isImage => attachmentType.toLowerCase().startsWith('image/');

  static SupportMessage fromApi(Map<String, dynamic> j) => SupportMessage(
    id: str(j['id']),
    conversationId: str(j['conversationId']),
    author: wireEnum(j['author'], SupportAuthor.values, SupportAuthor.system),
    authorName: str(j['authorName']),
    mine: boolean(j['mine']),
    body: str(j['body']),
    attachmentName: str(j['attachmentName']),
    attachmentType: str(j['attachmentType']),
    attachmentSize: integer(j['attachmentSize']),
    attachmentUrl: str(j['attachmentUrl']),
    createdAt: date(j['createdAt']),
  );
}

class SupportThread {
  const SupportThread({required this.conversation, required this.messages});

  final SupportConversation conversation;
  final List<SupportMessage> messages;

  /// The same thread with [message] in it, once — the stream and the reply
  /// call can both deliver the same message.
  SupportThread withMessage(SupportMessage message, [SupportConversation? now]) =>
      SupportThread(
        conversation: now ?? conversation,
        messages: messages.any((m) => m.id == message.id)
            ? messages
            : [...messages, message],
      );

  static SupportThread fromApi(Map<String, dynamic> j) => SupportThread(
    conversation: SupportConversation.fromApi(obj(j['conversation'])),
    messages: list(j['messages']).map(SupportMessage.fromApi).toList(),
  );
}

/// The panel's counts, for the badge and the queue's header.
class SupportQueueSummary {
  const SupportQueueSummary({
    this.open = 0,
    this.awaitingCustomer = 0,
    this.unassigned = 0,
    this.overdue = 0,
    this.unread = 0,
  });

  final int open;
  final int awaitingCustomer;
  final int unassigned;
  final int overdue;
  final int unread;

  static SupportQueueSummary fromApi(Map<String, dynamic> j) => SupportQueueSummary(
    open: integer(j['open']),
    awaitingCustomer: integer(j['awaitingCustomer']),
    unassigned: integer(j['unassigned']),
    overdue: integer(j['overdue']),
    unread: integer(j['unread']),
  );
}

/// One thing the server pushed down the event stream.
sealed class SupportEvent {
  const SupportEvent();
}

/// A new message, with the conversation as it now stands.
class SupportMessageEvent extends SupportEvent {
  const SupportMessageEvent(this.conversation, this.message);
  final SupportConversation conversation;
  final SupportMessage message;
}

/// A conversation changed: taken on, resolved, reopened.
class SupportConversationEvent extends SupportEvent {
  const SupportConversationEvent(this.conversation);
  final SupportConversation conversation;
}

/// Somebody on the other side is typing. Stored nowhere.
class SupportTypingEvent extends SupportEvent {
  const SupportTypingEvent(this.conversationId, this.who, this.name);
  final String conversationId;
  final SupportAuthor who;
  final String name;
}
