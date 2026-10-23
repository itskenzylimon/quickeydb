class MemoryModel {
  String name;
  String data;
  String? type;

  int? version; // increments each update
  String? createdAt; // microsecondsSinceEpoch
  String? updatedAt; // microsecondsSinceEpoch
  String? expiresAt; // microsecondsSinceEpoch (for TTL)

  MemoryModel({
    required this.name,
    required this.data,
    this.type,
    this.version,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
  });

  // Convert model → Map<String, dynamic>
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'data': data,
      'type': type,
      'version': version,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'expiresAt': expiresAt,
    };
  }

  // Convert Map<String, dynamic> → model
  factory MemoryModel.fromMap(Map<String, dynamic> map) {
    return MemoryModel(
      name: map['name'],
      data: map['data'],
      type: map['type'],
      version: map['version'],
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
      expiresAt: map['expiresAt'],
    );
  }
}
