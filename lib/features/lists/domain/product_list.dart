/// Una lista con nombre que agrupa productos (espejo de `ListResponse` del
/// backend). Se llama ProductList para no chocar con el `List` de Dart.
class ProductList {
  const ProductList({
    required this.id,
    required this.name,
    required this.itemCount,
    required this.createdAt,
  });

  final String id;
  final String name;
  final int itemCount;
  final DateTime createdAt;

  factory ProductList.fromJson(Map<String, dynamic> json) => ProductList(
        id: json['id'] as String,
        name: json['name'] as String,
        itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
