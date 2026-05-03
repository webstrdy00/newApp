import '../../../core/network/api_client.dart';

enum AttachmentType {
  image,
  url,
  youtube;

  static AttachmentType fromJson(String value) {
    return AttachmentType.values.firstWhere((item) => item.name == value);
  }
}

class RecordIngredient {
  const RecordIngredient({
    this.id,
    required this.name,
    this.quantity,
    this.sortOrder = 0,
  });

  final int? id;
  final String name;
  final String? quantity;
  final int sortOrder;

  factory RecordIngredient.fromJson(Map<String, dynamic> json) {
    return RecordIngredient(
      id: json['id'] as int?,
      name: json['name'] as String,
      quantity: json['quantity'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
    };
  }
}

class RecordAttachment {
  const RecordAttachment({
    this.id,
    required this.type,
    this.title,
    this.url,
    this.description,
    this.thumbnailUrl,
    this.objectKey,
    this.sortOrder = 0,
  });

  final int? id;
  final AttachmentType type;
  final String? title;
  final String? url;
  final String? description;
  final String? thumbnailUrl;
  final String? objectKey;
  final int sortOrder;

  String? get resolvedImageUrl {
    final key = objectKey?.trim();
    if (type == AttachmentType.image && key != null && key.isNotEmpty) {
      return '${defaultApiBaseUrl.replaceFirst(RegExp(r'/$'), '')}/files/$key';
    }

    final thumbnail = thumbnailUrl?.trim();
    if (thumbnail != null && thumbnail.isNotEmpty) {
      return thumbnail;
    }
    return null;
  }

  factory RecordAttachment.fromJson(Map<String, dynamic> json) {
    return RecordAttachment(
      id: json['id'] as int?,
      type: AttachmentType.fromJson(json['type'] as String),
      title: json['title'] as String?,
      url: json['url'] as String?,
      description: json['description'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      objectKey: json['object_key'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'title': title,
      'url': url,
      'description': description,
      'thumbnail_url': thumbnailUrl,
      'object_key': objectKey,
    };
  }
}

class AttachmentPreview {
  const AttachmentPreview({
    required this.type,
    required this.url,
    this.title,
    this.thumbnailUrl,
  });

  final AttachmentType type;
  final String url;
  final String? title;
  final String? thumbnailUrl;

  factory AttachmentPreview.fromJson(Map<String, dynamic> json) {
    return AttachmentPreview(
      type: AttachmentType.fromJson(json['type'] as String),
      url: json['url'] as String,
      title: json['title'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
    );
  }
}

class CookingRecord {
  const CookingRecord({
    required this.id,
    required this.dishName,
    required this.cookedDate,
    this.recipe,
    this.memo,
    this.rating,
    this.ingredients = const [],
    this.attachments = const [],
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String dishName;
  final DateTime cookedDate;
  final String? recipe;
  final String? memo;
  final int? rating;
  final List<RecordIngredient> ingredients;
  final List<RecordAttachment> attachments;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory CookingRecord.fromJson(Map<String, dynamic> json) {
    return CookingRecord(
      id: json['id'] as int,
      dishName: json['dish_name'] as String,
      cookedDate: DateTime.parse(json['cooked_date'] as String),
      recipe: json['recipe'] as String?,
      memo: json['memo'] as String?,
      rating: json['rating'] as int?,
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map((item) => RecordIngredient.fromJson(item as Map<String, dynamic>))
          .toList(),
      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((item) => RecordAttachment.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] == null ? null : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null ? null : DateTime.parse(json['updated_at'] as String),
    );
  }

  String get preview {
    if (memo != null && memo!.trim().isNotEmpty) {
      return memo!.trim();
    }
    if (recipe != null && recipe!.trim().isNotEmpty) {
      return recipe!.trim();
    }
    if (ingredients.isNotEmpty) {
      return ingredients.map((item) => item.name).join(', ');
    }
    return '남겨둔 메모가 없어요';
  }
}

class CalendarRecordDay {
  const CalendarRecordDay({required this.date, required this.count});

  final DateTime date;
  final int count;

  factory CalendarRecordDay.fromJson(Map<String, dynamic> json) {
    return CalendarRecordDay(
      date: DateTime.parse(json['date'] as String),
      count: json['count'] as int,
    );
  }
}

class RecordDraft {
  const RecordDraft({
    required this.dishName,
    required this.cookedDate,
    this.recipe,
    this.memo,
    this.rating,
    this.ingredients = const [],
    this.attachments = const [],
  });

  final String dishName;
  final DateTime cookedDate;
  final String? recipe;
  final String? memo;
  final int? rating;
  final List<RecordIngredient> ingredients;
  final List<RecordAttachment> attachments;

  Map<String, dynamic> toJson({bool includeAttachments = true}) {
    final data = <String, dynamic>{
      'dish_name': dishName,
      'cooked_date': cookedDate.toIso8601String().split('T').first,
      'recipe': recipe,
      'memo': memo,
      'rating': rating,
      'ingredients': ingredients.map((item) => item.toJson()).toList(),
    };
    if (includeAttachments) {
      data['attachments'] = attachments.map((item) => item.toJson()).toList();
    }
    return data;
  }
}
