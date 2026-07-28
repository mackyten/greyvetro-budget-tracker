/// A single line item tracked every month (a bank/e-wallet/investment for
/// [AccountSection.asset], or an earmarked fund/credit-card balance for
/// [AccountSection.reservedLiability]).
enum AccountSection { asset, reservedLiability }

/// Sub-type shown only for [AccountSection.reservedLiability] rows, so the UI
/// can distinguish money set aside (reserved) from money actually owed (debt).
enum ReservedKind { reserved, creditCard }

class Account {
  Account({
    required this.id,
    required this.name,
    required this.section,
    this.reservedKind,
    required this.order,
    this.active = true,
    this.cashCounter = false,
  });

  final String id;
  final String name;
  final AccountSection section;
  final ReservedKind? reservedKind;
  final int order;
  final bool active;

  /// Whether this row shows the denomination-counter shortcut when entering
  /// its monthly balance (see [AccountSection.asset] accounts that track
  /// physical cash, e.g. a wallet).
  final bool cashCounter;

  factory Account.fromMap(String id, Map<String, dynamic> map) {
    return Account(
      id: id,
      name: map['name'] as String,
      section: AccountSection.values.byName(map['section'] as String),
      reservedKind: map['reservedKind'] != null
          ? ReservedKind.values.byName(map['reservedKind'] as String)
          : null,
      order: (map['order'] as num).toInt(),
      active: map['active'] as bool? ?? true,
      cashCounter: map['cashCounter'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'section': section.name,
      'reservedKind': reservedKind?.name,
      'order': order,
      'active': active,
      'cashCounter': cashCounter,
    };
  }

  Account copyWith({String? name, bool? active, int? order, bool? cashCounter}) {
    return Account(
      id: id,
      name: name ?? this.name,
      section: section,
      reservedKind: reservedKind,
      order: order ?? this.order,
      active: active ?? this.active,
      cashCounter: cashCounter ?? this.cashCounter,
    );
  }
}
