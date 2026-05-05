import 'package:flutter_test/flutter_test.dart';
import 'package:haemeoknote/features/records/data/record_models.dart';

void main() {
  test('image attachment prefers signed thumbnail URL', () {
    const attachment = RecordAttachment(
      type: AttachmentType.image,
      thumbnailUrl: 'http://localhost:8000/api/files/a.jpg?token=signed',
      objectKey: 'records/images/a.jpg',
    );

    expect(
      attachment.resolvedImageUrl,
      'http://localhost:8000/api/files/a.jpg?token=signed',
    );
  });

  test('record draft serializes API payload', () {
    final draft = RecordDraft(
      dishName: '김치찌개',
      cookedDate: DateTime(2026, 4, 26),
      recipe: '끓인다',
      memo: '두부 추가',
      rating: 4,
      ingredients: const [RecordIngredient(name: '김치', quantity: '200g')],
      attachments: const [
        RecordAttachment(
          type: AttachmentType.url,
          url: 'https://example.com/recipe',
          title: '레시피',
        ),
      ],
    );

    expect(draft.toJson(), {
      'dish_name': '김치찌개',
      'cooked_date': '2026-04-26',
      'recipe': '끓인다',
      'memo': '두부 추가',
      'rating': 4,
      'ingredients': [
        {'name': '김치', 'quantity': '200g'},
      ],
      'attachments': [
        {
          'type': 'url',
          'title': '레시피',
          'url': 'https://example.com/recipe',
          'description': null,
          'thumbnail_url': null,
          'object_key': null,
        },
      ],
    });
  });
}
