// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Item {

 String get id;@JsonKey(name: 'original_url') String get originalUrl; String? get title;// Backend sends a JSON number (e.g. 63.0) or null; json_serializable casts
// the incoming `num` to `double`.
 double? get price; List<String> get images; String? get description;@JsonKey(name: 'domain_source') String? get domainSource; ItemStatus get status; bool get purchased;
/// Create a copy of Item
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ItemCopyWith<Item> get copyWith => _$ItemCopyWithImpl<Item>(this as Item, _$identity);

  /// Serializes this Item to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Item&&(identical(other.id, id) || other.id == id)&&(identical(other.originalUrl, originalUrl) || other.originalUrl == originalUrl)&&(identical(other.title, title) || other.title == title)&&(identical(other.price, price) || other.price == price)&&const DeepCollectionEquality().equals(other.images, images)&&(identical(other.description, description) || other.description == description)&&(identical(other.domainSource, domainSource) || other.domainSource == domainSource)&&(identical(other.status, status) || other.status == status)&&(identical(other.purchased, purchased) || other.purchased == purchased));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,originalUrl,title,price,const DeepCollectionEquality().hash(images),description,domainSource,status,purchased);

@override
String toString() {
  return 'Item(id: $id, originalUrl: $originalUrl, title: $title, price: $price, images: $images, description: $description, domainSource: $domainSource, status: $status, purchased: $purchased)';
}


}

/// @nodoc
abstract mixin class $ItemCopyWith<$Res>  {
  factory $ItemCopyWith(Item value, $Res Function(Item) _then) = _$ItemCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'original_url') String originalUrl, String? title, double? price, List<String> images, String? description,@JsonKey(name: 'domain_source') String? domainSource, ItemStatus status, bool purchased
});




}
/// @nodoc
class _$ItemCopyWithImpl<$Res>
    implements $ItemCopyWith<$Res> {
  _$ItemCopyWithImpl(this._self, this._then);

  final Item _self;
  final $Res Function(Item) _then;

/// Create a copy of Item
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? originalUrl = null,Object? title = freezed,Object? price = freezed,Object? images = null,Object? description = freezed,Object? domainSource = freezed,Object? status = null,Object? purchased = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,originalUrl: null == originalUrl ? _self.originalUrl : originalUrl // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,price: freezed == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double?,images: null == images ? _self.images : images // ignore: cast_nullable_to_non_nullable
as List<String>,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,domainSource: freezed == domainSource ? _self.domainSource : domainSource // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ItemStatus,purchased: null == purchased ? _self.purchased : purchased // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Item].
extension ItemPatterns on Item {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Item value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Item() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Item value)  $default,){
final _that = this;
switch (_that) {
case _Item():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Item value)?  $default,){
final _that = this;
switch (_that) {
case _Item() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'original_url')  String originalUrl,  String? title,  double? price,  List<String> images,  String? description, @JsonKey(name: 'domain_source')  String? domainSource,  ItemStatus status,  bool purchased)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Item() when $default != null:
return $default(_that.id,_that.originalUrl,_that.title,_that.price,_that.images,_that.description,_that.domainSource,_that.status,_that.purchased);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'original_url')  String originalUrl,  String? title,  double? price,  List<String> images,  String? description, @JsonKey(name: 'domain_source')  String? domainSource,  ItemStatus status,  bool purchased)  $default,) {final _that = this;
switch (_that) {
case _Item():
return $default(_that.id,_that.originalUrl,_that.title,_that.price,_that.images,_that.description,_that.domainSource,_that.status,_that.purchased);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'original_url')  String originalUrl,  String? title,  double? price,  List<String> images,  String? description, @JsonKey(name: 'domain_source')  String? domainSource,  ItemStatus status,  bool purchased)?  $default,) {final _that = this;
switch (_that) {
case _Item() when $default != null:
return $default(_that.id,_that.originalUrl,_that.title,_that.price,_that.images,_that.description,_that.domainSource,_that.status,_that.purchased);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Item implements Item {
  const _Item({required this.id, @JsonKey(name: 'original_url') required this.originalUrl, this.title, this.price, final  List<String> images = const <String>[], this.description, @JsonKey(name: 'domain_source') this.domainSource, required this.status, this.purchased = false}): _images = images;
  factory _Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);

@override final  String id;
@override@JsonKey(name: 'original_url') final  String originalUrl;
@override final  String? title;
// Backend sends a JSON number (e.g. 63.0) or null; json_serializable casts
// the incoming `num` to `double`.
@override final  double? price;
 final  List<String> _images;
@override@JsonKey() List<String> get images {
  if (_images is EqualUnmodifiableListView) return _images;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_images);
}

@override final  String? description;
@override@JsonKey(name: 'domain_source') final  String? domainSource;
@override final  ItemStatus status;
@override@JsonKey() final  bool purchased;

/// Create a copy of Item
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ItemCopyWith<_Item> get copyWith => __$ItemCopyWithImpl<_Item>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Item&&(identical(other.id, id) || other.id == id)&&(identical(other.originalUrl, originalUrl) || other.originalUrl == originalUrl)&&(identical(other.title, title) || other.title == title)&&(identical(other.price, price) || other.price == price)&&const DeepCollectionEquality().equals(other._images, _images)&&(identical(other.description, description) || other.description == description)&&(identical(other.domainSource, domainSource) || other.domainSource == domainSource)&&(identical(other.status, status) || other.status == status)&&(identical(other.purchased, purchased) || other.purchased == purchased));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,originalUrl,title,price,const DeepCollectionEquality().hash(_images),description,domainSource,status,purchased);

@override
String toString() {
  return 'Item(id: $id, originalUrl: $originalUrl, title: $title, price: $price, images: $images, description: $description, domainSource: $domainSource, status: $status, purchased: $purchased)';
}


}

/// @nodoc
abstract mixin class _$ItemCopyWith<$Res> implements $ItemCopyWith<$Res> {
  factory _$ItemCopyWith(_Item value, $Res Function(_Item) _then) = __$ItemCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'original_url') String originalUrl, String? title, double? price, List<String> images, String? description,@JsonKey(name: 'domain_source') String? domainSource, ItemStatus status, bool purchased
});




}
/// @nodoc
class __$ItemCopyWithImpl<$Res>
    implements _$ItemCopyWith<$Res> {
  __$ItemCopyWithImpl(this._self, this._then);

  final _Item _self;
  final $Res Function(_Item) _then;

/// Create a copy of Item
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? originalUrl = null,Object? title = freezed,Object? price = freezed,Object? images = null,Object? description = freezed,Object? domainSource = freezed,Object? status = null,Object? purchased = null,}) {
  return _then(_Item(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,originalUrl: null == originalUrl ? _self.originalUrl : originalUrl // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,price: freezed == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double?,images: null == images ? _self._images : images // ignore: cast_nullable_to_non_nullable
as List<String>,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,domainSource: freezed == domainSource ? _self.domainSource : domainSource // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ItemStatus,purchased: null == purchased ? _self.purchased : purchased // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
