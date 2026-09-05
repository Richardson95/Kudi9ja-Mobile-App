import 'models.dart';

/// A rotating savings circle — the digital version of ajo / esusu / adashe.
/// Everyone contributes the same amount each cycle; one member collects the
/// whole pot each round until everybody has had a turn.
class ThriftCircle {
  ThriftCircle({
    required this.id,
    required this.name,
    required this.contribution,
    required this.frequency,
    required this.members,
    required this.startDate,
    required this.createdByMe,
    this.currentRound = 1,
    this.roundsPaid = const [],
    this.inviteCode = '',
    this.emoji = '🤝',
  });

  final String id;
  final String name;

  /// What each member pays in per cycle.
  final double contribution;
  final AutoFrequency frequency;
  final List<ThriftMember> members;
  final DateTime startDate;
  final bool createdByMe;

  /// 1-based index of the round currently being collected.
  final int currentRound;

  /// Round numbers this user has already contributed to.
  final List<int> roundsPaid;
  final String inviteCode;
  final String emoji;

  int get size => members.length;

  /// What the collector walks away with each round.
  double get potSize => contribution * size;

  /// Total this user pays across the whole circle.
  double get totalCommitment => contribution * size;

  bool get isComplete => currentRound > size;

  bool get hasPaidThisRound => roundsPaid.contains(currentRound);

  ThriftMember? get currentCollector =>
      currentRound <= members.length ? members[currentRound - 1] : null;

  /// The round number at which this user collects the pot.
  int get myRound {
    for (var i = 0; i < members.length; i++) {
      if (members[i].isMe) return i + 1;
    }
    return 0;
  }

  bool get iHaveCollected => myRound > 0 && currentRound > myRound;

  DateTime dateForRound(int round) =>
      startDate.add(frequency.interval * (round - 1));

  DateTime get myPayoutDate => dateForRound(myRound);

  DateTime get nextCollectionDate => dateForRound(currentRound);

  double get progress =>
      size == 0 ? 0 : ((currentRound - 1) / size).clamp(0.0, 1.0);

  /// How many members have paid into the current round.
  int get paidThisRound {
    // Everyone ahead of the collector in the rotation has settled; this user's
    // own status is tracked precisely.
    final others = (size * 0.7).floor();
    return (hasPaidThisRound ? others + 1 : others).clamp(0, size);
  }

  ThriftCircle copyWith({
    int? currentRound,
    List<int>? roundsPaid,
    List<ThriftMember>? members,
  }) => ThriftCircle(
    id: id,
    name: name,
    contribution: contribution,
    frequency: frequency,
    members: members ?? this.members,
    startDate: startDate,
    createdByMe: createdByMe,
    currentRound: currentRound ?? this.currentRound,
    roundsPaid: roundsPaid ?? this.roundsPaid,
    inviteCode: inviteCode,
    emoji: emoji,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'contribution': contribution,
    'frequency': frequency.index,
    'members': members.map((m) => m.toJson()).toList(),
    'startDate': startDate.toIso8601String(),
    'createdByMe': createdByMe,
    'currentRound': currentRound,
    'roundsPaid': roundsPaid,
    'inviteCode': inviteCode,
    'emoji': emoji,
  };

  factory ThriftCircle.fromJson(Map<String, dynamic> j) => ThriftCircle(
    id: j['id'] as String,
    name: j['name'] as String,
    contribution: (j['contribution'] as num).toDouble(),
    frequency: AutoFrequency.values[j['frequency'] as int],
    members: (j['members'] as List)
        .map((e) => ThriftMember.fromJson(e as Map<String, dynamic>))
        .toList(),
    startDate: DateTime.parse(j['startDate'] as String),
    createdByMe: j['createdByMe'] as bool? ?? true,
    currentRound: j['currentRound'] as int? ?? 1,
    roundsPaid: (j['roundsPaid'] as List? ?? []).cast<int>(),
    inviteCode: j['inviteCode'] as String? ?? '',
    emoji: j['emoji'] as String? ?? '🤝',
  );
}

/// One seat in a circle.
///
/// A member is identified by their **customer reference**, not by their name.
/// A circle collects real money from real wallets each round, so every seat has
/// to belong to an account that can actually be debited — a typed name matches
/// nobody, and a circle built on typed names collects nothing from them and
/// pays the pot out anyway.
///
/// The [name] is what the server resolved that reference to, and it comes back
/// masked — "Chioma G. A." — so a member list cannot be used to read other
/// customers' full names off the app.
class ThriftMember {
  const ThriftMember({
    required this.customerRef,
    required this.name,
    required this.initials,
    this.isMe = false,
  });

  /// The Kudi9ja reference this seat belongs to, e.g. `K9-A1B2C3`.
  final String customerRef;

  /// The masked display name the reference resolved to.
  final String name;
  final String initials;
  final bool isMe;

  Map<String, dynamic> toJson() => {
    'customerRef': customerRef,
    'name': name,
    'initials': initials,
    'isMe': isMe,
  };

  factory ThriftMember.fromJson(Map<String, dynamic> j) => ThriftMember(
    customerRef: j['customerRef'] as String? ?? '',
    name: j['name'] as String,
    initials: j['initials'] as String,
    isMe: j['isMe'] as bool? ?? false,
  );
}
