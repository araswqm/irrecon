/// Represents a device category (e.g. TV, AC, Soundbar).
class DeviceType {
  final int id;
  final String name;
  final String? icon;

  const DeviceType({
    required this.id,
    required this.name,
    this.icon,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
      };

  factory DeviceType.fromMap(Map<String, dynamic> map) => DeviceType(
        id: map['id'] as int,
        name: map['name'] as String,
        icon: map['icon'] as String?,
      );

  @override
  String toString() => 'DeviceType(id: $id, name: $name)';
}
