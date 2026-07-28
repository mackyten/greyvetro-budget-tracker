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
  });

  final String id;
  final String name;
  final AccountSection section;
  final ReservedKind? reservedKind;
  final int order;
  final bool active;

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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'section': section.name,
      'reservedKind': reservedKind?.name,
      'order': order,
      'active': active,
    };
  }

  Account copyWith({String? name, bool? active, int? order}) {
    return Account(
      id: id,
      name: name ?? this.name,
      section: section,
      reservedKind: reservedKind,
      order: order ?? this.order,
      active: active ?? this.active,
    );
  }
}
