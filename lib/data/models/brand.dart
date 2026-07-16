/// Represents a brand (manufacturer) of a device.
class IRBrand {
  final int id;
  final String name;
  final int deviceTypeId;
  final String normalizedName;

  const IRBrand({
    required this.id,
    required this.name,
    required this.deviceTypeId,
    required this.normalizedName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'device_type_id': deviceTypeId,
        'normalized_name': normalizedName,
      };

  factory IRBrand.fromMap(Map<String, dynamic> map) => IRBrand(
        id: map['id'] as int,
        name: map['name'] as String,
        deviceTypeId: map['device_type_id'] as int,
        normalizedName: map['normalized_name'] as String,
      );

  @override
  String toString() => 'IRBrand(id: $id, name: $name)';
}
