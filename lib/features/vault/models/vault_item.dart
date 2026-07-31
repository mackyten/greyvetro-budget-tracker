/// Two kinds of records the Secure Vault can hold — a bank/card record with
/// its own three fixed fields, or a freeform note.
enum VaultItemKind { bankCard, note }

/// A single Secure Vault record. Never round-trips through Firestore or
/// [BudgetRepository] — this module is local-only, backed by
/// `flutter_secure_storage` (see `VaultStore`). [accountId] is a plain,
/// optional soft-link to `Account.id` — this model deliberately doesn't
/// import the `Account` type, so the vault stays fully decoupled from the
/// net-worth data path.
class VaultItem {
  VaultItem({
    required this.id,
    required this.kind,
    required this.title,
    this.accountNumber,
    this.cardNumber,
    this.cardholderName,
    this.body,
    this.accountId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final VaultItemKind kind;
  final String title;

  // VaultItemKind.bankCard payload — all optional individually, per scope
  // (no other fields beyond these three).
  final String? accountNumber;
  final String? cardNumber;
  final String? cardholderName;

  // VaultItemKind.note payload.
  final String? body;

  final String? accountId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    return VaultItem(
      id: json['id'] as String,
      kind: VaultItemKind.values.byName(json['kind'] as String),
      title: json['title'] as String,
      accountNumber: json['accountNumber'] as String?,
      cardNumber: json['cardNumber'] as String?,
      cardholderName: json['cardholderName'] as String?,
      body: json['body'] as String?,
      accountId: json['accountId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.name,
      'title': title,
      'accountNumber': accountNumber,
      'cardNumber': cardNumber,
      'cardholderName': cardholderName,
      'body': body,
      'accountId': accountId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

/// Plain (id, display name) pair the vault UI can show without importing
/// the real `Account` type — the caller (which already has `List<Account>`
/// from the normal repository stream) maps its accounts down to this shape.
typedef VaultAccountRef = ({String id, String name});
