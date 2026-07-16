/// Represents a specific device model with its IR file.
class IRModel {
  final int id;
  final String name;
  final int brandId;
  final String fileName;
  final String? fileUrl;

  const IRModel({
    required this.id,
    required this.name,
    required this.brandId,
    required this.fileName,
    this.fileUrl,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'brand_id': brandId,
        'file_name': fileName,
        'file_url': fileUrl,
      };

  factory IRModel.fromMap(Map<String, dynamic> map) => IRModel(
        id: map['id'] as int,
        name: map['name'] as String,
        brandId: map['brand_id'] as int,
        fileName: map['file_name'] as String,
        fileUrl: map['file_url'] as String?,
      );

  @override
  String toString() => 'IRModel(id: $id, name: $name)';
}
