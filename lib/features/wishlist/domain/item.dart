import 'package:freezed_annotation/freezed_annotation.dart';

part 'item.freezed.dart';
part 'item.g.dart';

/// Scraping lifecycle of an item. `POST /items` returns `PENDING`; the client
/// polls `GET /items/{id}` until `COMPLETED` or `FAILED`.
enum ItemStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('COMPLETED')
  completed,
  @JsonValue('FAILED')
  failed,
}

/// Mirrors the backend `ItemResponse`. `title`, `price`, `description` and
/// `domainSource` are null while `status == pending` (scraping in progress).
@freezed
abstract class Item with _$Item {
  const factory Item({
    required String id,
    @JsonKey(name: 'list_id') String? listId,
    @JsonKey(name: 'original_url') required String originalUrl,
    String? title,
    // Backend sends a JSON number (e.g. 63.0) or null; json_serializable casts
    // the incoming `num` to `double`.
    double? price,
    @Default(<String>[]) List<String> images,
    String? description,
    @JsonKey(name: 'domain_source') String? domainSource,
    required ItemStatus status,
    @Default(false) bool purchased,
  }) = _Item;

  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);
}
