class CouponData {
  const CouponData({
    this.id,
    this.code,
    this.type,
    this.typeName,
    this.price,
    this.region,
    this.isSpecial = false,
    this.isValid = false,
    this.status,
    this.usedAt,
    this.displayName,
    this.packageData,
    this.additionalMinutePlan,
    this.cloudStoragePlan,
    this.batch,
    this.agent,
    this.redeemer,
    this.verification,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String? code;
  final String? type;
  final String? typeName;
  final String? price;
  final String? region;
  final bool isSpecial;
  final bool isValid;
  final String? status;
  final String? usedAt;
  final String? displayName;
  final CouponProduct? packageData;
  final CouponProduct? additionalMinutePlan;
  final CouponProduct? cloudStoragePlan;
  final CouponBatch? batch;
  final CouponPerson? agent;
  final CouponPerson? redeemer;
  final CouponVerificationDetails? verification;
  final String? createdAt;
  final String? updatedAt;

  CouponProduct? get product =>
      packageData ?? additionalMinutePlan ?? cloudStoragePlan;

  factory CouponData.fromJson(Object? value) {
    final json = _stringMap(value);
    return CouponData(
      id: _stringish(json['id']),
      code: _stringish(json['code']),
      type: _stringish(json['type']),
      typeName: _stringish(json['type_name']),
      price: _stringish(json['price']),
      region: _stringish(json['region']),
      isSpecial: _boolish(json['is_special']),
      isValid: _boolish(json['is_valid']),
      status: _stringish(json['status']),
      usedAt: _stringish(json['used_at']),
      displayName: _stringish(json['display_name']),
      packageData: _nested<CouponProduct>(json['package'], CouponProduct.fromJson),
      additionalMinutePlan: _nested<CouponProduct>(
        json['additional_minute_plan'],
        CouponProduct.fromJson,
      ),
      cloudStoragePlan: _nested<CouponProduct>(
        json['cloud_storage_plan'],
        CouponProduct.fromJson,
      ),
      batch: _nested<CouponBatch>(json['batch'], CouponBatch.fromJson),
      agent: _nested<CouponPerson>(json['agent'], CouponPerson.fromJson),
      redeemer: _nested<CouponPerson>(json['redeemer'], CouponPerson.fromJson),
      verification: _nested<CouponVerificationDetails>(
        json['verification'],
        CouponVerificationDetails.fromJson,
      ),
      createdAt: _stringish(json['created_at']),
      updatedAt: _stringish(json['updated_at']),
    );
  }
}

class CouponProduct {
  const CouponProduct({
    this.id,
    this.name,
    this.price,
    this.description,
    this.duration,
    this.minutes,
    this.storage,
    this.storageSize,
  });

  final String? id;
  final String? name;
  final String? price;
  final String? description;
  final String? duration;
  final String? minutes;
  final String? storage;
  final String? storageSize;

  factory CouponProduct.fromJson(Object? value) {
    final json = _stringMap(value);
    return CouponProduct(
      id: _stringish(json['id']),
      name: _stringish(json['name']),
      price: _stringish(json['price']),
      description: _stringish(json['description']),
      duration: _stringish(json['duration']),
      minutes: _stringish(json['minutes']),
      storage: _stringish(json['storage']),
      storageSize: _stringish(json['storage_size']),
    );
  }
}

class CouponBatch {
  const CouponBatch({
    this.id,
    this.reference,
    this.type,
    this.typeName,
    this.region,
    this.displayName,
    this.createdAt,
  });

  final String? id;
  final String? reference;
  final String? type;
  final String? typeName;
  final String? region;
  final String? displayName;
  final String? createdAt;

  factory CouponBatch.fromJson(Object? value) {
    final json = _stringMap(value);
    return CouponBatch(
      id: _stringish(json['id']),
      reference: _stringish(json['reference']),
      type: _stringish(json['type']),
      typeName: _stringish(json['type_name']),
      region: _stringish(json['region']),
      displayName: _stringish(json['display_name']),
      createdAt: _stringish(json['created_at']),
    );
  }
}

class CouponPerson {
  const CouponPerson({this.id, this.name, this.username});

  final String? id;
  final String? name;
  final String? username;

  factory CouponPerson.fromJson(Object? value) {
    final json = _stringMap(value);
    return CouponPerson(
      id: _stringish(json['id']),
      name: _stringish(json['name']),
      username: _stringish(json['username']),
    );
  }
}

class CouponVerificationDetails {
  const CouponVerificationDetails({
    this.isValid = false,
    this.status,
    this.message,
  });

  final bool isValid;
  final String? status;
  final String? message;

  factory CouponVerificationDetails.fromJson(Object? value) {
    final json = _stringMap(value);
    return CouponVerificationDetails(
      isValid: _boolish(json['is_valid']),
      status: _stringish(json['status']),
      message: _stringish(json['message']),
    );
  }
}

Map<String, Object?> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

T? _nested<T>(Object? value, T Function(Object?) parser) =>
    value is Map ? parser(value) : null;

String? _stringish(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  if (text.trim().isEmpty || text == 'null') return null;
  return text;
}

bool _boolish(Object? value) {
  if (value is bool) return value;
  if (value is String) {
    switch (value.toLowerCase()) {
      case 'true':
        return true;
      case 'false':
        return false;
    }
  }
  return false;
}
