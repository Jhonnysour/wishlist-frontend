// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Item _$ItemFromJson(Map<String, dynamic> json) => _Item(
  id: json['id'] as String,
  originalUrl: json['original_url'] as String,
  title: json['title'] as String?,
  price: (json['price'] as num?)?.toDouble(),
  images:
      (json['images'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  description: json['description'] as String?,
  domainSource: json['domain_source'] as String?,
  status: $enumDecode(_$ItemStatusEnumMap, json['status']),
  purchased: json['purchased'] as bool? ?? false,
);

Map<String, dynamic> _$ItemToJson(_Item instance) => <String, dynamic>{
  'id': instance.id,
  'original_url': instance.originalUrl,
  'title': instance.title,
  'price': instance.price,
  'images': instance.images,
  'description': instance.description,
  'domain_source': instance.domainSource,
  'status': _$ItemStatusEnumMap[instance.status]!,
  'purchased': instance.purchased,
};

const _$ItemStatusEnumMap = {
  ItemStatus.pending: 'PENDING',
  ItemStatus.completed: 'COMPLETED',
  ItemStatus.failed: 'FAILED',
};
